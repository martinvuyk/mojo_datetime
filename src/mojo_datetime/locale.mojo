# ===----------------------------------------------------------------------=== #
# Copyright (c) 2026, Martin Vuyk Loperena
#
# Licensed under the Apache License v2.0 with LLVM Exceptions:
# https://llvm.org/LICENSE.txt
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ===----------------------------------------------------------------------=== #
"""A module containing locale funcionality and definitions."""

from std.bit import next_power_of_two
from std.builtin.dtype import _uint_type_of_width
from std.builtin.globals import global_constant
from std.os import abort
from std.utils import Variant
from std.ffi import external_call, c_char, get_errno
from std.sys.info import CompilationTarget, bit_width_of
from std.format._utils import _WriteBufferStack

from .zoneinfo import Offset
from .calendar import _NaiveDateTime, Calendar
from .datetime import DayOfWeek
from .timezone import TimeZone
from .zoneinfo import UTCZoneInfo
from ._tz_naive_datetime import _TzNaiveDateTime


# ===----------------------------------------------------------------------=== #
# Supported format codes
# ===----------------------------------------------------------------------=== #


struct FormatCode(Equatable):
    """The supported format codes. Based on the 1989 C standard, with some
    caveats.

    - This does not include any calendar-specific codes.
    - The day of the week and week number of the year are expressed relative to
        a given calendar. So if a string is stringified with a particular
        calendar, any week expressed therein is expected to follow that
        calendar's logic and be able to be parsed from it.
    """

    comptime a = Self("a")
    """The day of the week as locale's abbreviated name."""
    comptime A = Self("A")
    """The day of the week as locale's full name."""
    comptime w = Self("w")
    """The day of the week as a decimal number."""
    comptime d = Self("d")
    """Day of the month as a zero-padded decimal number."""
    comptime e = Self("e")
    """Day of the month as a space-padded decimal number."""
    comptime b = Self("b")
    """Month as locale's abbreviated name."""
    comptime B = Self("B")
    """Month as locale's full name."""
    comptime m = Self("m")
    """Month as a zero-padded decimal number."""
    comptime y = Self("y")
    """Year without century as a zero-padded decimal number."""
    comptime Y = Self("Y")
    """Year with century as a decimal number."""
    comptime H = Self("H")
    """Hour (24-hour clock) as a zero-padded decimal number."""
    comptime I = Self("I")
    """Hour (12-hour clock) as a zero-padded decimal number."""
    comptime p = Self("p")
    """Locale's equivalent of either AM or PM."""
    comptime M = Self("M")
    """Minute as a zero-padded decimal number."""
    comptime S = Self("S")
    """Second as a zero-padded decimal number."""
    comptime f = Self("f")
    """Microsecond as a decimal number, zero-padded to 6 digits."""
    comptime z = Self("z")
    """UTC offset in the form ±HHMM. No second or microsecond specification is
    expected or allowed."""
    comptime `:z` = Self(":z")
    """Extended UTC offset in the form ±HH:MM. No second or microsecond
    specification is expected or allowed."""
    comptime Z = Self("Z")
    """Time zone name."""
    comptime j = Self("j")
    """Day of the year as a zero-padded decimal number."""
    comptime W = Self("W")
    """Week number of the year as a zero-padded decimal number."""
    comptime c = Self("c")
    """Locale's appropriate date and time representation."""
    comptime x = Self("x")
    """Locale's appropriate date representation."""
    comptime X = Self("X")
    """Locale's appropriate time representation."""
    comptime `%` = Self("%")
    """A literal '%' character."""

    var value: SIMD[DType.uint8, 2]
    """The raw ASCII characters."""

    def __init__(out self, value: StringLiteral):
        """Construct a `FormatCode` from a string literal.

        Args:
            value: The value.
        """
        comptime val = type_of(value)()
        comptime assert 1 <= val.byte_length() <= 2
        comptime if val.byte_length() == 1:
            self.value = {value.unsafe_ptr().load[1](), 0}
        else:
            self.value = value.unsafe_ptr().load[2]()


# ===----------------------------------------------------------------------=== #
# ISO Format
# ===----------------------------------------------------------------------=== #


@fieldwise_init
struct IsoFormat:
    """Available formats to parse from and to
    [ISO 8601](https://es.wikipedia.org/wiki/ISO_8601)."""

    comptime YYYYMMDD = String("%Y%m%d")
    """Format: e.g. `19700101`."""
    comptime YYYY_MM_DD = String("%Y-%m-%d")
    """Format: e.g. `1970-01-01`."""
    comptime HHMMSS = String("%H%M%S")
    """Format: e.g. `000000`."""
    comptime HH_MM_SS = String("%H:%M:%S")
    """Format: e.g. `00:00:00`."""
    comptime YYYYMMDDHHMMSS = String("%Y%m%d%H%M%S")
    """Format: e.g. `19700101000000`."""
    comptime YYYYMMDDHHMMSSTZD = String("%Y%m%d%H%M%S%z")
    """Format: e.g. `19700101000000+0000`."""
    comptime YYYY_MM_DD___HH_MM_SS = String("%Y-%m-%d %H:%M:%S")
    """Format: e.g. `1970-01-01 00:00:00`."""
    comptime YYYY_MM_DD_T_HH_MM_SS = String("%Y-%m-%dT%H:%M:%S")
    """Format: e.g. `1970-01-01T00:00:00`."""
    comptime YYYY_MM_DD_T_HH_MM_SS_TZD = String("%Y-%m-%dT%H:%M:%S%:z")
    """Format: e.g. `1970-01-01T00:00:00+00:00`."""


# ===----------------------------------------------------------------------=== #
# _DTSpecIterator
# ===----------------------------------------------------------------------=== #


@fieldwise_init
struct _DTSpecIterator[mut: Bool, //, origin: Origin[mut=mut]](
    ImplicitlyCopyable, Iterable, Iterator
):
    comptime IteratorType[
        iterable_mut: Bool, //, iterable_origin: Origin[mut=iterable_mut]
    ]: Iterator = Self
    comptime Element = Tuple[Bool, StringSlice[Self.origin]]

    var _slice: StringSlice[Self.origin]

    def __iter__(ref self) -> Self.IteratorType[origin_of(self)]:
        return self.copy()

    @always_inline
    def __next__(mut self) raises StopIteration -> Self.Element:
        var length = self._slice.byte_length()
        var idx = self._slice.find("%")
        if idx == -1 and length > 0:
            var value = self._slice
            self._slice = {ptr = self._slice.unsafe_ptr() + length, length = 0}
            return (False, value)
        elif idx == -1 or length - idx <= 1:
            raise StopIteration()
        elif idx == 0 and self._slice.byte_length() > 2:
            # if we ever want to add O, or E or whatever
            comptime extension_chars = Byte(ord(":"))
            var end = 2 + Int(self._slice.unsafe_ptr()[1] in extension_chars)
            var value = self._slice[byte=1:end]
            self._slice = {
                ptr = self._slice.unsafe_ptr() + end,
                length = length - end,
            }
            return True, value
        elif idx == 0:
            var value = self._slice[byte=1:2]
            self._slice = {
                ptr = self._slice.unsafe_ptr() + 2,
                length = length - 2,
            }
            return True, value
        else:
            var value = self._slice[byte=:idx]
            self._slice = {
                ptr = self._slice.unsafe_ptr() + idx,
                length = length - idx,
            }
            return False, value


# ===----------------------------------------------------------------------=== #
# DateTime Locale
# ===----------------------------------------------------------------------=== #


@fieldwise_init
struct DTFormatSpecParsingError(TrivialRegisterPassable, Writable):
    """A custom error type for `Locale`s."""

    def write_to(self, mut writer: Some[Writer]):
        """This always writes "DTFormatSpecParsingError".

        Args:
            writer: The writer to write to.
        """
        writer.write("DTFormatSpecParsingError")


trait DTLocale(Copyable, Defaultable, ImplicitlyDestructible):
    """A trait to provide a locale that helps in stringifying values with
    region-specific characteristics."""

    def day_of_week_short(self, mut writer: Some[Writer], dt: _TzNaiveDateTime):
        """The day of the week as locale's abbreviated name.

        Args:
            writer: The writer to write to.
            dt: The datetime.
        """
        ...

    def parse_day_of_week_short[
        calendar: Calendar
    ](
        self, read_from: StringSlice[mut=False, _]
    ) raises DTFormatSpecParsingError -> Tuple[DayOfWeek[calendar], Int]:
        """Parse day_of_week as locale's abbreviated name.

        Parameters:
            calendar: The calendar to use.

        Args:
            read_from: The source data.

        Returns:
            A tuple of (day_of_week, bytes_read).

        Raises:
            If parsing fails.
        """
        ...

    def day_of_week_long(self, mut writer: Some[Writer], dt: _TzNaiveDateTime):
        """The day of the week as locale's full name.

        Args:
            writer: The writer to write to.
            dt: The datetime.
        """
        ...

    def parse_day_of_week_long[
        calendar: Calendar
    ](
        self, read_from: StringSlice[mut=False, _]
    ) raises DTFormatSpecParsingError -> Tuple[DayOfWeek[calendar], Int]:
        """Parse day_of_week as locale's full name.

        Parameters:
            calendar: The calendar to use.

        Args:
            read_from: The source data.

        Returns:
            A tuple of (day_of_week, bytes_read).

        Raises:
            If parsing fails.
        """
        ...

    def month_short(self, mut writer: Some[Writer], dt: _TzNaiveDateTime):
        """Month as locale's abbreviated name.

        Args:
            writer: The writer to write to.
            dt: The datetime.
        """
        ...

    def parse_month_short[
        calendar: Calendar
    ](
        self, read_from: StringSlice[mut=False, _]
    ) raises DTFormatSpecParsingError -> Tuple[UInt8, Int]:
        """Parse month as locale's abbreviated name.

        Parameters:
            calendar: The calendar to use.

        Args:
            read_from: The source data.

        Returns:
            A tuple of (month, bytes_read).

        Raises:
            If parsing fails.
        """
        ...

    def month_long(self, mut writer: Some[Writer], dt: _TzNaiveDateTime):
        """Month as locale's full name.

        Args:
            writer: The writer to write to.
            dt: The datetime.
        """
        ...

    def parse_month_long[
        calendar: Calendar
    ](
        self, read_from: StringSlice[mut=False, _]
    ) raises DTFormatSpecParsingError -> Tuple[UInt8, Int]:
        """Parse month as locale's full name.

        Parameters:
            calendar: The calendar to use.

        Args:
            read_from: The source data.

        Returns:
            A tuple of (month, bytes_read).

        Raises:
            If parsing fails.
        """
        ...

    def am_pm(self, mut writer: Some[Writer], dt: _TzNaiveDateTime):
        """Locale's equivalent of either AM or PM.

        Args:
            writer: The writer to write to.
            dt: The datetime.
        """
        ...

    def parse_am_pm[
        calendar: Calendar
    ](
        self, read_from: StringSlice[mut=False, _]
    ) raises DTFormatSpecParsingError -> Tuple[Bool, Int]:
        """Parse locale's equivalent of AM or PM.

        Parameters:
            calendar: The calendar to use.

        Args:
            read_from: The source data.

        Returns:
            A tuple of (is_pm, bytes_read).

        Raises:
            If parsing fails.
        """
        ...

    def datetime_fmt[calendar: Calendar](self) -> String:
        """Format string for locale's date and time representation.

        Parameters:
            calendar: The calendar to use.

        Returns:
            The format string.

        Notes:
            This function is the only one allowed to recursively target other
            locale-aware format codes.
        """
        ...

    def date_fmt[calendar: Calendar](self) -> String:
        """Format string for locale's date representation.

        Parameters:
            calendar: The calendar to use.

        Returns:
            The format string.
        """
        ...

    def time_fmt[calendar: Calendar](self) -> String:
        """Format string for locale's time representation.

        Parameters:
            calendar: The calendar to use.

        Returns:
            The format string.
        """
        ...


