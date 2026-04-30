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
"""Nanosecond resolution `DateTime` module."""
from std.time import time
from std.utils import Variant
from std.collections.optional import Optional

from .calendar import (
    Calendar,
    UTCCalendar,
    CalendarHashes,
    PythonCalendar,
    _NaiveDateTime,
)
from .timezone import TimeZone, TZ_UTC
from .timedelta import TimeDelta, SITimeUnit
from .locale import (
    IsoFormat,
    _write_to,
    _parse,
    DTLocale,
    GenericEnglishDTLocale,
)
from .zoneinfo import UTCZoneInfo, gregorian_zoneinfo
from ._tz_naive_datetime import _TzNaiveDateTime


@fieldwise_init
struct DayOfWeek[calendar: Calendar = PythonCalendar](
    Comparable, ImplicitlyCopyable
):
    """A struct representing a calendar-aware day of the week.

    Parameters:
        calendar: The calendar to use.
    """

    comptime MONDAY = Self(Self.calendar.MONDAY)
    """Monday value for this calendar."""
    comptime TUESDAY = Self(Self.calendar.TUESDAY)
    """Tuesday value for this calendar."""
    comptime WEDNESDAY = Self(Self.calendar.WEDNESDAY)
    """Wednesday value for this calendar."""
    comptime THURSDAY = Self(Self.calendar.THURSDAY)
    """Thursday value for this calendar."""
    comptime FRIDAY = Self(Self.calendar.FRIDAY)
    """Friday value for this calendar."""
    comptime SATURDAY = Self(Self.calendar.SATURDAY)
    """Saturday value for this calendar."""
    comptime SUNDAY = Self(Self.calendar.SUNDAY)
    """Sunday value for this calendar."""

    comptime min_raw_value = min(
        Self.MONDAY.value,
        Self.TUESDAY.value,
        Self.WEDNESDAY.value,
        Self.THURSDAY.value,
        Self.FRIDAY.value,
        Self.SATURDAY.value,
        Self.SUNDAY.value,
    )
    """The minimum raw value for a `DayOfWeek` in this calendar."""
    comptime max_raw_value = max(
        Self.MONDAY.value,
        Self.TUESDAY.value,
        Self.WEDNESDAY.value,
        Self.THURSDAY.value,
        Self.FRIDAY.value,
        Self.SATURDAY.value,
        Self.SUNDAY.value,
    )
    """The maximum raw value for a `DayOfWeek` in this calendar."""

    var value: UInt8
    """The raw value in the `DayOfWeek`."""

    @always_inline
    def __init__(dt: _TzNaiveDateTime, out self: DayOfWeek[dt.calendar]):
        """Construct a `DayOfWeek` from a datetime.

        Args:
            dt: The datetime.
        """
        self = {dt.calendar.day_of_week(dt.dt)}

    @always_inline
    def __init__(dt: DateTime, out self: DayOfWeek[dt.calendar]):
        """Construct a `DayOfWeek` from a datetime.

        Args:
            dt: The datetime.
        """
        self = {dt.calendar.day_of_week(dt._to_naive_datetime())}

    @always_inline
    def __eq__(self, other: Self) -> Bool:
        """Compare the `DayOfWeek` with another instance.

        Args:
            other: The other `DayOfWeek`.

        Returns:
            The result.
        """
        return self.value == other.value

    @always_inline
    def __lt__(self, other: Self) -> Bool:
        """Compare the `DayOfWeek` with another instance.

        Args:
            other: The other `DayOfWeek`.

        Returns:
            The result.
        """
        return self.value < other.value

    @always_inline
    def is_monday(self) -> Bool:
        """Whether the `DayOfWeek` is monday.

        Returns:
            The result.
        """
        return self == Self.MONDAY

    @always_inline
    def is_tuesday(self) -> Bool:
        """Whether the `DayOfWeek` is tuesday.

        Returns:
            The result.
        """
        return self == Self.TUESDAY

    @always_inline
    def is_wednesday(self) -> Bool:
        """Whether the `DayOfWeek` is wednesday.

        Returns:
            The result.
        """
        return self == Self.WEDNESDAY

    @always_inline
    def is_thursday(self) -> Bool:
        """Whether the `DayOfWeek` is thursday.

        Returns:
            The result.
        """
        return self == Self.THURSDAY

    @always_inline
    def is_friday(self) -> Bool:
        """Whether the `DayOfWeek` is friday.

        Returns:
            The result.
        """
        return self == Self.FRIDAY

    @always_inline
    def is_saturday(self) -> Bool:
        """Whether the `DayOfWeek` is saturday.

        Returns:
            The result.
        """
        return self == Self.SATURDAY

    @always_inline
    def is_sunday(self) -> Bool:
        """Whether the `DayOfWeek` is sunday.

        Returns:
            The result.
        """
        return self == Self.SUNDAY

    @always_inline
    @staticmethod
    def is_valid(value: UInt8) -> Bool:
        """Whether the raw day of week value is valid for this calendar.

        Args:
            value: The raw value.

        Returns:
            The result.
        """
        return Self.min_raw_value <= value <= Self.max_raw_value

    @always_inline
    def to_calendar[cal: Calendar](self, out res: DayOfWeek[cal]):
        """Translate a `DayOfWeek` to another calendar.

        Parameters:
            cal: The new calendar.

        Returns:
            The translated `DayOfWeek`.
        """
        if self.is_monday():
            return res.MONDAY
        elif self.is_tuesday():
            return res.TUESDAY
        elif self.is_wednesday():
            return res.WEDNESDAY
        elif self.is_thursday():
            return res.THURSDAY
        elif self.is_friday():
            return res.FRIDAY
        elif self.is_saturday():
            return res.SATURDAY
        else:
            assert self.is_sunday(), "invalid internal value"
            return res.SUNDAY

    @always_inline
    def __eq__(self, other: DayOfWeek) -> Bool:
        """Compare the `DayOfWeek` with another instance.

        Args:
            other: The other `DayOfWeek`.

        Returns:
            The result.
        """
        return self == other.to_calendar[Self.calendar]()

    @always_inline
    def __ne__(self, other: DayOfWeek) -> Bool:
        """Compare the `DayOfWeek` with another instance.

        Args:
            other: The other `DayOfWeek`.

        Returns:
            The result.
        """
        return self != other.to_calendar[Self.calendar]()