# ===----------------------------------------------------------------------=== #
# LibCLocale
# ===----------------------------------------------------------------------=== #


def _get_flag[name: String, linux: Int, mac: Optional[Int] = None]() -> Int32:
    comptime if CompilationTarget.is_linux():
        return Int32(linux)
    elif CompilationTarget.is_macos() and mac:
        return Int32(mac.value())
    else:
        CompilationTarget.unsupported_target_error[
            operation=name, note="unknown constant value for the given OS"
        ]()


# MacOs source: https://github.com/apple-oss-distributions/Libc
comptime _LC_TIME_MASK = Int32(1) << _get_flag["LC_TIME", 2, 5]()

comptime _LINUX_TIME_BASE = 0x20000

comptime _D_T_FMT = _get_flag["D_T_FMT", _LINUX_TIME_BASE + 40, 1]()
comptime _D_FMT = _get_flag["D_FMT", _LINUX_TIME_BASE + 41, 2]()
comptime _T_FMT = _get_flag["T_FMT", _LINUX_TIME_BASE + 42, 3]()
comptime _AM_STR = _get_flag["AM_STR", _LINUX_TIME_BASE + 38, 5]()
comptime _PM_STR = _get_flag["PM_STR", _LINUX_TIME_BASE + 39, 6]()

comptime _ABDAY_1 = _get_flag["ABDAY_1", _LINUX_TIME_BASE + 0, 14]()
comptime _DAY_1 = _get_flag["DAY_1", _LINUX_TIME_BASE + 7, 7]()
comptime _ABMON_1 = _get_flag["ABMON_1", _LINUX_TIME_BASE + 14, 33]()
comptime _MON_1 = _get_flag["MON_1", _LINUX_TIME_BASE + 26, 21]()

comptime _posix_days[calendar: Calendar]: InlineArray[
    DayOfWeek[calendar], 7
] = [
    DayOfWeek[calendar].SUNDAY,
    DayOfWeek[calendar].MONDAY,
    DayOfWeek[calendar].TUESDAY,
    DayOfWeek[calendar].WEDNESDAY,
    DayOfWeek[calendar].THURSDAY,
    DayOfWeek[calendar].FRIDAY,
    DayOfWeek[calendar].SATURDAY,
]
"""Posix represents [sunday, monday]: [0, 6]."""


struct LibCLocale(DTLocale):
    """A POSIX standard C locale via FFI with Libc."""

    comptime _ptr = Optional[OpaquePointer[MutExternalOrigin]]
    var _loc: Self._ptr

    def __init__(out self, var locale_name: String) raises:
        """Initializes a locale by name (e.g. 'es_ES.utf8').

        Args:
            locale_name: The string name of the locale.

        Raises:
            When failing to instantiate the locale.
        """
        var null_ptr = Self._ptr()
        var name = locale_name.as_c_string_slice()
        self._loc = external_call["newlocale", Self._ptr](
            _LC_TIME_MASK, name.unsafe_ptr(), null_ptr
        )
        if self._loc == null_ptr:
            raise Error(
                t"Failed to instantiate locale: '{locale_name}'. ErrNo:"
                t" {get_errno()}"
            )

    def __init__(out self):
        """Default constructor initializes the 'C' standard locale."""
        try:
            self = Self("C")
        except e:
            abort(String(e))

    def __init__(out self, *, copy: Self):
        """Create a new instance of the value by copying an existing one.

        Args:
            copy: The value to copy.
        """
        self._loc = external_call["duplocale", Self._ptr](copy._loc)
        if self._loc == {}:
            abort(t"Failed to duplicate locale. ErrNo: {get_errno()}")

    def __del__(deinit self):
        """Frees the reference to self."""
        external_call["freelocale", NoneType](self._loc)

    @always_inline
    def _get_langinfo(self, item: Int32) -> StringSlice[ImmutAnyOrigin]:
        """Fetches a locale-specific string given an nl_item.

        If item is not valid, a pointer to an empty string is returned.

        The pointer returned by these functions may point to static data
        that may be overwritten, or the pointer itself may be invalidated,
        by a subsequent call to nl_langinfo(), nl_langinfo_l(), or
        setlocale(3).  The same statements apply to nl_langinfo_l() if the
        locale object referred to by locale is freed or modified by
        freelocale(3) or newlocale(3).

        POSIX specifies that the application may not modify the string
        returned by these functions.

        [Reference](https://man7.org/linux/man-pages/man3/nl_langinfo.3.html).
        """
        var c_str = external_call[
            "nl_langinfo_l", UnsafePointer[c_char, ImmutAnyOrigin]
        ](item, self._loc)
        return StringSlice(unsafe_from_utf8_ptr=c_str)

    def day_of_week_short(self, mut writer: Some[Writer], dt: _TzNaiveDateTime):
        """The day of the week as locale's abbreviated name.

        Args:
            writer: The writer to write to.
            dt: The datetime.
        """
        var dow = DayOfWeek(dt)
        comptime for i in range(7):
            comptime day = _posix_days[dt.calendar][i]
            if dow == day:
                return writer.write(self._get_langinfo(_ABDAY_1 + Int32(i)))

        assert False, t"Unknown day of the week for datetime: {dt}"
        writer.write(self._get_langinfo(_ABDAY_1 + 6))

    def parse_day_of_week_short[
        calendar: Calendar
    ](
        self, read_from: StringSlice[mut=False, _]
    ) raises DTFormatSpecParsingError -> Tuple[DayOfWeek[calendar], Int]:
        """Parse day_of_week as locale's abbreviated name.

        Parameters:
            calendar: The calendar to use.

        Args:
            read_from: The source data.

        Returns:
            A tuple of (day_of_week, bytes_read).

        Raises:
            If parsing fails.
        """
        comptime for i in range(7):
            comptime day = _posix_days[calendar][i]
            var dow_str = self._get_langinfo(_ABDAY_1 + Int32(i))
            if read_from.startswith(dow_str):
                return day, dow_str.byte_length()

        raise DTFormatSpecParsingError()

    def day_of_week_long(self, mut writer: Some[Writer], dt: _TzNaiveDateTime):
        """The day of the week as locale's full name.

        Args:
            writer: The writer to write to.
            dt: The datetime.
        """
        var dow = DayOfWeek(dt)
        comptime for i in range(7):
            comptime day = _posix_days[dt.calendar][i]
            if dow == day:
                return writer.write(self._get_langinfo(_DAY_1 + Int32(i)))

        assert False, t"Unknown day of the week for datetime: {dt}"
        writer.write(self._get_langinfo(_DAY_1 + 6))

    def parse_day_of_week_long[
        calendar: Calendar
    ](
        self, read_from: StringSlice[mut=False, _]
    ) raises DTFormatSpecParsingError -> Tuple[DayOfWeek[calendar], Int]:
        """Parse day_of_week as locale's full name.

        Parameters:
            calendar: The calendar to use.

        Args:
            read_from: The source data.

        Returns:
            A tuple of (day_of_week, bytes_read).

        Raises:
            If parsing fails.
        """
        comptime for i in range(7):
            comptime day = _posix_days[calendar][i]
            var dow_str = self._get_langinfo(_DAY_1 + Int32(i))
            if read_from.startswith(dow_str):
                return day, dow_str.byte_length()

        raise DTFormatSpecParsingError()

    def month_short(self, mut writer: Some[Writer], dt: _TzNaiveDateTime):
        """Month as locale's abbreviated name.

        Args:
            writer: The writer to write to.
            dt: The datetime.
        """
        writer.write(self._get_langinfo(_ABMON_1 + Int32(dt.dt.month) - 1))

    def parse_month_short[
        calendar: Calendar
    ](
        self, read_from: StringSlice[mut=False, _]
    ) raises DTFormatSpecParsingError -> Tuple[UInt8, Int]:
        """Parse month as locale's abbreviated name.

        Parameters:
            calendar: The calendar to use.

        Args:
            read_from: The source data.

        Returns:
            A tuple of (month, bytes_read).

        Raises:
            If parsing fails.
        """
        for i in range(calendar.max_month):
            var mon_str = self._get_langinfo(_ABMON_1 + Int32(i))
            if read_from.startswith(mon_str):
                return UInt8(i + 1), mon_str.byte_length()

        raise DTFormatSpecParsingError()

    def month_long(self, mut writer: Some[Writer], dt: _TzNaiveDateTime):
        """Month as locale's full name.

        Args:
            writer: The writer to write to.
            dt: The datetime.
        """
        writer.write(self._get_langinfo(_MON_1 + Int32(dt.dt.month) - 1))

    def parse_month_long[
        calendar: Calendar
    ](
        self, read_from: StringSlice[mut=False, _]
    ) raises DTFormatSpecParsingError -> Tuple[UInt8, Int]:
        """Parse month as locale's full name.

        Parameters:
            calendar: The calendar to use.

        Args:
            read_from: The source data.

        Returns:
            A tuple of (month, bytes_read).

        Raises:
            If parsing fails.
        """
        for i in range(calendar.max_month):
            var mon_str = self._get_langinfo(_MON_1 + Int32(i))
            if read_from.startswith(mon_str):
                return UInt8(i + 1), mon_str.byte_length()

        raise DTFormatSpecParsingError()

    def am_pm(self, mut writer: Some[Writer], dt: _TzNaiveDateTime):
        """Locale's equivalent of either AM or PM.

        Args:
            writer: The writer to write to.
            dt: The datetime.
        """
        comptime middle = (dt.calendar.max_hour - dt.calendar.min_hour + 1) // 2
        var item = _PM_STR if dt.dt.hour >= middle else _AM_STR
        writer.write(self._get_langinfo(item))

    def parse_am_pm[
        calendar: Calendar
    ](
        self, read_from: StringSlice[mut=False, _]
    ) raises DTFormatSpecParsingError -> Tuple[Bool, Int]:
        """Parse locale's equivalent of AM or PM.

        Parameters:
            calendar: The calendar to use.

        Args:
            read_from: The source data.

        Returns:
            A tuple of (is_pm, bytes_read).

        Raises:
            If parsing fails.
        """
        var am_str = self._get_langinfo(_AM_STR)
        if read_from.startswith(am_str):
            return False, am_str.byte_length()

        var pm_str = self._get_langinfo(_PM_STR)
        if read_from.startswith(pm_str):
            return True, pm_str.byte_length()

        raise DTFormatSpecParsingError()

    def datetime_fmt[calendar: Calendar](self) -> String:
        """Format string for locale's date and time representation.

        Parameters:
            calendar: The calendar to use.

        Returns:
            The format string.

        Notes:
            This function is the only one allowed to recursively target other
            locale-aware format codes.
        """
        return String(self._get_langinfo(_D_T_FMT))

    def date_fmt[calendar: Calendar](self) -> String:
        """Format string for locale's date representation.

        Parameters:
            calendar: The calendar to use.

        Returns:
            The format string.
        """
        return String(self._get_langinfo(_D_FMT))

    def time_fmt[calendar: Calendar](self) -> String:
        """Format string for locale's time representation.

        Parameters:
            calendar: The calendar to use.

        Returns:
            The format string.
        """
        return String(self._get_langinfo(_T_FMT))


# ===----------------------------------------------------------------------=== #
# Mojo Native Locales
# ===----------------------------------------------------------------------=== #

comptime _days[calendar: Calendar]: InlineArray[DayOfWeek[calendar], 7] = [
    DayOfWeek[calendar].MONDAY,
    DayOfWeek[calendar].TUESDAY,
    DayOfWeek[calendar].WEDNESDAY,
    DayOfWeek[calendar].THURSDAY,
    DayOfWeek[calendar].FRIDAY,
    DayOfWeek[calendar].SATURDAY,
    DayOfWeek[calendar].SUNDAY,
]


trait NativeDTLocale(DTLocale):
    """A trait to provide an easy way to implement a specific Mojo-native
    locale."""

    # fmt: off
    comptime day_of_week_names_short: InlineArray[String, 7] = [
        "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"
    ]
    """Names for the days of the week starting on monday."""
    comptime day_of_week_names_long: InlineArray[String, 7] = [
        "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Satday",
        "Sunday"
    ]
    """Names for the days of the week starting on monday."""
    comptime month_names_short: List[Tuple[Int, String]] = [
        (1, "Jan"), (2, "Feb"), (3, "Mar"), (4, "Apr"), (5, "May"), (6, "Jun"),
        (7, "Jul"), (8, "Aug"), (9, "Sep"), (10, "Oct"), (11, "Nov"),
        (12, "Dec"),
    ]
    """Names for the months of the year. Alternative names are allowed for
    parsing, but writing prioritizes the first instance of that month number."""
    comptime month_names_long: List[Tuple[Int, String]] = [
        (1, "January"), (2, "February"), (3, "March"), (4, "April"), (5, "May"),
        (6, "June"), (7, "July"), (8, "August"), (9, "September"),
        (10, "October"), (11, "November"), (12, "December"),
    ]
    """Names for the months of the year. Alternative names are allowed for
    parsing, but writing prioritizes the first instance of that month number."""
    # fmt: on
    comptime AM: String = "AM"
    """String for AM."""
    comptime PM: String = "PM"
    """String for PM."""
    comptime datetime_fmt_str: String = "%a, %d %b %Y %H:%M:%S %z"
    """Format string for locale's date and time representation."""
    comptime date_fmt_str: String = "%d/%m/%Y"
    """Format string for locale's date representation."""
    comptime time_fmt_str: String = "%H:%M:%S"
    """Format string for locale's time representation."""

    def day_of_week_short(self, mut writer: Some[Writer], dt: _TzNaiveDateTime):
        """The day of the week as locale's abbreviated name.

        Args:
            writer: The writer to write to.
            dt: The datetime.
        """
        var dow = DayOfWeek(dt)
        comptime for i in range(7):
            comptime dow_str = Self.day_of_week_names_short[i]
            comptime day = _days[dt.calendar][i]
            if dow == day:
                return writer.write(dow_str)
        assert False, t"Unknown day of the week for datetime: {dt}"
        comptime sunday = Self.day_of_week_names_short[6]
        writer.write(sunday)

    def parse_day_of_week_short[
        calendar: Calendar
    ](
        self, read_from: StringSlice[mut=False, _]
    ) raises DTFormatSpecParsingError -> Tuple[DayOfWeek[calendar], Int]:
        """Parse day_of_week as locale's abbreviated name.

        Parameters:
            calendar: The calendar to use.

        Args:
            read_from: The source data.

        Returns:
            A tuple of (day_of_week, bytes_read).

        Raises:
            If parsing fails.
        """
        comptime for i in range(7):
            comptime dow_str = Self.day_of_week_names_short[i]
            comptime day = _days[calendar][i]
            if read_from.startswith(dow_str):
                return day, dow_str.byte_length()

        raise DTFormatSpecParsingError()

    def day_of_week_long(self, mut writer: Some[Writer], dt: _TzNaiveDateTime):
        """The day of the week as locale's full name.

        Args:
            writer: The writer to write to.
            dt: The datetime.
        """
        var dow = DayOfWeek(dt)
        comptime for i in range(7):
            comptime dow_str = Self.day_of_week_names_long[i]
            comptime day = _days[dt.calendar][i]
            if dow == day:
                return writer.write(dow_str)

        assert False, t"Unknown day of the week for datetime: {dt}"
        comptime sunday = Self.day_of_week_names_long[6]
        writer.write(sunday)

    def parse_day_of_week_long[
        calendar: Calendar
    ](
        self, read_from: StringSlice[mut=False, _]
    ) raises DTFormatSpecParsingError -> Tuple[DayOfWeek[calendar], Int]:
        """Parse day_of_week as locale's full name.

        Parameters:
            calendar: The calendar to use.

        Args:
            read_from: The source data.

        Returns:
            A tuple of (day_of_week, bytes_read).

        Raises:
            If parsing fails.
        """
        comptime for i in range(7):
            comptime dow_str = Self.day_of_week_names_long[i]
            comptime day = _days[calendar][i]
            if read_from.startswith(dow_str):
                return day, dow_str.byte_length()

        raise DTFormatSpecParsingError()

    def month_short(self, mut writer: Some[Writer], dt: _TzNaiveDateTime):
        """Month as locale's abbreviated name.

        Args:
            writer: The writer to write to.
            dt: The datetime.
        """
        comptime this_impl = "This implementation is only for calendars"
        comptime assert (
            dt.calendar.min_month == 1 and dt.calendar.max_month == 12
        ), t"{this_impl} with a month range: [1, 12]"
        comptime for i in range(len(Self.month_names_short)):
            comptime mon_num, mon_str = Self.month_names_short[i]
            if dt.dt.month == UInt8(mon_num):
                return writer.write(mon_str)

        assert False, t"Unknown month for datetime: {dt}"
        comptime _, last = Self.month_names_short[
            len(Self.month_names_short) - 1
        ]
        writer.write(last)

    def parse_month_short[
        calendar: Calendar
    ](
        self, read_from: StringSlice[mut=False, _]
    ) raises DTFormatSpecParsingError -> Tuple[UInt8, Int]:
        """Parse month as locale's abbreviated name.

        Parameters:
            calendar: The calendar to use.

        Args:
            read_from: The source data.

        Returns:
            A tuple of (month, bytes_read).

        Raises:
            If parsing fails.
        """
        comptime this_impl = "This implementation is only for calendars"
        comptime assert (
            calendar.min_month == 1 and calendar.max_month == 12
        ), t"{this_impl} with a month range: [1, 12]"
        comptime for i in range(len(Self.month_names_short)):
            comptime mon_num, mon_str = Self.month_names_short[i]
            if read_from.startswith(mon_str):
                return UInt8(mon_num), mon_str.byte_length()

        raise DTFormatSpecParsingError()

    def month_long(self, mut writer: Some[Writer], dt: _TzNaiveDateTime):
        """Month as locale's full name.

        Args:
            writer: The writer to write to.
            dt: The datetime.
        """
        comptime this_impl = "This implementation is only for calendars"
        comptime assert (
            dt.calendar.min_month == 1 and dt.calendar.max_month == 12
        ), t"{this_impl} with a month range: [1, 12]"
        comptime for i in range(len(Self.month_names_long)):
            comptime mon_num, mon_str = Self.month_names_long[i]
            if dt.dt.month == UInt8(mon_num):
                return writer.write(mon_str)

        assert False, t"Unknown month for datetime: {dt}"
        comptime _, last = Self.month_names_short[
            len(Self.month_names_short) - 1
        ]
        writer.write(last)

    def parse_month_long[
        calendar: Calendar
    ](
        self, read_from: StringSlice[mut=False, _]
    ) raises DTFormatSpecParsingError -> Tuple[UInt8, Int]:
        """Parse month as locale's full name.

        Parameters:
            calendar: The calendar to use.

        Args:
            read_from: The source data.

        Returns:
            A tuple of (month, bytes_read).

        Raises:
            If parsing fails.
        """
        comptime this_impl = "This implementation is only for calendars"
        comptime assert (
            calendar.min_month == 1 and calendar.max_month == 12
        ), t"{this_impl} with a month range: [1, 12]"
        comptime for i in range(len(Self.month_names_long)):
            comptime mon_num, mon_str = Self.month_names_long[i]
            if read_from.startswith(mon_str):
                return UInt8(mon_num), mon_str.byte_length()

        raise DTFormatSpecParsingError()

    @always_inline
    def am_pm(self, mut writer: Some[Writer], dt: _TzNaiveDateTime):
        """Locale's equivalent of either AM or PM.

        Args:
            writer: The writer to write to.
            dt: The datetime.
        """
        comptime middle = (dt.calendar.max_hour - dt.calendar.min_hour + 1) // 2
        writer.write(Self.AM if dt.dt.hour < middle else Self.PM)

    @always_inline
    def parse_am_pm[
        calendar: Calendar
    ](
        self, read_from: StringSlice[mut=False, _]
    ) raises DTFormatSpecParsingError -> Tuple[Bool, Int]:
        """Parse locale's equivalent of AM or PM.

        Parameters:
            calendar: The calendar to use.

        Args:
            read_from: The source data.

        Returns:
            A tuple of (is_pm, bytes_read).

        Raises:
            If parsing fails.
        """
        if read_from.startswith(Self.AM):
            return False, Self.AM.byte_length()
        elif read_from.startswith(Self.PM):
            return True, Self.PM.byte_length()
        raise DTFormatSpecParsingError()

    @always_inline
    def datetime_fmt[calendar: Calendar](self) -> String:
        """Format string for locale's date and time representation.

        Parameters:
            calendar: The calendar to use.

        Returns:
            The format string.

        Notes:
            This function is the only one allowed to recursively target other
            locale-aware format codes.
        """
        return Self.datetime_fmt_str

    @always_inline
    def date_fmt[calendar: Calendar](self) -> String:
        """Format string for locale's date representation.

        Parameters:
            calendar: The calendar to use.

        Returns:
            The format string.
        """
        return Self.date_fmt_str

    @always_inline
    def time_fmt[calendar: Calendar](self) -> String:
        """Format string for locale's time representation.

        Parameters:
            calendar: The calendar to use.

        Returns:
            The format string.
        """
        return Self.time_fmt_str


@fieldwise_init
struct GenericEnglishDTLocale(NativeDTLocale):
    """A default generic English locale."""

    ...


@fieldwise_init
struct USDTLocale(NativeDTLocale):
    """A default US datetime locale."""

    comptime datetime_fmt_str: String = "%a, %b %d %H:%M:%S %Y %z"
    """Format string for locale's date and time representation."""
    comptime date_fmt_str: String = "%m/%d/%Y"
    """Format string for locale's date representation."""


@fieldwise_init
struct SpanishDTLocale(NativeDTLocale):
    """A default Spanish speaking locale."""

    # fmt: off
    comptime day_of_week_names_short: InlineArray[String, 7] = [
        "Lun", "Mar", "Mie", "Jue", "Vie", "Sab", "Dom"
    ]
    """Names for the days of the week starting on monday."""
    comptime day_of_week_names_long: InlineArray[String, 7] = [
        "Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado", "Domingo"
    ]
    """Names for the days of the week starting on monday."""
    comptime month_names_short: List[Tuple[Int, String]] = [
        (1, "Ene"), (2, "Feb"), (3, "Mar"), (4, "Abr"), (5, "May"), (6, "Jun"),
        (7, "Jul"), (8, "Ago"), (9, "Sep"), (9, "Set"), (10, "Oct"),
        (11, "Nov"), (12, "Dic"),
    ]
    """Names for the months of the year. Alternative names are allowed for
    parsing, but writing prioritizes the first instance of that month number."""
    comptime month_names_long: List[Tuple[Int, String]] = [
        (1, "Enero"), (2, "Febrero"), (3, "Marzo"), (4, "Abril"), (5, "Mayo"),
        (6, "Junio"), (7, "Julio"), (8, "Agosto"), (9, "Septiembre"),
        (9, "Setiembre"), (10, "Octubre"), (11, "Noviembre"), (12, "Diciembre"),
    ]
    """Names for the months of the year. Alternative names are allowed for
    parsing, but writing prioritizes the first instance of that month number."""
    # fmt: on