struct DateTime[
    timezone: TimeZone = TZ_UTC, calendar: Calendar = PythonCalendar
](Comparable, ImplicitlyCopyable, Writable):
    """Custom `Calendar` and `TimeZone` may be passed in.
    By default, it uses `PythonCalendar` which is a Gregorian
    calendar with its given epoch and max year:
    [0001-01-01, 9999-12-31]. Default `TimeZone` is UTC.

    Parameters:
        timezone: The time zone for the `DateTime`.
        calendar: The calendar for the `DateTime`.

    - Max Resolution:
        - year: Up to year 65_536.
        - month: Up to month 256.
        - day: Up to day 256.
        - hour: Up to hour 256.
        - minute: Up to minute 256.
        - second: Up to second 256.
        - m_second: Up to m_second 65_536.
        - u_second: Up to u_second 65_536.
        - n_second: Up to n_second 65_536.
        - hash: 64 bits.

    - Notes:
        The Default `DateTime` hash has only microsecond resolution.
    """

    var year: UInt16
    """The Year."""
    var month: UInt8
    """The Month."""
    var day: UInt8
    """The Day."""
    var hour: UInt8
    """The Hour."""
    var minute: UInt8
    """The Minute."""
    var second: UInt8
    """The Second."""
    var m_second: UInt16
    """The Milisecond."""
    var u_second: UInt16
    """The Microsecond."""
    var n_second: UInt16
    """The Nanosecond."""

    def __init__[
        T1: Intable & Movable = Int,
        T2: Intable & Movable = Int,
        T3: Intable & Movable = Int,
        T4: Intable & Movable = Int,
        T5: Intable & Movable = Int,
        T6: Intable & Movable = Int,
        T7: Intable & Movable = Int,
        T8: Intable & Movable = Int,
        T9: Intable & Movable = Int,
    ](
        out self,
        year: Optional[T1] = None,
        month: Optional[T2] = None,
        day: Optional[T3] = None,
        hour: Optional[T4] = None,
        minute: Optional[T5] = None,
        second: Optional[T6] = None,
        m_second: Optional[T7] = None,
        u_second: Optional[T8] = None,
        n_second: Optional[T9] = None,
    ):
        """Construct a `DateTime` from valid values.

        Parameters:
            T1: Any type that is `Intable & Movable`.
            T2: Any type that is `Intable & Movable`.
            T3: Any type that is `Intable & Movable`.
            T4: Any type that is `Intable & Movable`.
            T5: Any type that is `Intable & Movable`.
            T6: Any type that is `Intable & Movable`.
            T7: Any type that is `Intable & Movable`.
            T8: Any type that is `Intable & Movable`.
            T9: Any type that is `Intable & Movable`.

        Args:
            year: Year.
            month: Month.
            day: Day.
            hour: Hour.
            minute: Minute.
            second: Second.
            m_second: M_second.
            u_second: U_second.
            n_second: N_second.
        """

        self.year = UInt16(Int(year.value())) if year else {
            Self.calendar.min_year
        }
        self.month = UInt8(Int(month.value())) if month else {
            Self.calendar.min_month
        }
        self.day = UInt8(Int(day.value())) if day else {Self.calendar.min_day}
        self.hour = UInt8(Int(hour.value())) if hour else {
            Self.calendar.min_hour
        }
        self.minute = UInt8(Int(minute.value())) if minute else {
            Self.calendar.min_minute
        }
        self.second = UInt8(Int(second.value())) if second else {
            Self.calendar.min_second
        }
        self.m_second = UInt16(Int(m_second.value())) if m_second else {
            Self.calendar.min_millisecond
        }
        self.u_second = UInt16(Int(u_second.value())) if u_second else {
            Self.calendar.min_microsecond
        }
        self.n_second = UInt16(Int(n_second.value())) if n_second else {
            Self.calendar.min_nanosecond
        }

    def __init__(out self, dt: _NaiveDateTime):
        """Construct a `DateTime` for a datetime with no timezone.

        Args:
            dt: Datetime with no timezone.
        """
        self.year = dt.year
        self.month = dt.month
        self.day = dt.day
        self.hour = dt.hour
        self.minute = dt.minute
        self.second = dt.second
        self.m_second = dt.m_second
        self.u_second = dt.u_second
        self.n_second = dt.n_second

    def __init__(out self, no_tz_datetime: _TzNaiveDateTime[Self.calendar]):
        """Construct a `DateTime` for a datetime with no timezone.

        Args:
            no_tz_datetime: Datetime with no timezone.
        """
        self = Self(no_tz_datetime.dt)

    def __init__(out self, *, var from_utc: DateTime[TZ_UTC, Self.calendar]):
        """Translate `TimeZone` from UTC.

        Args:
            from_utc: The UTC `DateTime`.
        """

        comptime if Self.timezone == TZ_UTC:
            return rebind[Self](from_utc)
        var offset = Self.timezone.zone_info.offset_at_utc_time(
            from_utc._to_tz_naive_datetime()
        )
        from_utc = {offset.utc_to_local(from_utc._to_tz_naive_datetime())}
        return from_utc.replace[tz=Self.timezone]()

    def replace[
        tz: TimeZone = Self.timezone, cal: Calendar = Self.calendar
    ](
        var self,
        *,
        year: Optional[UInt16] = None,
        month: Optional[UInt8] = None,
        day: Optional[UInt8] = None,
        hour: Optional[UInt8] = None,
        minute: Optional[UInt8] = None,
        second: Optional[UInt8] = None,
        m_second: Optional[UInt16] = None,
        u_second: Optional[UInt16] = None,
        n_second: Optional[UInt16] = None,
    ) -> DateTime[tz, cal]:
        """Replace with given value/s.

        Parameters:
            tz: Time zone to change to (raw).
            cal: Calendar to change to (raw).

        Args:
            year: Year.
            month: Month.
            day: Day.
            hour: Hour.
            minute: Minute.
            second: Second.
            m_second: Milisecond.
            u_second: Microsecond.
            n_second: Nanosecond.

        Returns:
            Self.
        """
        return {
            year.or_else(self.year),
            month.or_else(self.month),
            day.or_else(self.day),
            hour.or_else(self.hour),
            minute.or_else(self.minute),
            second.or_else(self.second),
            m_second.or_else(self.m_second),
            u_second.or_else(self.u_second),
            n_second.or_else(self.n_second),
        }

    @always_inline
    def to_calendar[cal: Calendar](var self) -> DateTime[Self.timezone, cal]:
        """Translates the `DateTime`'s values to be on the same offset since
        its current calendar's epoch to the new calendar's epoch.

        Parameters:
            cal: The new calendar.

        Returns:
            The new `DateTime`.
        """
        return {self._to_tz_naive_datetime().to_calendar[cal]()}

    def to_timezone[tz: TimeZone](var self) -> DateTime[tz, Self.calendar]:
        """Returns a new instance of `Self` transformed to UTC.

        Parameters:
            tz: TimeZone.

        Returns:
            The new `DateTime`.
        """

        comptime if Self.timezone == tz:
            return rebind[DateTime[tz, Self.calendar]](self)
        offset = self.timezone.zone_info.offset_at_local_time(
            self._to_tz_naive_datetime()
        )
        var utc_time = offset.local_to_utc(self._to_tz_naive_datetime())
        comptime if tz == TZ_UTC:
            return {utc_time}
        new_offset = tz.zone_info.offset_at_utc_time(utc_time)
        return {new_offset.utc_to_local(utc_time)}

    @always_inline
    def to_utc(var self) -> DateTime[TZ_UTC, Self.calendar]:
        """Returns a new instance of `Self` transformed to UTC.

        Returns:
            Self.
        """
        return self.to_timezone[TZ_UTC]()

    @always_inline
    def to_delta_since_epoch[
        unit: SITimeUnit = SITimeUnit.SECONDS,
        dtype: DType where dtype.is_unsigned() = DType.uint64,
    ](self) -> TimeDelta[unit, dtype]:
        """The amount of time since the begining of the calendar's epoch.

        Parameters:
            unit: The time unit.
            dtype: The dtype in which to store the time delta in.

        Returns:
            The `TImeDelta`.
        """
        return {
            self.calendar.to_delta_since_epoch[unit, dtype](
                self._to_naive_datetime()
            )
        }

    @always_inline
    def to_delta_since_unix_epoch[
        unit: SITimeUnit = SITimeUnit.SECONDS,
        dtype: DType where dtype.is_unsigned() = DType.uint64,
    ](self) -> Tuple[Bool, TimeDelta[unit, dtype]]:
        """The amount of time since the begining of the unix epoch (1970-01-01).

        Parameters:
            unit: The time unit.
            dtype: The dtype in which to store the time delta in.

        Returns:
            - Whether the offset is positive.
            - The `TimeDelta`.
        """
        var is_positive, naive_delta = self.calendar.to_delta_since_unix_epoch[
            unit, dtype
        ](self._to_naive_datetime())
        return is_positive, TimeDelta[unit, dtype](naive_delta)

    def _to_naive_datetime(self) -> _NaiveDateTime:
        return {
            self.year,
            self.month,
            self.day,
            self.hour,
            self.minute,
            self.second,
            self.m_second,
            self.u_second,
            self.n_second,
        }

    def _to_tz_naive_datetime(self) -> _TzNaiveDateTime[Self.calendar]:
        return {self._to_naive_datetime()}

    @always_inline
    def add(
        var self,
        *,
        years: UInt64 = 0,
        months: UInt64 = 0,
        days: UInt64 = 0,
        hours: UInt64 = 0,
        minutes: UInt64 = 0,
        seconds: UInt64 = 0,
        m_seconds: UInt64 = 0,
        u_seconds: UInt64 = 0,
        n_seconds: UInt64 = 0,
    ) -> Self:
        """Recursively evaluated function to build a valid `DateTime`
        according to its calendar. Values are added in BigEndian order i.e.
        `years, months, ...` .

        Args:
            years: Years.
            months: Months.
            days: Days.
            hours: Hours.
            minutes: Minutes.
            seconds: Seconds.
            m_seconds: Miliseconds.
            u_seconds: Microseconds.
            n_seconds: Nanoseconds.

        Returns:
            Self.

        Notes:
            On overflow, the `DateTime` starts from the beginning of the
            calendar's epoch and keeps evaluating until valid.
        """
        return {
            self._to_tz_naive_datetime().add(
                years=years,
                months=months,
                days=days,
                hours=hours,
                minutes=minutes,
                seconds=seconds,
                m_seconds=m_seconds,
                u_seconds=u_seconds,
                n_seconds=n_seconds,
            )
        }

    def subtract(
        var self,
        *,
        years: UInt64 = 0,
        months: UInt64 = 0,
        days: UInt64 = 0,
        hours: UInt64 = 0,
        minutes: UInt64 = 0,
        seconds: UInt64 = 0,
        m_seconds: UInt64 = 0,
        u_seconds: UInt64 = 0,
        n_seconds: UInt64 = 0,
    ) -> Self:
        """Recursively evaluated function to build a valid `DateTime`
        according to its calendar. Values are subtracted in LittleEndian order
        i.e. `n_seconds, u_seconds, ...` .

        Args:
            years: Years.
            months: Months.
            days: Days.
            hours: Hours.
            minutes: Minutes.
            seconds: Seconds.
            m_seconds: Miliseconds.
            u_seconds: Microseconds.
            n_seconds: Nanoseconds.

        Returns:
            Self.

        Notes:
            On overflow, the `DateTime` goes to the end of the calendar's epoch
            and keeps evaluating until valid.
        """
        return {
            self._to_tz_naive_datetime().subtract(
                years=years,
                months=months,
                days=days,
                hours=hours,
                minutes=minutes,
                seconds=seconds,
                m_seconds=m_seconds,
                u_seconds=u_seconds,
                n_seconds=n_seconds,
            )
        }

    @always_inline
    def add(var self, other: TimeDelta) -> Self:
        """Adds another `DateTime`.

        Args:
            other: Other.

        Returns:
            A `DateTime` with the `TimeZone` and `Calendar` of `self`.
        """
        comptime if other.unit == SITimeUnit.NANOSECONDS:
            return self.add(n_seconds=UInt64(other.value))
        elif other.unit == SITimeUnit.MICROSECONDS:
            return self.add(u_seconds=UInt64(other.value))
        elif other.unit == SITimeUnit.MILLISECONDS:
            return self.add(m_seconds=UInt64(other.value))
        elif other.unit == SITimeUnit.SECONDS:
            return self.add(seconds=UInt64(other.value))
        elif other.unit == SITimeUnit.MINUTES:
            return self.add(minutes=UInt64(other.value))
        elif other.unit == SITimeUnit.HOURS:
            return self.add(hours=UInt64(other.value))
        elif other.unit == SITimeUnit.DAYS:
            return self.add(days=UInt64(other.value))
        else:
            comptime assert False, "time unit not implemented"

    @always_inline
    def subtract(var self, other: TimeDelta) -> Self:
        """Subtracts another `DateTime`.

        Args:
            other: Other.

        Returns:
            A `DateTime` with the `TimeZone` and `Calendar` of `self`.
        """
        comptime if other.unit == SITimeUnit.NANOSECONDS:
            return self.subtract(n_seconds=UInt64(other.value))
        elif other.unit == SITimeUnit.MICROSECONDS:
            return self.subtract(u_seconds=UInt64(other.value))
        elif other.unit == SITimeUnit.MILLISECONDS:
            return self.subtract(m_seconds=UInt64(other.value))
        elif other.unit == SITimeUnit.SECONDS:
            return self.subtract(seconds=UInt64(other.value))
        elif other.unit == SITimeUnit.MINUTES:
            return self.subtract(minutes=UInt64(other.value))
        elif other.unit == SITimeUnit.HOURS:
            return self.subtract(hours=UInt64(other.value))
        elif other.unit == SITimeUnit.DAYS:
            return self.subtract(days=UInt64(other.value))
        else:
            comptime assert False, "time unit not implemented"

    @always_inline
    def subtract[
        unit: SITimeUnit = SITimeUnit.SECONDS,
        dtype: DType where dtype.is_unsigned() = DType.uint64,
    ](var self, other: Self) -> TimeDelta[unit, dtype]:
        """Subtracts another `DateTime`.

        Parameters:
            unit: The time unit to calculate the delta in.
            dtype: The dtype to store the delta in.

        Args:
            other: Other.

        Returns:
            A `DateTime` with the `TimeZone` and `Calendar` of `self`.
        """
        assert self >= other, "self must be >= other"
        return (
            self.to_delta_since_epoch[unit, dtype]()
            - other.to_delta_since_epoch[unit, dtype]()
        )

    @always_inline
    def __add__(var self, other: TimeDelta) -> Self:
        """Add.

        Args:
            other: Other.

        Returns:
            Result.
        """
        return self.add(other)

    @always_inline
    def __sub__(var self, other: TimeDelta) -> Self:
        """Subtract.

        Args:
            other: Other.

        Returns:
            Result.
        """
        return self.subtract(other)

    @always_inline
    def __sub__(
        var self, other: Self
    ) -> TimeDelta[SITimeUnit.SECONDS, DType.uint64]:
        """Subtract.

        Args:
            other: Other.

        Returns:
            Result.
        """
        return self.subtract(other)

    @always_inline
    def __iadd__(mut self, other: TimeDelta):
        """Add Immediate.

        Args:
            other: Other.
        """
        self = self.add(other)

    @always_inline
    def __isub__(mut self, other: TimeDelta):
        """Subtract Immediate.

        Args:
            other: Other.
        """
        self = self.subtract(other)

    @always_inline
    def day_of_week(self) -> DayOfWeek[Self.calendar]:
        """Calculates the day of the week for a `DateTime`.

        Returns:
            Day of the week for the `DateTime`s calendar.
        """
        return {self}

    @always_inline
    def day_of_year(self) -> UInt16:
        """Calculates the day of the year for a `DateTime`.

        Returns:
            Day of the year: [1, 366] (for Gregorian calendar).
        """
        return self.calendar.day_of_year(self._to_naive_datetime())

    @always_inline
    def day_of_month(self, day_of_year: UInt16) -> Tuple[UInt8, UInt8]:
        """Calculates the month, day of the month for a given day of the year.

        Args:
            day_of_year: The day of the year.

        Returns:
            - month: Month of the year: [1, 12] (for Gregorian calendar).
            - day: Day of the month: [1, 31] (for Gregorian calendar).
        """
        return self.calendar.day_of_month(self.year, day_of_year)

    @always_inline
    def week_of_year(self) -> UInt8:
        """Calculates the week of the year for a given date.

        Returns:
            Week of the year: [0, 52] (Gregorian), [1, 53] (ISOCalendar).

        Notes:
            Gregorian takes the first day of the year as starting week 0,
            ISOCalendar follows [ISO 8601](\
            https://en.wikipedia.org/wiki/ISO_week_date) which takes the first
            thursday of the year as starting week 1.
        """
        return self.calendar.week_of_year(self._to_naive_datetime())

    def leapsecs_since_epoch(self) -> UInt32:
        """Cumulative leap seconds since the calendar's epoch start.

        Returns:
            The amount.
        """
        dt = self.to_utc()
        return dt.calendar.leapsecs_since_epoch(dt._to_naive_datetime())

    @always_inline
    def hash[
        cal_hash: CalendarHashes = CalendarHashes.UINT64
    ](self) -> Scalar[cal_hash.dtype]:
        """Hash.

        Parameters:
            cal_hash: The calendar hash to hash this with.

        Returns:
            Result.
        """
        return self.calendar.hash[cal_hash](self._to_naive_datetime())

    @always_inline
    @staticmethod
    def from_hash(value: Scalar) -> Self:
        """Construct a `DateTime` from a hash made by it.
        Nanoseconds are set to the calendar's minimum.

        Args:
            value: The value to parse.

        Returns:
            Self.
        """
        return Self(Self.calendar.from_hash(value))

    @always_inline
    def _compare[op: StaticString](self, other: DateTime) -> Bool:
        var s: UInt64
        var o: UInt64
        comptime if self.timezone != other.timezone:
            s, o = self.to_utc().hash(), other.to_utc().hash()
        else:
            s, o = self.hash(), other.hash()

        comptime if op == "==":
            return (s, self.n_second) == (o, other.n_second)
        elif op == "!=":
            return (s, self.n_second) != (o, other.n_second)
        elif op == ">":
            return (s, self.n_second) > (o, other.n_second)
        elif op == ">=":
            return (s, self.n_second) >= (o, other.n_second)
        elif op == "<":
            return (s, self.n_second) < (o, other.n_second)
        elif op == "<=":
            return (s, self.n_second) <= (o, other.n_second)
        else:
            comptime assert False, "nonexistent op."

    @always_inline
    def __eq__(self, other: Self) -> Bool:
        """Eq.

        Args:
            other: Other.

        Returns:
            Bool.
        """
        return self._compare["=="](other)

    @always_inline
    def __lt__(self, other: Self) -> Bool:
        """Lt.

        Args:
            other: Other.

        Returns:
            Bool.
        """
        return self._compare["<"](other)

    @always_inline
    def __eq__(self, other: DateTime) -> Bool:
        """Eq.

        Args:
            other: Other.

        Returns:
            Bool.
        """
        return self._compare["=="](other)

    @always_inline
    def __ne__(self, other: DateTime) -> Bool:
        """Ne.

        Args:
            other: Other.

        Returns:
            Bool.
        """
        return self._compare["!="](other)

    @always_inline
    def __gt__(self, other: DateTime) -> Bool:
        """Gt.

        Args:
            other: Other.

        Returns:
            Bool.
        """
        return self._compare[">"](other)

    @always_inline
    def __ge__(self, other: DateTime) -> Bool:
        """Ge.

        Args:
            other: Other.

        Returns:
            Bool.
        """
        return self._compare[">="](other)

    @always_inline
    def __lt__(self, other: DateTime) -> Bool:
        """Lt.

        Args:
            other: Other.

        Returns:
            Bool.
        """
        return self._compare["<"](other)

    @always_inline
    def __le__(self, other: DateTime) -> Bool:
        """Le.

        Args:
            other: Other.

        Returns:
            Bool.
        """
        return self._compare["<="](other)

    @staticmethod
    def from_unix_epoch[
        add_leapsecs: Bool = False
    ](time_delta: TimeDelta) -> Self:
        """Construct a `DateTime` from the time delta since the Unix Epoch
        1970-01-01. Adding the cumulative leap seconds since 1972
        to the given date.

        Parameters:
            add_leapsecs: Whether to add the leap seconds and leap days
                since the start of the calendar's epoch.

        Args:
            time_delta: Nanoseconds.

        Returns:
            Self.
        """

        dt = DateTime[Self.timezone, UTCCalendar]().add(time_delta)
        comptime if add_leapsecs:
            dt = dt.add(seconds=UInt64(dt.leapsecs_since_epoch()))
        return dt.to_calendar[Self.calendar]()

    # @always_inline
    # @staticmethod
    # def now() -> Self:
    #     """Construct a datetime from `time.now()`.

    #     Returns:
    #         Self.
    #     """
    #     return Self.from_unix_epoch(
    #         TimeDelta[SITimeUnit.NANOSECONDS](time.monotonic())
    #     )

    @always_inline
    def timestamp(self) -> Float64:
        """Return the POSIX timestamp (seconds since unix epoch).

        Returns:
            The POSIX timestamp.

        Notes:
            If the datetime is before the unix epoch, then a negative offset is
            returned.
        """
        var is_positive, naive_delta = self.to_delta_since_unix_epoch[
            SITimeUnit.SECONDS
        ]()
        return Float64(naive_delta.value) * Float64(1 if is_positive else -1)

    @always_inline
    @staticmethod
    def parse[
        zone_info_t: UTCZoneInfo,
        //,
        fmt_str: String,
        locale_t: DTLocale = GenericEnglishDTLocale,
        zone_info_dict: Dict[String, zone_info_t] = gregorian_zoneinfo,
    ](
        read_from: StringSlice[mut=False, _],
        var locale: Optional[locale_t] = None,
    ) raises -> Self:
        """Parse a `DateTime` from a  `String`.

        Parameters:
            zone_info_t: The type that stores the zone information.
            fmt_str: The format string.
            locale_t: The locale type to parse the datetime with for
                locale-aware format codes
                (`{"%a", "%A", "%b", "%B", "%p", "%c", "%x", "%X"}`).
            zone_info_dict: The dictionary to search any `"%Z"` timezone strings
                from.

        Args:
            read_from: The string to read from.
            locale: An optional locale for locale-aware format codes.

        Returns:
            The result.

        Raises:
            If parsing fails for any of several reasons.

        Notes:
            - Format codes `{"%w", "%W", "%j"}`: When parsing any datetime that
                has relative days from a given offset, the whole string is
                parsed then the relative days added up.
            - Format code `"%z"`: When only `%z` is specified, the
                parsed datetime is interpreted as being a datetime with a UTC
                offset, from which a datetime of `Self.timezone` is then built
                by using `Self.timezone.zone_info.offset_at_utc_time(...)`.
            - Format code `"%Z"`: Any offset specified with `%z` when `%Z` is
                present is interpreted as an offset relative to that timezone,
                **not UTC**.
            - See [`FormatCodes`](/mojo_datetime/locale/FormatCodes) for all the
                supported format codes.
        """
        comptime p = _parse[fmt_str, Self.calendar, zone_info_dict, locale_t]
        return Self(from_utc={p(read_from)})

    @always_inline
    def write_to(self, mut writer: Some[Writer]):
        """Write the `DateTime` to a writer.

        Args:
            writer: The writer to write to.
        """
        self.write_to[IsoFormat.YYYY_MM_DD_T_HH_MM_SS_TZD](writer)

    @always_inline
    def write_to[
        fmt_str: String, locale_t: DTLocale = GenericEnglishDTLocale
    ](self, mut writer: Some[Writer], var locale: Optional[locale_t] = None):
        """Write the `DateTime` to a writer.

        Parameters:
            fmt_str: The format string.
            locale_t: The locale type to write the datetime with for
                locale-aware format codes
                (`{"%a", "%A", "%b", "%B", "%p", "%c", "%x", "%X"}`).

        Args:
            writer: The writer to write to.
            locale: An optional locale for locale-aware format codes.

        Notes:
            - See [`FormatCodes`](/mojo_datetime/locale/FormatCodes) for all the
                supported format codes.
        """
        var naive_self = self._to_tz_naive_datetime()
        var offset = Self.timezone.zone_info.offset_at_local_time(naive_self)
        _write_to[fmt_str, Self.timezone.tz_str](
            writer, naive_self, offset, locale^
        )