@fieldwise_init
struct FrenchDTLocale(NativeDTLocale):
    """A default French speaking locale."""

    # fmt: off
    comptime day_of_week_names_short: InlineArray[String, 7] = [
        "Lun", "Mar", "Mer", "Jeu", "Ven", "Sam", "Dim"
    ]
    """Names for the days of the week starting on monday."""
    comptime day_of_week_names_long: InlineArray[String, 7] = [
        "Lundi", "Mardi", "Mercredi", "Jeudi", "Vendredi", "Samedi", "Dimanche"
    ]
    """Names for the days of the week starting on monday."""
    comptime month_names_short: List[Tuple[Int, String]] = [
        (1, "Janv"), (2, "Févr"), (3, "Mars"), (4, "Avr"), (5, "Mai"),
        (6, "Juin"), (7, "Juil"), (8, "Août"), (9, "Sept"), (10, "Oct"),
        (11, "Nov"), (12, "Déc"),
    ]
    """Names for the months of the year. Alternative names are allowed for
    parsing, but writing prioritizes the first instance of that month number."""
    comptime month_names_long: List[Tuple[Int, String]] = [
        (1, "Janvier"), (2, "Février"), (3, "Mars"), (4, "Avril"), (5, "Mai"),
        (6, "Juin"), (7, "Juillet"), (8, "Août"), (9, "Septembre"),
        (10, "Octobre"), (11, "Novembre"), (12, "Décembre"),
    ]
    """Names for the months of the year. Alternative names are allowed for
    parsing, but writing prioritizes the first instance of that month number."""
    # fmt: on


@fieldwise_init
struct PortugueseDTLocale(NativeDTLocale):
    """A default Portuguese speaking locale."""

    # fmt: off
    comptime day_of_week_names_short: InlineArray[String, 7] = [
        "Seg", "Ter", "Qua", "Qui", "Sex", "Sáb", "Dom"
    ]
    """Names for the days of the week starting on monday."""
    comptime day_of_week_names_long: InlineArray[String, 7] = [
        "Segunda-feira", "Terça-feira", "Quarta-feira", "Quinta-feira", 
        "Sexta-feira", "Sábado", "Domingo"
    ]
    """Names for the days of the week starting on monday."""
    comptime month_names_short: List[Tuple[Int, String]] = [
        (1, "Jan"), (2, "Fev"), (3, "Mar"), (4, "Abr"), (5, "Mai"), (6, "Jun"),
        (7, "Jul"), (8, "Ago"), (9, "Set"), (10, "Out"), (11, "Nov"),
        (12, "Dez"),
    ]
    """Names for the months of the year. Alternative names are allowed for
    parsing, but writing prioritizes the first instance of that month number."""
    comptime month_names_long: List[Tuple[Int, String]] = [
        (1, "Janeiro"), (2, "Fevereiro"), (3, "Março"), (4, "Abril"),
        (5, "Maio"), (6, "Junho"), (7, "Julho"), (8, "Agosto"), (9, "Setembro"),
        (10, "Outubro"), (11, "Novembro"), (12, "Dezembro"),
    ]
    """Names for the months of the year. Alternative names are allowed for
    parsing, but writing prioritizes the first instance of that month number."""
    # fmt: on


@fieldwise_init
struct ChineseDTLocale(NativeDTLocale):
    """A default Mandarin Chinese locale."""

    # fmt: off
    comptime day_of_week_names_short: InlineArray[String, 7] = [
        "周一", "周二", "周三", "周四", "周五", "周六", "周日"
    ]
    """Names for the days of the week starting on monday."""
    comptime day_of_week_names_long: InlineArray[String, 7] = [
        "星期一", "星期二", "星期三", "星期四", "星期五", "星期六", "星期日"
    ]
    """Names for the days of the week starting on monday."""
    comptime month_names_short: List[Tuple[Int, String]] = [
        (1, "1月"), (2, "2月"), (3, "3月"), (4, "4月"), (5, "5月"), (6, "6月"),
        (7, "7月"), (8, "8月"), (9, "9月"), (10, "10月"), (11, "11月"),
        (12, "12月"),
    ]
    """Names for the months of the year. Alternative names are allowed for
    parsing, but writing prioritizes the first instance of that month number."""
    comptime month_names_long: List[Tuple[Int, String]] = [
        (1, "一月"), (2, "二月"), (3, "三月"), (4, "四月"), (5, "五月"),
        (6, "六月"), (7, "七月"), (8, "八月"), (9, "九月"), (10, "十月"),
        (11, "十一月"), (12, "十二月"),
    ]
    """Names for the months of the year. Alternative names are allowed for
    parsing, but writing prioritizes the first instance of that month number."""
    # fmt: on
    comptime AM: String = "上午"
    """String for AM."""
    comptime PM: String = "下午"
    """String for PM."""
    comptime datetime_fmt_str: String = "%Y年%m月%d日 %H:%M:%S"
    """Format string for locale's date and time representation."""
    comptime date_fmt_str: String = "%Y年%m月%d日"
    """Format string for locale's date representation."""


@fieldwise_init
struct JapaneseDTLocale(NativeDTLocale):
    """A default Japanese locale."""

    # fmt: off
    comptime day_of_week_names_short: InlineArray[String, 7] = [
        "月", "火", "水", "木", "金", "土", "日"
    ]
    """Names for the days of the week starting on monday."""
    comptime day_of_week_names_long: InlineArray[String, 7] = [
        "月曜日", "火曜日", "水曜日", "木曜日", "金曜日", "土曜日", "日曜日"
    ]
    """Names for the days of the week starting on monday."""
    comptime month_names_short: List[Tuple[Int, String]] = [
        (1, "1月"), (2, "2月"), (3, "3月"), (4, "4月"), (5, "5月"), (6, "6月"),
        (7, "7月"), (8, "8月"), (9, "9月"), (10, "10月"), (11, "11月"),
        (12, "12月"),
    ]
    """Names for the months of the year. Alternative names are allowed for
    parsing, but writing prioritizes the first instance of that month number."""
    comptime month_names_long: List[Tuple[Int, String]] = [
        (1, "1月"), (2, "2月"), (3, "3月"), (4, "4月"), (5, "5月"), (6, "6月"),
        (7, "7月"), (8, "8月"), (9, "9月"), (10, "10月"), (11, "11月"),
        (12, "12月"),
    ]
    """Names for the months of the year. Alternative names are allowed for
    parsing, but writing prioritizes the first instance of that month number."""
    # fmt: on
    comptime AM: String = "午前"
    """String for AM."""
    comptime PM: String = "午後"
    """String for PM."""
    comptime datetime_fmt_str: String = "%Y年%m月%d日 %H時%M分%S秒"
    """Format string for locale's date and time representation."""
    comptime date_fmt_str: String = "%Y/%m/%d"
    """Format string for locale's date representation."""


@fieldwise_init
struct RussianDTLocale(NativeDTLocale):
    """A default Russian locale favoring format-context (genitive) months."""

    # fmt: off
    comptime day_of_week_names_short: InlineArray[String, 7] = [
        "Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"
    ]
    """Names for the days of the week starting on monday."""
    comptime day_of_week_names_long: InlineArray[String, 7] = [
        "Понедельник", "Вторник", "Среда", "Четверг", "Пятница", "Суббота",
        "Воскресенье",
    ]
    """Names for the days of the week starting on monday."""
    comptime month_names_short: List[Tuple[Int, String]] = [
        (1, "янв"), (2, "фев"), (3, "мар"), (4, "апр"), (5, "мая"), (6, "июн"),
        (7, "июл"), (8, "авг"), (9, "сен"), (10, "окт"), (11, "ноя"),
        (12, "дек"),
    ]
    """Names for the months of the year. Alternative names are allowed for
    parsing, but writing prioritizes the first instance of that month number."""
    comptime month_names_long: List[Tuple[Int, String]] = [
        (1, "января"), (2, "февраля"), (3, "марта"), (4, "апреля"), (5, "мая"),
        (6, "июня"), (7, "июля"), (8, "августа"), (9, "сентября"),
        (10, "октября"), (11, "ноября"), (12, "декабря"),
    ]
    """Names for the months of the year. Alternative names are allowed for
    parsing, but writing prioritizes the first instance of that month number."""
    # fmt: on
    comptime AM: String = "ДП"
    """String for AM."""
    comptime PM: String = "ПП"
    """String for PM."""
    comptime date_fmt_str: String = "%d.%m.%Y"
    """Format string for locale's date representation."""


@fieldwise_init
struct HindiDTLocale(NativeDTLocale):
    """A default Hindi locale."""

    # fmt: off
    comptime day_of_week_names_short: InlineArray[String, 7] = [
        "सोम", "मंगल", "बुध", "गुरु", "शुक्र", "शनि", "रवि"
    ]
    """Names for the days of the week starting on monday."""
    comptime day_of_week_names_long: InlineArray[String, 7] = [
        "सोमवार", "मंगलवार", "बुधवार", "गुरुवार", "शुक्रवार", "शनिवार", "रविवार"
    ]
    """Names for the days of the week starting on monday."""
    comptime month_names_short: List[Tuple[Int, String]] = [
        (1, "जन"), (2, "फ़र"), (3, "मार्च"), (4, "अप्रैल"), (5, "मई"), (6, "जून"),
        (7, "जुल"), (8, "अग"), (9, "सित"), (10, "अक्टू"), (11, "नव"), (12, "दिस"),
    ]
    """Names for the months of the year. Alternative names are allowed for
    parsing, but writing prioritizes the first instance of that month number."""
    comptime month_names_long: List[Tuple[Int, String]] = [
        (1, "जनवरी"), (2, "फ़रवरी"), (3, "मार्च"), (4, "अप्रैल"), (5, "मई"),
        (6, "जून"), (7, "जुलाई"), (8, "अगस्त"), (9, "सितंबर"),
        (10, "अक्टूबर"), (11, "नवंबर"), (12, "दिसंबर"),
    ]
    """Names for the months of the year. Alternative names are allowed for
    parsing, but writing prioritizes the first instance of that month number."""
    # fmt: on
    comptime AM: String = "पूर्वाह्न"
    """String for AM."""
    comptime PM: String = "अपराह्न"
    """String for PM."""


@fieldwise_init
struct ArabicDTLocale(NativeDTLocale):
    """A default Arabic locale."""

    # fmt: off
    comptime day_of_week_names_short: InlineArray[String, 7] = [
        "الاثنين", "الثلاثاء", "الأربعاء", "الخميس", "الجمعة", "السبت", "الأحد"
    ]
    """Names for the days of the week starting on monday."""
    comptime day_of_week_names_long: InlineArray[String, 7] = [
        "الاثنين", "الثلاثاء", "الأربعاء", "الخميس", "الجمعة", "السبت", "الأحد"
    ]
    """Names for the days of the week starting on monday."""
    comptime month_names_short: List[Tuple[Int, String]] = [
        (1, "يناير"), (2, "فبراير"), (3, "مارس"), (4, "أبريل"), (5, "مايو"),
        (6, "يونيو"), (7, "يوليو"), (8, "أغسطس"), (9, "سبتمبر"), (10, "أكتوبر"),
        (11, "نوفمبر"), (12, "ديسمبر"),
    ]
    """Names for the months of the year. Alternative names are allowed for
    parsing, but writing prioritizes the first instance of that month number."""
    comptime month_names_long: List[Tuple[Int, String]] = [
        (1, "يناير"), (2, "فبراير"), (3, "مارس"), (4, "أبريل"), (5, "مايو"),
        (6, "يونيو"), (7, "يوليو"), (8, "أغسطس"), (9, "سبتمبر"), (10, "أكتوبر"),
        (11, "نوفمبر"), (12, "ديسمبر"),
    ]
    """Names for the months of the year. Alternative names are allowed for
    parsing, but writing prioritizes the first instance of that month number."""
    # fmt: on
    comptime AM: String = "ص"
    """String for AM."""
    comptime PM: String = "م"
    """String for PM."""


@fieldwise_init
struct BengaliDTLocale(NativeDTLocale):
    """A default Bengali locale."""

    # fmt: off
    comptime day_of_week_names_short: InlineArray[String, 7] = [
        "সোম", "মঙ্গল", "বুধ", "বৃহস্পতি", "শুক্র", "শনি", "রবি"
    ]
    """Names for the days of the week starting on monday."""
    comptime day_of_week_names_long: InlineArray[String, 7] = [
        "সোমবার", "মঙ্গলবার", "বুধবার", "বৃহস্পতিবার", "শুক্রবার", "শনিবার", "রবিবার"
    ]
    """Names for the days of the week starting on monday."""
    comptime month_names_short: List[Tuple[Int, String]] = [
        (1, "জানু"), (2, "ফেব"), (3, "মার্চ"), (4, "এপ্রিল"), (5, "মে"), (6, "জুন"),
        (7, "জুল"), (8, "আগস্ট"), (9, "সেপ্টে"), (10, "অক্টো"), (11, "নভে"),
        (12, "ডিসে"),
    ]
    """Names for the months of the year. Alternative names are allowed for
    parsing, but writing prioritizes the first instance of that month number."""
    comptime month_names_long: List[Tuple[Int, String]] = [
        (1, "জানুয়ারি"), (2, "ফেব্রুয়ারি"), (3, "মার্চ"), (4, "এপ্রিল"), (5, "মে"),
        (6, "জুন"), (7, "জুলাই"), (8, "আগস্ট"), (9, "সেপ্টেম্বর"), (10, "অক্টোবর"),
        (11, "নভেম্বর"), (12, "ডিসেম্বর"),
    ]
    """Names for the months of the year. Alternative names are allowed for
    parsing, but writing prioritizes the first instance of that month number."""
    # fmt: on
    comptime AM: String = "পূর্বাহ্ণ"
    """String for AM."""
    comptime PM: String = "অপরাহ্ণ"
    """String for PM."""


@fieldwise_init
struct GermanDTLocale(NativeDTLocale):
    """A default German locale."""

    # fmt: off
    comptime day_of_week_names_short: InlineArray[String, 7] = [
        "Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"
    ]
    """Names for the days of the week starting on monday."""
    comptime day_of_week_names_long: InlineArray[String, 7] = [
        "Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag", "Samstag", 
        "Sonntag"
    ]
    """Names for the days of the week starting on monday."""
    comptime month_names_short: List[Tuple[Int, String]] = [
        (1, "Jan"), (2, "Feb"), (3, "Mär"), (4, "Apr"), (5, "Mai"), (6, "Jun"),
        (7, "Jul"), (8, "Aug"), (9, "Sep"), (10, "Okt"), (11, "Nov"),
        (12, "Dez"),
    ]
    """Names for the months of the year. Alternative names are allowed for
    parsing, but writing prioritizes the first instance of that month number."""
    comptime month_names_long: List[Tuple[Int, String]] = [
        (1, "Januar"), (2, "Februar"), (3, "März"), (4, "April"), (5, "Mai"),
        (6, "Juni"), (7, "Juli"), (8, "August"), (9, "September"),
        (10, "Oktober"), (11, "November"), (12, "Dezember"),
    ]
    """Names for the months of the year. Alternative names are allowed for
    parsing, but writing prioritizes the first instance of that month number."""
    # fmt: on
    comptime AM: String = "vorm."
    """String for AM."""
    comptime PM: String = "nachm."
    """String for PM."""
    comptime datetime_fmt_str: String = "%a, %d. %b %Y %H:%M:%S %z"
    """Format string for locale's date and time representation."""
    comptime date_fmt_str: String = "%d.%m.%Y"
    """Format string for locale's date representation."""


@fieldwise_init
struct KoreanDTLocale(NativeDTLocale):
    """A default Korean locale."""

    # fmt: off
    comptime day_of_week_names_short: InlineArray[String, 7] = [
        "월", "화", "수", "목", "금", "토", "일"
    ]
    """Names for the days of the week starting on monday."""
    comptime day_of_week_names_long: InlineArray[String, 7] = [
        "월요일", "화요일", "수요일", "목요일", "금요일", "토요일", "일요일"
    ]
    """Names for the days of the week starting on monday."""
    comptime month_names_short: List[Tuple[Int, String]] = [
        (1, "1월"), (2, "2월"), (3, "3월"), (4, "4월"), (5, "5월"), (6, "6월"),
        (7, "7월"), (8, "8월"), (9, "9월"), (10, "10월"), (11, "11월"),
        (12, "12월"),
    ]
    """Names for the months of the year. Alternative names are allowed for
    parsing, but writing prioritizes the first instance of that month number."""
    comptime month_names_long: List[Tuple[Int, String]] = [
        (1, "1월"), (2, "2월"), (3, "3월"), (4, "4월"), (5, "5월"), (6, "6월"),
        (7, "7월"), (8, "8월"), (9, "9월"), (10, "10월"), (11, "11월"),
        (12, "12월"),
    ]
    """Names for the months of the year. Alternative names are allowed for
    parsing, but writing prioritizes the first instance of that month number."""
    # fmt: on
    comptime AM: String = "오전"
    """String for AM."""
    comptime PM: String = "오후"
    """String for PM."""
    comptime datetime_fmt_str: String = "%Y년 %m월 %d일 %H:%M:%S"
    """Format string for locale's date and time representation."""
    comptime date_fmt_str: String = "%Y-%m-%d"
    """Format string for locale's date representation."""


@fieldwise_init
struct IndonesianDTLocale(NativeDTLocale):
    """A default Indonesian locale."""

    # fmt: off
    comptime day_of_week_names_short: InlineArray[String, 7] = [
        "Sen", "Sel", "Rab", "Kam", "Jum", "Sab", "Min"
    ]
    """Names for the days of the week starting on monday."""
    comptime day_of_week_names_long: InlineArray[String, 7] = [
        "Senin", "Selasa", "Rabu", "Kamis", "Jumat", "Sabtu", "Minggu"
    ]
    """Names for the days of the week starting on monday."""
    comptime month_names_short: List[Tuple[Int, String]] = [
        (1, "Jan"), (2, "Feb"), (3, "Mar"), (4, "Apr"), (5, "Mei"), (6, "Jun"),
        (7, "Jul"), (8, "Agt"), (9, "Sep"), (10, "Okt"), (11, "Nov"),
        (12, "Des"),
    ]
    """Names for the months of the year. Alternative names are allowed for
    parsing, but writing prioritizes the first instance of that month number."""
    comptime month_names_long: List[Tuple[Int, String]] = [
        (1, "Januari"), (2, "Februari"), (3, "Maret"), (4, "April"), (5, "Mei"),
        (6, "Juni"), (7, "Juli"), (8, "Agustus"), (9, "September"),
        (10, "Oktober"), (11, "November"), (12, "Desember"),
    ]
    """Names for the months of the year. Alternative names are allowed for
    parsing, but writing prioritizes the first instance of that month number."""
    # fmt: on
    comptime datetime_fmt_str: String = "%a, %d %b %Y %H:%M:%S"
    """Format string for locale's date and time representation."""


@fieldwise_init
struct ItalianDTLocale(NativeDTLocale):
    """A default Italian locale."""

    # fmt: off
    comptime day_of_week_names_short: InlineArray[String, 7] = [
        "Lun", "Mar", "Mer", "Gio", "Ven", "Sab", "Dom"
    ]
    """Names for the days of the week starting on monday."""
    comptime day_of_week_names_long: InlineArray[String, 7] = [
        "Lunedì", "Martedì", "Mercoledì", "Giovedì", "Venerdì", "Sabato", 
        "Domenica"
    ]
    """Names for the days of the week starting on monday."""
    comptime month_names_short: List[Tuple[Int, String]] = [
        (1, "Gen"), (2, "Feb"), (3, "Mar"), (4, "Apr"), (5, "Mag"), (6, "Giu"),
        (7, "Lug"), (8, "Ago"), (9, "Set"), (10, "Ott"), (11, "Nov"),
        (12, "Dic"),
    ]
    """Names for the months of the year. Alternative names are allowed for
    parsing, but writing prioritizes the first instance of that month number."""
    comptime month_names_long: List[Tuple[Int, String]] = [
        (1, "Gennaio"), (2, "Febbraio"), (3, "Marzo"), (4, "Aprile"), 
        (5, "Maggio"), (6, "Giugno"), (7, "Luglio"), (8, "Agosto"), 
        (9, "Settembre"), (10, "Ottobre"), (11, "Novembre"), (12, "Dicembre"),
    ]
    """Names for the months of the year. Alternative names are allowed for
    parsing, but writing prioritizes the first instance of that month number."""
    # fmt: on
    comptime datetime_fmt_str: String = "%a %d %b %Y %H:%M:%S %z"
    """Format string for locale's date and time representation."""


# ===----------------------------------------------------------------------=== #
# Locale parsing and stringification
# ===----------------------------------------------------------------------=== #


# fmt: off
comptime _allowed_specs_start: InlineArray[Byte, 25] = [
    Byte(ord("w")), Byte(ord("d")), Byte(ord("m")), Byte(ord("y")),
    Byte(ord("Y")), Byte(ord("H")), Byte(ord("I")), Byte(ord("M")),
    Byte(ord("S")), Byte(ord("f")), Byte(ord("z")), Byte(ord("Z")),
    Byte(ord("j")), Byte(ord("W")), Byte(ord("%")), Byte(ord(":")),
    Byte(ord("e")),
    # locale aware
    Byte(ord("a")), Byte(ord("A")), Byte(ord("b")), Byte(ord("B")),
    Byte(ord("p")), Byte(ord("c")), Byte(ord("x")), Byte(ord("X")),
]
# fmt: on


def _is_valid_spec(spec: StringSlice[mut=False, _]) -> Tuple[Bool, String]:
    if spec.byte_length() == 0:
        return False, "Empty format specification"
    var sl_iter = spec.codepoint_slices()
    while True:
        try:
            var s = next(sl_iter)
            if "%" != s:
                continue
            try:
                var next_char = next(sl_iter)
                var b0 = next_char.unsafe_ptr()[0]
                if b0 not in _allowed_specs_start:
                    return False, String(
                        "Unsupported format code: %", next_char
                    )
                if b0 == Byte(ord(":")):
                    next_char2 = next(sl_iter)
                    if next_char2.unsafe_ptr()[0] != Byte(ord("z")):
                        return False, String(
                            "Unsupported format code: %", next_char, next_char2
                        )
            except StopIteration:
                return (False, "Unescaped % character at the end of the string")
        except StopIteration:
            break
    return True, ""


def _write_int_base_10[
    pad_width: Int = 0, pad: StaticString = "0"
](mut writer: Some[Writer], decimal: Scalar):
    # NOTE: can't use Byte(ord()) here due to recursion
    comptime `0` = 0x30
    comptime `-` = 0x2D
    comptime assert pad.byte_length() == 1
    comptime pad_byte = pad.unsafe_ptr()[0]

    comptime dtype = _uint_type_of_width[bit_width_of[decimal.dtype]()]()

    var buf = SIMD[DType.uint8, bit_width_of[dtype]()]()
    var ptr = UnsafePointer(to=buf).bitcast[Byte]()

    var remainder: Scalar[dtype]
    comptime if decimal.dtype.is_signed():
        remainder = {abs(decimal)}
    else:
        remainder = {decimal}

    var i = 0
    while i == 0 or remainder > 0:
        ptr[buf.size - (i + 1)] = `0` | UInt8(remainder % 10)
        remainder //= 10
        i += 1

    comptime if decimal.dtype.is_signed():
        ptr[buf.size - (i + 1)] = `-`
        i += Int(decimal < 0)

    comptime if pad_width > 1:
        while pad_width > i:
            ptr[buf.size - (i + 1)] = pad_byte
            i += 1

    writer.write_string(
        {ptr = UnsafePointer(to=buf).bitcast[Byte]() + buf.size - i, length = i}
    )


def _write_to[
    origin: ImmutOrigin, //, tz_str: String
](
    spec: StringSlice[origin],
    mut writer: Some[Writer],
    dt: _TzNaiveDateTime,
    offset: Offset,
    locale: Some[DTLocale],
):
    var validated = _is_valid_spec(spec)
    assert validated[0], validated[1]

    for is_spec, s in _DTSpecIterator(spec):
        if not is_spec:
            s.write_to(writer)
            continue

        var c = s.unsafe_ptr()[0]
        if c == FormatCode.w.value[0]:
            writer.write(dt.calendar.day_of_week(dt.dt))
        elif c == FormatCode.d.value[0]:
            _write_int_base_10[2](writer, dt.dt.day)
        elif c == FormatCode.e.value[0]:
            _write_int_base_10[2, " "](writer, dt.dt.day)
        elif c == FormatCode.m.value[0]:
            _write_int_base_10[2](writer, dt.dt.month)
        elif c == FormatCode.y.value[0]:
            _write_int_base_10[2](writer, dt.dt.year % 100)
        elif c == FormatCode.Y.value[0]:
            _write_int_base_10[4](writer, dt.dt.year)
        elif c == FormatCode.H.value[0]:
            _write_int_base_10[2](writer, dt.dt.hour)
        elif c == FormatCode.I.value[0]:
            var h = dt.dt.hour % 12
            h += UInt8(12 if h == 0 else 0)
            _write_int_base_10[2](writer, h)
        elif c == FormatCode.M.value[0]:
            _write_int_base_10[2](writer, dt.dt.minute)
        elif c == FormatCode.S.value[0]:
            _write_int_base_10[2](writer, dt.dt.second)
        elif c == FormatCode.f.value[0]:
            _write_int_base_10[6](
                writer, dt.dt.m_second * 1000 + dt.dt.u_second
            )
        elif c == FormatCode.j.value[0]:
            _write_int_base_10[3](writer, dt.calendar.day_of_year(dt.dt))
        elif c == FormatCode.W.value[0]:
            _write_int_base_10[2](writer, dt.calendar.week_of_year(dt.dt))
        elif c == FormatCode.z.value[0]:
            writer.write("+" if offset.is_east_utc else "-")
            _write_int_base_10[2](writer, offset.hours)
            _write_int_base_10[2](writer, offset.minutes)
        elif c == FormatCode.`:z`.value[0]:
            if not s == ":z":
                abort(t"Unsupported format code: '{s}'")
            writer.write(offset)
        elif c == FormatCode.Z.value[0]:
            writer.write(tz_str)
        elif c == FormatCode.`%`.value[0]:
            writer.write("%")
        elif c == FormatCode.a.value[0]:
            locale.day_of_week_short(writer, dt)
        elif c == FormatCode.A.value[0]:
            locale.day_of_week_long(writer, dt)
        elif c == FormatCode.b.value[0]:
            locale.month_short(writer, dt)
        elif c == FormatCode.B.value[0]:
            locale.month_long(writer, dt)
        elif c == FormatCode.p.value[0]:
            locale.am_pm(writer, dt)
        else:
            var fmt_str: String
            if c == FormatCode.c.value[0]:
                fmt_str = locale.datetime_fmt[dt.calendar]()
            elif c == FormatCode.x.value[0]:
                fmt_str = locale.date_fmt[dt.calendar]()
            elif c == FormatCode.X.value[0]:
                fmt_str = locale.time_fmt[dt.calendar]()
            else:
                abort(t"Unsupported format code: '{s}'")
            _write_to[tz_str](fmt_str, writer, dt, offset, locale)


def _write_to[
    spec: String, tz_str: String, locale_t: DTLocale
](
    mut writer: Some[Writer],
    dt: _TzNaiveDateTime,
    offset: Offset,
    loc: locale_t,
):
    comptime validated = _is_valid_spec(spec)
    comptime assert validated[0], validated[1]

    comptime for is_spec, s in _DTSpecIterator(spec):
        comptime if not is_spec:
            writer.write(s)
            continue

        comptime c = s.unsafe_ptr()[0]
        comptime if c == FormatCode.w.value[0]:
            writer.write(dt.calendar.day_of_week(dt.dt))
        elif c == FormatCode.d.value[0]:
            _write_int_base_10[2](writer, dt.dt.day)
        elif c == FormatCode.e.value[0]:
            _write_int_base_10[2, " "](writer, dt.dt.day)
        elif c == FormatCode.m.value[0]:
            _write_int_base_10[2](writer, dt.dt.month)
        elif c == FormatCode.y.value[0]:
            _write_int_base_10[2](writer, dt.dt.year % 100)
        elif c == FormatCode.Y.value[0]:
            _write_int_base_10[4](writer, dt.dt.year)
        elif c == FormatCode.H.value[0]:
            _write_int_base_10[2](writer, dt.dt.hour)
        elif c == FormatCode.I.value[0]:
            var h = dt.dt.hour % 12
            h += UInt8(12 if h == 0 else 0)
            _write_int_base_10[2](writer, h)
        elif c == FormatCode.M.value[0]:
            _write_int_base_10[2](writer, dt.dt.minute)
        elif c == FormatCode.S.value[0]:
            _write_int_base_10[2](writer, dt.dt.second)
        elif c == FormatCode.f.value[0]:
            _write_int_base_10[6](
                writer, dt.dt.m_second * 1000 + dt.dt.u_second
            )
        elif c == FormatCode.j.value[0]:
            _write_int_base_10[3](writer, dt.calendar.day_of_year(dt.dt))
        elif c == FormatCode.W.value[0]:
            _write_int_base_10[2](writer, dt.calendar.week_of_year(dt.dt))
        elif c == FormatCode.z.value[0]:
            writer.write("+" if offset.is_east_utc else "-")
            _write_int_base_10[2](writer, offset.hours)
            _write_int_base_10[2](writer, offset.minutes)
        elif c == FormatCode.`:z`.value[0]:
            comptime assert s == ":z", t"Unsupported format code: '{s}'"
            writer.write(offset)
        elif c == FormatCode.Z.value[0]:
            writer.write(tz_str)
        elif c == FormatCode.`%`.value[0]:
            writer.write("%")
        elif c == FormatCode.a.value[0]:
            loc.day_of_week_short(writer, dt)
        elif c == FormatCode.A.value[0]:
            loc.day_of_week_long(writer, dt)
        elif c == FormatCode.b.value[0]:
            loc.month_short(writer, dt)
        elif c == FormatCode.B.value[0]:
            loc.month_long(writer, dt)
        elif c == FormatCode.p.value[0]:
            loc.am_pm(writer, dt)
        elif conforms_to(locale_t, NativeDTLocale):

            @always_inline
            def write_to[
                fmt_str: String
            ]() {mut writer, read dt, read offset, read loc}:
                _write_to[fmt_str, tz_str, locale_t](writer, dt, offset)

            comptime loc_t = type_of(
                trait_downcast_var[NativeDTLocale](locale_t())
            )

            comptime if c == FormatCode.c.value[0]:
                write_to[loc_t.datetime_fmt_str]()
            elif c == FormatCode.x.value[0]:
                write_to[loc_t.date_fmt_str]()
            elif c == FormatCode.X.value[0]:
                write_to[loc_t.time_fmt_str]()
            else:
                comptime assert False, t"Unsupported format code: '{s}'"
        else:
            var fmt_str: String
            comptime if c == FormatCode.c.value[0]:
                fmt_str = loc.datetime_fmt[dt.calendar]()
            elif c == FormatCode.x.value[0]:
                fmt_str = loc.date_fmt[dt.calendar]()
            elif c == FormatCode.X.value[0]:
                fmt_str = loc.time_fmt[dt.calendar]()
            else:
                comptime assert False, t"Unsupported format code: '{s}'"
            _write_to[tz_str](fmt_str, writer, dt, offset, loc)


@always_inline
def _write_to_iso[
    spec: String
](mut writer: Some[Writer], dt: _TzNaiveDateTime, offset: Offset):
    comptime `0` = Byte(ord("0"))
    comptime `+` = Byte(ord("+"))
    comptime `-` = Byte(ord("-"))
    comptime `:` = Byte(ord(":"))
    comptime `T` = Byte(ord("T"))
    comptime ` ` = Byte(ord(" "))

    @always_inline
    def vec[
        *Ts: type_of(Byte)
    ](*args: *Ts, out res: SIMD[DType.uint8, next_power_of_two(Ts.size)]):
        res = {}
        comptime for i in range(Ts.size):
            res[i] = args[i]

    @always_inline
    def to_str(
        ref vec: SIMD[DType.uint8, _], length: Int = vec.size
    ) -> StringSlice[origin_of(vec)]:
        return {ptr = UnsafePointer(to=vec).bitcast[Byte](), length = length}

    var yyyy = `0` | UInt8(dt.dt.year // 1000)
    var yyy_base = dt.dt.year % 1000
    var yyy = `0` | UInt8(yyy_base // 100)
    var yy_base = yyy_base % 100
    var yy = `0` | UInt8(yy_base // 10)
    var y = `0` | UInt8(yy_base % 10)
    var monmon = `0` | UInt8(dt.dt.month // 10)
    var mon = `0` | UInt8(dt.dt.month % 10)
    var dd = `0` | UInt8(dt.dt.day // 10)
    var d = `0` | UInt8(dt.dt.day % 10)
    var hh = `0` | UInt8(dt.dt.hour // 10)
    var h = `0` | UInt8(dt.dt.hour % 10)
    var mm = `0` | UInt8(dt.dt.minute // 10)
    var m = `0` | UInt8(dt.dt.minute % 10)
    var ss = `0` | UInt8(dt.dt.second // 10)
    var s = `0` | UInt8(dt.dt.second % 10)

    comptime if spec == IsoFormat.YYYYMMDD:
        var res = vec(yyyy, yyy, yy, y, monmon, mon, dd, d)
        writer.write_string(to_str(res))
    elif spec == IsoFormat.YYYY_MM_DD:
        var res = vec(yyyy, yyy, yy, y, `-`, monmon, mon, `-`, dd, d)
        writer.write_string(to_str(res, 10))
    elif spec == IsoFormat.HHMMSS:
        var hhmmss = vec(hh, h, mm, m, ss, s)
        writer.write_string(to_str(hhmmss, 6))
    elif spec == IsoFormat.HH_MM_SS:
        var res = vec(hh, h, `:`, mm, m, `:`, ss, s)
        writer.write_string(to_str(res))
    elif spec == IsoFormat.YYYYMMDDHHMMSS:
        var res = vec(yyyy, yyy, yy, y, monmon, mon, dd, d, hh, h, mm, m, ss, s)
        writer.write_string(to_str(res, 14))
    elif spec == IsoFormat.YYYYMMDDHHMMSSTZD:
        var sign = Scalar[DType.bool](offset.is_east_utc).select(`+`, `-`)
        # fmt: off
        var res = vec(
            yyyy, yyy, yy, y, monmon, mon, dd, d, hh, h, mm, m, ss, s,
            sign, `0` | (offset.hours // 10), `0` | (offset.hours % 10),
            `0` | (offset.minutes // 10), `0` | (offset.minutes % 10),
        )
        # fmt: on
        writer.write_string(to_str(res, 19))
    elif spec == IsoFormat.YYYY_MM_DD___HH_MM_SS:
        # fmt: off
        var res = vec(
            yyyy, yyy, yy, y, `-`, monmon, mon, `-`, dd, d, ` `,
            hh, h, `:`, mm, m, `:`, ss, s,
        )
        # fmt: on
        writer.write_string(to_str(res, 19))
    elif spec == IsoFormat.YYYY_MM_DD_T_HH_MM_SS:
        # fmt: off
        var res = vec(
            yyyy, yyy, yy, y, `-`, monmon, mon, `-`, dd, d, `T`,
            hh, h, `:`, mm, m, `:`, ss, s,
        )
        # fmt: on
        writer.write_string(to_str(res, 19))
    elif spec == IsoFormat.YYYY_MM_DD_T_HH_MM_SS_TZD:
        var sign = Scalar[DType.bool](offset.is_east_utc).select(`+`, `-`)
        # fmt: off
        var res = vec(
            yyyy, yyy, yy, y, `-`, monmon, mon, `-`, dd, d, `T`,
            hh, h, `:`, mm, m, `:`, ss, s,
            sign, `0` | (offset.hours // 10), `0` | (offset.hours % 10), `:`,
            `0` | (offset.minutes // 10), `0` | (offset.minutes % 10),
        )
        # fmt: on
        writer.write_string(to_str(res, 25))
    else:
        comptime assert False, "IsoFormat not implemented."


@always_inline
def _write_to[
    spec: String, tz_str: String, locale_t: DTLocale
](
    mut writer: Some[Writer],
    dt: _TzNaiveDateTime,
    offset: Offset,
    var locale: Optional[locale_t] = None,
):
    comptime validated = _is_valid_spec(spec)
    comptime assert validated[0], validated[1]

    comptime if spec in [
        IsoFormat.YYYYMMDD,
        IsoFormat.YYYY_MM_DD,
        IsoFormat.HHMMSS,
        IsoFormat.HH_MM_SS,
        IsoFormat.YYYYMMDDHHMMSS,
        IsoFormat.YYYYMMDDHHMMSSTZD,
        IsoFormat.YYYY_MM_DD___HH_MM_SS,
        IsoFormat.YYYY_MM_DD_T_HH_MM_SS,
        IsoFormat.YYYY_MM_DD_T_HH_MM_SS_TZD,
    ]:
        _write_to_iso[spec](writer, dt, offset)
    else:
        var buf = _WriteBufferStack(writer)
        var loc = locale^.or_else({})
        _write_to[spec, tz_str](buf, dt, offset, loc)
        buf.flush()


@always_inline
def _slice(
    read_from: StringSlice[mut=False, _], *, start: Int
) -> type_of(read_from):
    return {
        ptr = read_from.unsafe_ptr() + start,
        length = read_from.byte_length() - start,
    }


@always_inline
def _slice(
    read_from: StringSlice[mut=False, _], *, end: Int
) -> type_of(read_from):
    return {ptr = read_from.unsafe_ptr(), length = end}


def _parse_pure_int[
    end: Int, dtype: DType
](read_from: StringSlice[mut=False, _]) raises -> Scalar[dtype]:
    comptime `0` = Byte(ord("0"))
    comptime `9` = Byte(ord("9"))

    if read_from.byte_length() < end:
        raise Error(
            "Input string is shorter than what the format code requires."
        )
    var ptr = read_from.unsafe_ptr()
    var res = Scalar[dtype](0)
    var i = 0
    while i < end:
        res *= 10
        var val = ptr[i]
        if not (`0` <= val <= `9`):
            raise Error(
                t"Unexpected character in: '{_slice(read_from, end=end)}'"
            )
        res += Scalar[dtype](val & 0x0F)
        i += 1

    return res


def _parse_num_or_raise[
    end: Int,
    min_value: Scalar,
    max_value: type_of(min_value),
    value_str: String,
](read_from: StringSlice[mut=False, _]) raises -> Tuple[
    UInt16, type_of(read_from)
]:
    comptime v_in = "The value is expected to be in the range"
    var value = _parse_pure_int[end, min_value.dtype](read_from)
    if not (min_value <= value <= max_value):
        raise Error(t"{v_in} {min_value} <= {value_str} <= {max_value}")
    return UInt16(value), _slice(read_from, start=end)


def _parse[
    zone_info_t: UTCZoneInfo,
    //,
    calendar: Calendar,
    zone_info_dict: Dict[String, zone_info_t],
    locale_t: DTLocale = GenericEnglishDTLocale,
](
    spec: String,
    var read_from: StringSlice[mut=False, _],
    mut dt: _TzNaiveDateTime,
    locale: locale_t,
    mut days_to_add: UInt16,
    mut hours_to_add: Int8,
    mut zone_info: Optional[zone_info_t],
    mut offset: Offset,
) raises:
    var validated = _is_valid_spec(spec)
    assert validated[0], validated[1]

    for is_spec, s in _DTSpecIterator(spec):
        if not is_spec:
            if read_from.byte_length() < s.byte_length():
                raise Error("Input string is shorter than the format spec.")
            elif read_from.byte_length() > s.byte_length():
                read_from = _slice(read_from, start=s.byte_length())
            continue

        var c = s.unsafe_ptr()[0]
        if c == FormatCode.w.value[0]:
            comptime DoW = DayOfWeek[dt.calendar]
            var dow, sl = _parse_num_or_raise[
                1, DoW.min_raw_value, DoW.max_raw_value, "day of week"
            ](read_from)
            days_to_add += dow
            read_from = sl
        elif c == FormatCode.d.value[0] or c == FormatCode.e.value[0]:
            var day, sl = _parse_num_or_raise[
                2,
                dt.calendar.min_day,
                dt.calendar.max_possible_days_in_month,
                "day",
            ](read_from)
            dt.dt.day = UInt8(day)
            read_from = sl
        elif c == FormatCode.m.value[0]:
            var month, sl = _parse_num_or_raise[
                2, dt.calendar.min_month, dt.calendar.max_month, "month"
            ](read_from)
            dt.dt.month = UInt8(month)
            read_from = sl
        elif c == FormatCode.y.value[0]:
            var year, sl = _parse_num_or_raise[
                2, dt.calendar.min_year, dt.calendar.max_year, "year"
            ](read_from)
            dt.dt.year = year
            read_from = sl
        elif c == FormatCode.Y.value[0]:
            var year, sl = _parse_num_or_raise[
                4, dt.calendar.min_year, dt.calendar.max_year, "year"
            ](read_from)
            dt.dt.year = year
            read_from = sl
        elif c == FormatCode.H.value[0] or c == FormatCode.I.value[0]:
            var hour, sl = _parse_num_or_raise[
                2, dt.calendar.min_hour, dt.calendar.max_hour, "hour"
            ](read_from)
            dt.dt.hour = UInt8(hour)
            read_from = sl
        elif c == FormatCode.M.value[0]:
            var minute, sl = _parse_num_or_raise[
                2, dt.calendar.min_minute, dt.calendar.max_minute, "minute"
            ](read_from)
            dt.dt.minute = UInt8(minute)
            read_from = sl
        elif c == FormatCode.S.value[0]:
            var second, sl = _parse_num_or_raise[
                2,
                dt.calendar.min_second,
                dt.calendar.max_possible_second,
                "second",
            ](read_from)
            dt.dt.second = UInt8(second)
            read_from = sl
        elif c == FormatCode.f.value[0]:
            var millisecond, sl0 = _parse_num_or_raise[
                3,
                dt.calendar.min_millisecond,
                dt.calendar.max_millisecond,
                "millisecond",
            ](read_from)
            dt.dt.m_second = millisecond
            var microsecond, sl = _parse_num_or_raise[
                3,
                dt.calendar.min_microsecond,
                dt.calendar.max_microsecond,
                "microsecond",
            ](sl0)
            dt.dt.u_second = microsecond
            read_from = sl
        elif c == FormatCode.j.value[0]:
            var doy, sl = _parse_num_or_raise[
                3,
                UInt16(dt.calendar.min_day),
                dt.calendar.max_possible_days_in_year,
                "day of year",
            ](read_from)
            days_to_add += doy
            read_from = sl
        elif c == FormatCode.W.value[0]:
            var woy, sl = _parse_num_or_raise[
                2,
                dt.calendar.min_weeks_in_year,
                dt.calendar.max_possible_weeks_in_year,
                "week of year",
            ](read_from)
            days_to_add += (woy - UInt16(dt.calendar.min_weeks_in_year)) * 7
            read_from = sl
        elif c == FormatCode.z.value[0]:
            var of, length = Offset.parse(read_from)
            offset = of
            read_from = _slice(read_from, start=length)
        elif c == FormatCode.`:z`.value[0]:
            if not s == ":z":
                raise Error(t"Unsupported format code: '{s}'")
            var of, length = Offset.parse(read_from)
            offset = of
            read_from = _slice(read_from, start=length)
        elif c == FormatCode.Z.value[0]:
            var idx = read_from.find(" ")
            var maybe_tz_str = (
                _slice(read_from, end=idx) if idx != -1 else read_from
            )
            # FIXME: for some reason support for this was blocked
            # var maybe_zone_info = global_constant[zone_info_dict]().get(
            #     String(maybe_tz_str)  # FIXME: we don't need to allocate here
            # )
            var maybe_zone_info = materialize[zone_info_dict]().get(
                String(maybe_tz_str)
            )
            if not maybe_zone_info:
                raise Error(
                    "Can't find zone info for timezone string '{maybe_tz_str}'"
                )
            zone_info = maybe_zone_info.value()
            read_from = _slice(read_from, start=maybe_tz_str.byte_length())
        elif c == FormatCode.`%`.value[0]:
            if not read_from.startswith("%"):
                raise Error("Expected a '%' character")
            read_from = read_from[byte=1:]
        elif c == FormatCode.a.value[0]:
            var _, bytes_read = locale.parse_day_of_week_short[calendar](
                read_from
            )
            read_from = _slice(read_from, start=bytes_read)
        elif c == FormatCode.A.value[0]:
            var _, bytes_read = locale.parse_day_of_week_long[calendar](
                read_from
            )
            read_from = _slice(read_from, start=bytes_read)
        elif c == FormatCode.b.value[0]:
            var month, bytes_read = locale.parse_month_short[calendar](
                read_from
            )
            dt.dt.month = month
            read_from = _slice(read_from, start=bytes_read)
        elif c == FormatCode.B.value[0]:
            var month, bytes_read = locale.parse_month_long[calendar](read_from)
            dt.dt.month = month
            read_from = _slice(read_from, start=bytes_read)
        elif c == FormatCode.p.value[0]:
            var is_pm, bytes_read = locale.parse_am_pm[calendar](read_from)
            comptime middle = (
                dt.calendar.max_hour - dt.calendar.min_hour + 1
            ) // 2
            hours_to_add += Int8(
                (12 if is_pm else 0) if (dt.dt.hour != middle) else (
                    0 if is_pm else -12
                )
            )
            read_from = _slice(read_from, start=bytes_read)
        else:
            var fmt_str: String
            if c == FormatCode.c.value[0]:
                fmt_str = locale.datetime_fmt[calendar]()
            elif c == FormatCode.x.value[0]:
                fmt_str = locale.date_fmt[calendar]()
            elif c == FormatCode.X.value[0]:
                fmt_str = locale.time_fmt[calendar]()
            else:
                raise Error(t"Unsupported format code: '{s}'")
            _parse[calendar, zone_info_dict](
                fmt_str,
                read_from,
                dt,
                locale,
                days_to_add,
                hours_to_add,
                zone_info,
                offset,
            )


def _parse[
    zone_info_t: UTCZoneInfo,
    //,
    spec: String,
    calendar: Calendar,
    zone_info_dict: Dict[String, zone_info_t],
    locale_t: DTLocale,
](
    mut read_from: StringSlice[mut=False, _],
    mut dt: _TzNaiveDateTime,
    loc: locale_t,
    mut days_to_add: UInt16,
    mut hours_to_add: Int8,
    mut zone_info: Optional[zone_info_t],
    mut offset: Offset,
) raises:
    comptime validated = _is_valid_spec(spec)
    comptime assert validated[0], validated[1]

    comptime for is_spec, s in _DTSpecIterator(spec):
        comptime if not is_spec:
            if read_from.byte_length() < s.byte_length():
                raise Error("Input string is shorter than the format spec.")
            read_from = _slice(read_from, start=s.byte_length())
            continue

        comptime c = s.unsafe_ptr()[0]
        comptime if c == FormatCode.w.value[0]:
            comptime DoW = DayOfWeek[dt.calendar]
            var dow, sl = _parse_num_or_raise[
                1, DoW.min_raw_value, DoW.max_raw_value, "day of week"
            ](read_from)
            days_to_add += dow
            read_from = sl
        elif c == FormatCode.d.value[0] or c == FormatCode.e.value[0]:
            var day, sl = _parse_num_or_raise[
                2,
                dt.calendar.min_day,
                dt.calendar.max_possible_days_in_month,
                "day",
            ](read_from)
            dt.dt.day = UInt8(day)
            read_from = sl
        elif c == FormatCode.m.value[0]:
            var month, sl = _parse_num_or_raise[
                2, dt.calendar.min_month, dt.calendar.max_month, "month"
            ](read_from)
            dt.dt.month = UInt8(month)
            read_from = sl
        elif c == FormatCode.y.value[0]:
            var year, sl = _parse_num_or_raise[
                2, dt.calendar.min_year, dt.calendar.max_year, "year"
            ](read_from)
            dt.dt.year = year
            read_from = sl
        elif c == FormatCode.Y.value[0]:
            var year, sl = _parse_num_or_raise[
                4, dt.calendar.min_year, dt.calendar.max_year, "year"
            ](read_from)
            dt.dt.year = year
            read_from = sl
        elif c == FormatCode.H.value[0] or c == FormatCode.I.value[0]:
            var hour, sl = _parse_num_or_raise[
                2, dt.calendar.min_hour, dt.calendar.max_hour, "hour"
            ](read_from)
            dt.dt.hour = UInt8(hour)
            read_from = sl
        elif c == FormatCode.M.value[0]:
            var minute, sl = _parse_num_or_raise[
                2, dt.calendar.min_minute, dt.calendar.max_minute, "minute"
            ](read_from)
            dt.dt.minute = UInt8(minute)
            read_from = sl
        elif c == FormatCode.S.value[0]:
            var second, sl = _parse_num_or_raise[
                2,
                dt.calendar.min_second,
                dt.calendar.max_possible_second,
                "second",
            ](read_from)
            dt.dt.second = UInt8(second)
            read_from = sl
        elif c == FormatCode.f.value[0]:
            var millisecond, sl0 = _parse_num_or_raise[
                3,
                dt.calendar.min_millisecond,
                dt.calendar.max_millisecond,
                "millisecond",
            ](read_from)
            dt.dt.m_second = millisecond
            var microsecond, sl = _parse_num_or_raise[
                3,
                dt.calendar.min_microsecond,
                dt.calendar.max_microsecond,
                "microsecond",
            ](sl0)
            dt.dt.u_second = microsecond
            read_from = sl
        elif c == FormatCode.j.value[0]:
            var doy, sl = _parse_num_or_raise[
                3,
                UInt16(dt.calendar.min_day),
                dt.calendar.max_possible_days_in_year,
                "day of year",
            ](read_from)
            days_to_add += doy - UInt16(dt.calendar.min_day)
            read_from = sl
        elif c == FormatCode.W.value[0]:
            var woy, sl = _parse_num_or_raise[
                2,
                dt.calendar.min_weeks_in_year,
                dt.calendar.max_possible_weeks_in_year,
                "week of year",
            ](read_from)
            days_to_add += (woy - UInt16(dt.calendar.min_weeks_in_year)) * 7
            read_from = sl
        elif c == FormatCode.z.value[0]:
            var of, length = Offset.parse(read_from)
            offset = of
            read_from = _slice(read_from, start=length)
        elif c == FormatCode.`:z`.value[0]:
            comptime assert s == ":z", t"Unsupported format code: '{s}'"
            var of, length = Offset.parse(read_from)
            offset = of
            read_from = _slice(read_from, start=length)
        elif c == FormatCode.Z.value[0]:
            var idx = read_from.find(" ")
            var maybe_tz_str = (
                _slice(read_from, end=idx) if idx != -1 else read_from
            )
            # FIXME: for some reason support for this was blocked
            # var maybe_zone_info = global_constant[zone_info_dict]().get(
            #     String(maybe_tz_str)  # FIXME: we don't need to allocate here
            # )
            var maybe_zone_info = materialize[zone_info_dict]().get(
                String(maybe_tz_str)
            )
            if not maybe_zone_info:
                raise Error(
                    "Can't find zone info for timezone string '{maybe_tz_str}'"
                )
            zone_info = maybe_zone_info.value()
            read_from = _slice(read_from, start=maybe_tz_str.byte_length())
        elif c == FormatCode.`%`.value[0]:
            if not read_from.startswith("%"):
                raise Error("Expected a '%' character")
            read_from = read_from[byte=1:]
        elif c == FormatCode.a.value[0]:
            var _, bytes_read = loc.parse_day_of_week_short[calendar](read_from)
            read_from = _slice(read_from, start=bytes_read)
        elif c == FormatCode.A.value[0]:
            var _, bytes_read = loc.parse_day_of_week_long[calendar](read_from)
            read_from = _slice(read_from, start=bytes_read)
        elif c == FormatCode.b.value[0]:
            var month, bytes_read = loc.parse_month_short[calendar](read_from)
            dt.dt.month = month
            read_from = _slice(read_from, start=bytes_read)
        elif c == FormatCode.B.value[0]:
            var month, bytes_read = loc.parse_month_long[calendar](read_from)
            dt.dt.month = month
            read_from = _slice(read_from, start=bytes_read)
        elif c == FormatCode.p.value[0]:
            comptime assert (
                "%I" in spec
            ), "Expected a '%I' format spec when a '%p' is present"
            var is_pm, bytes_read = loc.parse_am_pm[calendar](read_from)
            comptime middle = (
                dt.calendar.max_hour - dt.calendar.min_hour + 1
            ) // 2
            hours_to_add += Int8(
                (12 if is_pm else 0) if (dt.dt.hour != middle) else (
                    0 if is_pm else -12
                )
            )
            read_from = _slice(read_from, start=bytes_read)
        elif conforms_to(locale_t, NativeDTLocale):

            @always_inline
            def parse[fmt_str: String]() raises {mut, read loc}:
                _parse[fmt_str, calendar, zone_info_dict, locale_t](
                    read_from,
                    dt,
                    loc,
                    days_to_add,
                    hours_to_add,
                    zone_info,
                    offset,
                )

            comptime loc_t = type_of(trait_downcast[NativeDTLocale](loc))

            comptime if c == FormatCode.c.value[0]:
                parse[loc_t.datetime_fmt_str]()
            elif c == FormatCode.x.value[0]:
                parse[loc_t.date_fmt_str]()
            elif c == FormatCode.X.value[0]:
                parse[loc_t.time_fmt_str]()
            else:
                comptime assert False, t"Unsupported format code: '{s}'"
        else:
            var fmt_str: String
            comptime if c == FormatCode.c.value[0]:
                fmt_str = loc.datetime_fmt[calendar]()
            elif c == FormatCode.x.value[0]:
                fmt_str = loc.date_fmt[calendar]()
            elif c == FormatCode.X.value[0]:
                fmt_str = loc.time_fmt[calendar]()
            else:
                comptime assert False, t"Unsupported format code: '{s}'"
            _parse[calendar, zone_info_dict](
                fmt_str,
                read_from,
                dt,
                loc,
                days_to_add,
                hours_to_add,
                zone_info,
                offset,
            )


def _parse[
    zone_info_t: UTCZoneInfo,
    //,
    spec: String,
    calendar: Calendar,
    zone_info_dict: Dict[String, zone_info_t],
    locale_t: DTLocale,
](
    read_from_in: StringSlice[mut=False, _],
    var locale: Optional[locale_t] = None,
) raises -> _TzNaiveDateTime[calendar]:
    comptime validated = _is_valid_spec(spec)
    comptime assert validated[0], validated[1]

    var read_from = read_from_in.copy()
    var dt = _TzNaiveDateTime[calendar]()

    var loc = locale^.or_else({})

    var offset = Offset()
    var days_to_add = UInt16(0)
    var hours_to_add = Int8(0)
    var zone_info = Optional[zone_info_t](None)

    _parse[spec, calendar, zone_info_dict, locale_t](
        read_from, dt, loc, days_to_add, hours_to_add, zone_info, offset
    )

    # NOTE: When parsing any date that has relative days from a given offset
    # wait until we've parsed the whole string so that any ordering of the
    # elements results in the same final datetime.
    if days_to_add > 0:
        dt = dt.add(days=UInt64(days_to_add))
    if hours_to_add < 0:
        dt = dt.subtract(hours=UInt64(abs(hours_to_add)))
    elif hours_to_add > 0:
        dt = dt.add(hours=UInt64(hours_to_add))

    # NOTE: When a timezone string is specified and is either preceded or
    # followed by a raw offset, we interpret it as meaning an offset
    # relative to that timezone string.
    if zone_info:
        offset += zone_info.unsafe_value().offset_at_local_time(dt)
    if offset != Offset():
        dt = offset.local_to_utc(dt)

    return dt
