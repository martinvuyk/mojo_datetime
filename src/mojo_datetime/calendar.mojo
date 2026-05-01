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
"""`Calendar` module."""

from std.os import abort
from std.utils import Variant
from std.sys.intrinsics import likely, unlikely


comptime PythonCalendar = Gregorian[]
"""The default Python proleptic Gregorian calendar, goes from [0001-01-01,
9999-12-31]. It is leap day and leap second aware."""
comptime UTCCalendar = Gregorian[min_year_=1970]
"""The UTC calendar, goes from [1970-01-01, 9999-12-31]. It is leap day and leap
second aware."""
comptime UTCFastCal = Gregorian[include_leapsecs_=False, min_year_=1970]
"""A fast UTC calendar that ignores leap seconds. Leap day aware, goes from
[1970-01-01, 9999-12-31]."""

# ===----------------------------------------------------------------------=== #
# base types
# ===----------------------------------------------------------------------=== #


@fieldwise_init
struct SITimeUnit(Comparable, TrivialRegisterPassable):
    """A struct representing some International System of Units (SI) time
    units."""

    comptime NANOSECONDS = Self(0)
    """A nanosecond is defined as 10**-9 * seconds."""
    comptime MICROSECONDS = Self(1)
    """A microsecond is defined as 10**-6 * seconds."""
    comptime MILLISECONDS = Self(2)
    """A millisecond is defined as 10**-3 * seconds."""
    comptime SECONDS = Self(3)
    """A second is an SI base unit."""
    comptime MINUTES = Self(4)
    """A minute is defined as 60 * seconds."""
    comptime HOURS = Self(5)
    """An hour is defined as 60 * minutes."""
    comptime DAYS = Self(6)
    """A day is defined as 24 * hours."""
    var _value: UInt8

    @always_inline
    def __lt__(self, rhs: Self) -> Bool:
        """Define whether `self` is less than `rhs`.

        Args:
            rhs: The value to compare with.

        Returns:
            True if `self` is less than `rhs`.
        """
        return self._value < rhs._value


struct _NaiveDateTime(Comparable, ImplicitlyCopyable, Writable):
    var year: UInt16
    var month: UInt8
    var day: UInt8
    var hour: UInt8
    var minute: UInt8
    var second: UInt8
    var m_second: UInt16
    var u_second: UInt16
    var n_second: UInt16

    def __init__(
        out self,
        year: UInt16 = 0,
        month: UInt8 = 0,
        day: UInt8 = 0,
        hour: UInt8 = 0,
        minute: UInt8 = 0,
        second: UInt8 = 0,
        m_second: UInt16 = 0,
        u_second: UInt16 = 0,
        n_second: UInt16 = 0,
    ):
        self.year = year
        self.month = month
        self.day = day
        self.hour = hour
        self.minute = minute
        self.second = second
        self.m_second = m_second
        self.u_second = u_second
        self.n_second = n_second

    @always_inline
    def __lt__(self, other: Self) -> Bool:
        """Lt.

        Args:
            other: Other.

        Returns:
            Bool.
        """
        if self.year != other.year:
            return self.year < other.year
        if self.month != other.month:
            return self.month < other.month
        if self.day != other.day:
            return self.day < other.day
        if self.hour != other.hour:
            return self.hour < other.hour
        if self.minute != other.minute:
            return self.minute < other.minute
        if self.second != other.second:
            return self.second < other.second
        if self.m_second != other.m_second:
            return self.m_second < other.m_second
        if self.u_second != other.u_second:
            return self.u_second < other.u_second
        return self.n_second < other.n_second


# ===----------------------------------------------------------------------=== #
# Calendar hashes
# ===----------------------------------------------------------------------=== #


@fieldwise_init
struct CalendarHashes[dtype: DType]:
    """Hashing definitions. Up to microsecond resolution for
    the 64bit hash. Each calendar implementation can still
    override with its own definitions.

    Parameters:
        dtype: The dtype that this calendar hash uses.
    """

    comptime UINT8 = CalendarHashes[DType.uint8]()
    """Hash width UINT8."""
    comptime UINT16 = CalendarHashes[DType.uint16]()
    """Hash width UINT16."""
    comptime UINT32 = CalendarHashes[DType.uint32]()
    """Hash width UINT32."""
    comptime UINT64 = CalendarHashes[DType.uint64]()
    """Hash width UINT64."""

    comptime _17b = 0b1_1111_1111_1111_1111
    comptime _12b = 0b0_0000_1111_1111_1111
    comptime _10b = 0b0_0000_0011_1111_1111
    comptime _9b = 0b0_0000_0001_1111_1111
    comptime _6b = 0b0_0000_0000_0011_1111
    comptime _5b = 0b0_0000_0000_0001_1111
    comptime _4b = 0b0_0000_0000_0000_1111
    comptime _3b = 0b0_0000_0000_0000_0111
    comptime _2b = 0b0_0000_0000_0000_0011

    comptime shift_64_y = (5 + 5 + 5 + 6 + 6 + 10 + 10)
    """Up to 131_072 years in total (-1 numeric)."""
    comptime shift_64_mon = (5 + 5 + 6 + 6 + 10 + 10)
    """Up to 32 months in total (-1 numeric)."""
    comptime shift_64_d = (5 + 6 + 6 + 10 + 10)
    """Up to 32 days in total (-1 numeric)."""
    comptime shift_64_h = (6 + 6 + 10 + 10)
    """Up to 32 hours in total (-1 numeric)."""
    comptime shift_64_m = (6 + 10 + 10)
    """Up to 64 minutes in total (-1 numeric)."""
    comptime shift_64_s = (10 + 10)
    """Up to 64 seconds in total (-1 numeric)."""
    comptime shift_64_ms = 10
    """Up to 1024 m_seconds in total (-1 numeric)."""
    comptime shift_64_us = 0
    """Up to 1024 u_seconds in total (-1 numeric)."""
    comptime mask_64_y: UInt64 = CalendarHashes._17b
    """A mask_64_y."""
    comptime mask_64_mon: UInt64 = CalendarHashes._5b
    """A mask_64_mon."""
    comptime mask_64_d: UInt64 = CalendarHashes._5b
    """A mask_64_d."""
    comptime mask_64_h: UInt64 = CalendarHashes._5b
    """A mask_64_h."""
    comptime mask_64_m: UInt64 = CalendarHashes._6b
    """A mask_64_m."""
    comptime mask_64_s: UInt64 = CalendarHashes._6b
    """A mask_64_s."""
    comptime mask_64_ms: UInt64 = CalendarHashes._10b
    """A mask_64_ms."""
    comptime mask_64_us: UInt64 = CalendarHashes._10b
    """A mask_64_us."""

    comptime shift_32_y = (4 + 5 + 5 + 6)
    """Up to 4096 years in total (-1 numeric)."""
    comptime shift_32_mon = (5 + 5 + 6)
    """Up to 16 months in total (-1 numeric)."""
    comptime shift_32_d = (5 + 6)
    """Up to 32 days in total (-1 numeric)."""
    comptime shift_32_h = 6
    """Up to 32 hours in total (-1 numeric)."""
    comptime shift_32_m = 0
    """Up to 64 minutes in total (-1 numeric)."""
    comptime mask_32_y: UInt32 = CalendarHashes._12b
    """A mask_32_y."""
    comptime mask_32_mon: UInt32 = CalendarHashes._4b
    """A mask_32_mon."""
    comptime mask_32_d: UInt32 = CalendarHashes._5b
    """A mask_32_d."""
    comptime mask_32_h: UInt32 = CalendarHashes._5b
    """A mask_32_h."""
    comptime mask_32_m: UInt32 = CalendarHashes._6b
    """A mask_32_m."""

    comptime shift_16_y = (9 + 5)
    """Up to 4 years in total (-1 numeric)."""
    comptime shift_16_d = 5
    """Up to 512 days in total (-1 numeric)."""
    comptime shift_16_h = 0
    """Up to 32 hours in total (-1 numeric)."""
    comptime mask_16_y: UInt16 = CalendarHashes._2b
    """A mask_16_y."""
    comptime mask_16_d: UInt16 = CalendarHashes._9b
    """A mask_16_d."""
    comptime mask_16_h: UInt16 = CalendarHashes._5b
    """A mask_16_h."""

    comptime shift_8_d = 5
    """Up to 8 days in total (-1 numeric)."""
    comptime shift_8_h = 0
    """Up to 32 hours in total (-1 numeric)."""
    comptime mask_8_d: UInt8 = CalendarHashes._3b
    """A mask_8_d."""
    comptime mask_8_h: UInt8 = CalendarHashes._5b
    """A mask_8_h."""


# ===----------------------------------------------------------------------=== #
# Leap seconds
# ===----------------------------------------------------------------------=== #


@fieldwise_init
struct Leapsec(TrivialRegisterPassable):
    """Leap second added to UTC to keep in sync with [IAT](
    https://en.wikipedia.org/wiki/International_Atomic_Time).
    """

    comptime _cal_h = CalendarHashes.UINT32

    var year: UInt16
    """Year in which the leap second was added."""
    var month: UInt8
    """Month in which the leap second was added."""
    var day: UInt8
    """Day in which the leap second was added."""

    def __init__(out self, dt: _NaiveDateTime):
        """Construct a Leapsec from a naive datetime.

        Args:
            dt: A naive datetime.
        """
        self.year = dt.year
        self.month = dt.month
        self.day = dt.day

    @staticmethod
    def from_hash(value: UInt32) -> Self:
        """Parse a hash.

        Args:
            value: The hash value.

        Returns:
            The result.
        """
        var year = UInt16(
            UInt32(value >> Self._cal_h.shift_32_y) & Self._cal_h.mask_32_y
        )
        var month = UInt8(
            UInt32(value >> Self._cal_h.shift_32_mon) & Self._cal_h.mask_32_mon
        )
        var day = UInt8(
            UInt32(value >> Self._cal_h.shift_32_d) & Self._cal_h.mask_32_d
        )
        return {year, month, day}

    def hash(self) -> UInt32:
        """Produce a hash from self.

        Returns:
            The result.
        """

        return (
            (UInt32(self.year) << Self._cal_h.shift_32_y)
            | (UInt32(self.month) << Self._cal_h.shift_32_mon)
            | (UInt32(self.day) << Self._cal_h.shift_32_d)
        )


# TODO: need to programatically update this list every january
comptime gregorian_leapsecs: InlineArray[UInt32, 27] = [
    Leapsec(1972, 6, 30).hash(),
    Leapsec(1972, 12, 31).hash(),
    Leapsec(1973, 12, 31).hash(),
    Leapsec(1974, 12, 31).hash(),
    Leapsec(1975, 12, 31).hash(),
    Leapsec(1976, 12, 31).hash(),
    Leapsec(1977, 12, 31).hash(),
    Leapsec(1978, 12, 31).hash(),
    Leapsec(1979, 12, 31).hash(),
    Leapsec(1981, 6, 30).hash(),
    Leapsec(1982, 6, 30).hash(),
    Leapsec(1983, 6, 30).hash(),
    Leapsec(1985, 6, 30).hash(),
    Leapsec(1987, 12, 31).hash(),
    Leapsec(1989, 12, 31).hash(),
    Leapsec(1990, 12, 31).hash(),
    Leapsec(1992, 6, 30).hash(),
    Leapsec(1993, 6, 30).hash(),
    Leapsec(1994, 6, 30).hash(),
    Leapsec(1995, 12, 31).hash(),
    Leapsec(1997, 6, 30).hash(),
    Leapsec(1998, 12, 31).hash(),
    Leapsec(2005, 12, 31).hash(),
    Leapsec(2008, 12, 31).hash(),
    Leapsec(2012, 6, 30).hash(),
    Leapsec(2015, 6, 30).hash(),
    Leapsec(2016, 12, 31).hash(),
]
"""List of hashed leap seconds: Leapsec(year, month, day).hash().
They MUST be on either June 30th at 23:59 or Dec. 31st at 23:59 according to
the International Time Bureau.

[IANA's list](https://data.iana.org/time-zones/tzdb/leapseconds).
"""

# ===----------------------------------------------------------------------=== #
# Calendar
# ===----------------------------------------------------------------------=== #
comptime _m = UInt16.MAX


trait Calendar(Defaultable, ImplicitlyCopyable, Movable):
    """A calendar implementation.

    This trait is intended to be used for custom calendar implementations. It
    is soft-private, meaning it is meant to be used as an internal tool but
    if somebody needs to implement a given calendar that isn't available here,
    then they can use this trait. The trait itself can be modified if a given
    external calendar needs it, as long as it doesn't impede the more common
    existing ones.

    Calendars which were considered but are too out of scope for this library:
    - Lunar
        - Tabular Islamic Calendar with a 30 year cycle
    - Lunisolar
        - Hebrew Calendar
        - Modern Chinese Calendar
        - Hindu Calendar (parametrized for Amanta and Purnimanta)
    """

    comptime max_year: UInt16 = 9999
    """Maximum value of years."""
    comptime max_typical_days_in_year: UInt16 = 365
    """Maximum typical value of days in a year (no leaps)."""
    comptime max_possible_days_in_year: UInt16 = 366
    """Maximum possible value of days in a year (with leaps)."""
    comptime max_possible_days_in_month: UInt8 = 31
    """Maximum possible value of days in a month (with leaps)."""
    comptime max_possible_weeks_in_year: UInt8 = 52
    """Maximum possible value of weeks in a year (with leaps)."""
    comptime max_month: UInt8 = 12
    """Maximum value of months in a year."""
    comptime max_hour: UInt8 = 23
    """Maximum value of hours in a day."""
    comptime max_minute: UInt8 = 59
    """Maximum value of minutes in an hour."""
    comptime max_typical_second: UInt8 = 59
    """Maximum typical value of seconds in a minute (no leaps)."""
    comptime max_possible_second: UInt8 = 60
    """Maximum possible value of seconds in a minute (with leaps)."""
    comptime max_millisecond: UInt16 = 999
    """Maximum value of milliseconds in a second."""
    comptime max_microsecond: UInt16 = 999
    """Maximum value of microseconds in a second."""
    comptime max_nanosecond: UInt16 = 999
    """Maximum value of nanoseconds in a second."""
    comptime min_year: UInt16 = 1
    """Default minimum year in the calendar."""
    comptime min_month: UInt8 = 1
    """Default minimum month."""
    comptime min_weeks_in_year: UInt8 = 0
    """Minimum value of weeks in a year."""
    comptime min_day: UInt8 = 1
    """Default minimum day."""
    comptime min_hour: UInt8 = 0
    """Default minimum hour."""
    comptime min_minute: UInt8 = 0
    """Default minimum minute."""
    comptime min_second: UInt8 = 0
    """Default minimum second."""
    comptime min_millisecond: UInt16 = 0
    """Default minimum millisecond."""
    comptime min_microsecond: UInt16 = 0
    """Default minimum microsecond."""
    comptime min_nanosecond: UInt16 = 0
    """Default minimum nanosecond."""

    comptime MONDAY: UInt8 = 0
    """Raw Monday value for this calendar."""
    comptime TUESDAY: UInt8 = 1
    """Raw Tuesday value for this calendar."""
    comptime WEDNESDAY: UInt8 = 2
    """Raw Wednesday value for this calendar."""
    comptime THURSDAY: UInt8 = 3
    """Raw Thursday value for this calendar."""
    comptime FRIDAY: UInt8 = 4
    """Raw Friday value for this calendar."""
    comptime SATURDAY: UInt8 = 5
    """Raw Saturday value for this calendar."""
    comptime SUNDAY: UInt8 = 6
    """Raw Sunday value for this calendar."""

    comptime _leapsec_size: Int
    comptime _hashed_leapsec_array: InlineArray[UInt32, Self._leapsec_size]
    comptime _include_leapsecs: Bool
    comptime _unix_calendar: Calendar

    # fmt: off
    comptime _monthdays: SIMD[DType.uint8, 16] = [
        0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31, 0, 0, 0
    ]
    comptime _days_before_month: SIMD[DType.uint16, 16] = [
        0, 0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334, _m, _m, _m
    ]
    # fmt: on

    @always_inline
    @staticmethod
    def month_range(dt: _NaiveDateTime) -> Tuple[UInt8, UInt8]:
        """Returns day of the week for the first day of the month and number of
        days in the month, for the specified year and month.

        Args:
            dt: The naive datetime.

        Returns:
            - day_of_week: Day of the week.
            - day_of_month: Day of the month.
        """
        return Self.day_of_week({dt.year, dt.month, 1}), Self.max_days_in_month(
            dt
        )

    @staticmethod
    def max_second(dt: _NaiveDateTime) -> UInt8:
        """The maximum amount of seconds that a minute lasts (usually 59).
        Some years its 60 when a leap second is added. The spec also lists
        the posibility of 58 seconds but it stil hasn't ben done.

        Args:
            dt: The naive datetime.

        Returns:
            The amount.
        """

        comptime if Self._include_leapsecs:
            if Self.is_leapsec(
                {dt.year, dt.month, dt.day, dt.hour, dt.minute, 59}
            ):
                return 60
        return 59

    @staticmethod
    def max_days_in_month(dt: _NaiveDateTime) -> UInt8:
        """The maximum amount of days in a given month.

        Args:
            dt: The naive datetime.

        Returns:
            The amount of days.
        """
        var days = Self._monthdays[Int(dt.month)]
        return days + UInt8(
            unlikely(dt.month == 2 and Self.is_leapyear(dt.year))
        )

    @staticmethod
    @always_inline
    def day_of_week(dt: _NaiveDateTime) -> UInt8:
        """Calculates the day of the week for a given date.

        Args:
            dt: The naive datetime.

        Returns:
            Day of the week [monday, sunday]: [0, 6] (Gregorian) [1, 7]
            (ISOCalendar).
        """
        # NOTE: since we calculate the day of week based on a fixed day that
        # the gregorian calendar started, we can just use that here. Using
        # arbitrary epochs would make this code not work (hence we don't use
        # self.days_since_epoch())
        var gregorian_days_since_epoch = Self._days_since_epoch[1, 1, 1](dt) + 1
        return (gregorian_days_since_epoch % 7).cast[DType.uint8]()

    @always_inline
    @staticmethod
    def day_of_year(dt: _NaiveDateTime) -> UInt16:
        """Calculates the day of the year for a given date.

        Args:
            dt: The naive datetime.

        Returns:
            Day of the year: [1, 366] (for Gregorian calendar).
        """
        var total = Self._days_before_month[Int(dt.month)]
        var leap_day = UInt16(dt.month > 2 and Self.is_leapyear(dt.year))
        return total + UInt16(dt.day) + leap_day

    @staticmethod
    def day_of_month(year: UInt16, day_of_year: UInt16) -> Tuple[UInt8, UInt8]:
        """Calculates the month, day of the month for a given day of the year.

        Args:
            year: Year.
            day_of_year: The day of the year.

        Returns:
            - month: Month of the year: [1, 12] (for Gregorian calendar).
            - day: Day of the month: [1, 31] (for Gregorian calendar).
        """
        var c = Self._days_before_month.lt(day_of_year).cast[DType.uint8]()
        var idx = c.reduce_add() - 1
        var rest = day_of_year - Self._days_before_month[Int(idx)]
        rest -= UInt16(idx > 2 and Self.is_leapyear(year))
        return idx, rest.cast[DType.uint8]()

    @staticmethod
    @always_inline
    def week_of_year(dt: _NaiveDateTime) -> UInt8:
        """Calculates the week of the year for a given date.

        Args:
            dt: The naive datetime.

        Returns:
            Week of the year: [0, 52] (Gregorian), [1, 53] (ISOCalendar).
        
        Notes:
            Gregorian takes the first day of the year as starting week 0,
            ISOCalendar follows [ISO 8601](\
            https://en.wikipedia.org/wiki/ISO_week_date) which takes the first
            thursday of the year as starting week 1.
        """
        return (Self.day_of_year(dt) // 7).cast[DType.uint8]()

    @staticmethod
    def is_leapsec(dt: _NaiveDateTime) -> Bool:
        """Whether the second is a leap second.

        Args:
            dt: The naive datetime.

        Returns:
            Bool.
        """

        comptime if not Self._include_leapsecs:
            return False

        if unlikely(
            dt.hour == 23
            and dt.minute == 59
            and dt.second == 59
            and (dt.month == 6 or dt.month == 12)
            and (dt.day == 30 or dt.day == 31)
        ):
            var h = Leapsec(dt).hash()

            comptime for i in range(Self._leapsec_size):
                comptime leapsec = Self._hashed_leapsec_array[i]
                if h == leapsec:
                    return True
            return False
        return False

    @staticmethod
    def leapsecs_since_epoch(dt: _NaiveDateTime) -> UInt32:
        """Cumulative leap seconds since the calendar's epoch start.

        Args:
            dt: The naive datetime.

        Returns:
            The amount.
        """

        comptime if not Self._include_leapsecs:
            return 0

        if unlikely(dt.year < 1972):
            return 0
        comptime size = UInt32(Self._leapsec_size)
        var h = Leapsec(dt).hash()
        comptime last = Self._hashed_leapsec_array[size - 1]
        if h > last:
            return size
        amnt = UInt32(0)

        comptime for i in range(size):
            comptime leapsec = Self._hashed_leapsec_array[i]
            if h < leapsec:
                return amnt
            amnt += 1
        return amnt

    @always_inline
    @staticmethod
    def _leapdays_since_epoch[min_year: UInt16](dt: _NaiveDateTime) -> UInt32:
        var y = UInt32(dt.year - min_year)
        var l = Self.is_leapyear(dt.year) and (dt.month, dt.day) >= (
            UInt8(2),
            UInt8(29),
        )
        return y // 4 - y // 100 + y // 400 + UInt32(l)

    @always_inline
    @staticmethod
    def leapdays_since_epoch(dt: _NaiveDateTime) -> UInt32:
        """Cumulative leap days since the calendar's default epoch start.

        Args:
            dt: The naive datetime.

        Returns:
            The amount.
        """
        comptime if Self.min_year <= 1:
            return Self._leapdays_since_epoch[Self.min_year](dt)
        else:
            var dt_2 = _NaiveDateTime(
                Self.min_year,
                Self.min_month,
                Self.min_day,
            )
            return (
                Self._leapdays_since_epoch[1](dt)
            ) - Self._leapdays_since_epoch[1](dt_2)

    @always_inline
    @staticmethod
    def _days_since_epoch[
        min_year: UInt16, min_month: UInt8, min_day: UInt8
    ](dt: _NaiveDateTime) -> UInt32:
        var y_d1 = UInt32((dt.year - min_year) * Self.max_typical_days_in_year)
        var leapdays = Self._leapdays_since_epoch[min_year](
            {dt.year, min_month, min_day}
        )
        var doy = UInt32(Self.day_of_year(dt)) - UInt32(min_day)
        return y_d1 + leapdays + doy

    @always_inline
    @staticmethod
    def days_since_epoch(dt: _NaiveDateTime) -> UInt32:
        """Cumulative days since the calendar's default epoch start.

        Args:
            dt: The naive datetime.

        Returns:
            The amount: [0, 9998].
        """
        var lhs = Self._days_since_epoch[1, 1, 1](dt)
        comptime if (
            Self.min_year == 1 and Self.min_month == 1 and Self.min_day == 1
        ):
            return lhs
        return lhs - Self._days_since_epoch[1, 1, 1](
            {Self.min_year, Self.min_month, Self.min_day}
        )

    @staticmethod
    def to_delta_since_epoch[
        unit: SITimeUnit, dtype: DType = DType.uint64
    ](dt: _NaiveDateTime) -> Scalar[dtype]:
        """The amount of time since the begining of the calendar's epoch.

        Parameters:
            unit: The time unit.
            dtype: The dtype in which to store the time delta.

        Args:
            dt: The naive datetime.

        Returns:
            The amount.
        """
        var days = Scalar[dtype](Self.days_since_epoch(dt))
        comptime if unit == SITimeUnit.DAYS:
            return days

        var hours = days * Scalar[dtype](Self.max_hour + 1) + Scalar[dtype](
            dt.hour - Self.min_hour
        )
        comptime if unit == SITimeUnit.HOURS:
            return hours

        var minutes = hours * Scalar[dtype](Self.max_minute + 1) + Scalar[
            dtype
        ](dt.minute - Self.min_minute)
        comptime if unit == SITimeUnit.MINUTES:
            return minutes

        var leaps = Self.leapsecs_since_epoch(dt)
        var seconds = (
            minutes * Scalar[dtype](Self.max_typical_second + 1)
            + Scalar[dtype](dt.second - Self.min_second)
        ) - Scalar[dtype](leaps)
        comptime if unit == SITimeUnit.SECONDS:
            return seconds

        var m_seconds = seconds * Scalar[dtype](
            Self.max_millisecond + 1
        ) + Scalar[dtype](dt.m_second - Self.min_millisecond)
        comptime if unit == SITimeUnit.MILLISECONDS:
            return m_seconds

        var u_seconds = m_seconds * Scalar[dtype](
            Self.max_microsecond + 1
        ) + Scalar[dtype](dt.u_second - Self.min_microsecond)
        comptime if unit == SITimeUnit.MICROSECONDS:
            return u_seconds

        var n_seconds = u_seconds * Scalar[dtype](
            Self.max_nanosecond + 1
        ) + Scalar[dtype](dt.n_second - Self.min_nanosecond)
        comptime if unit == SITimeUnit.NANOSECONDS:
            return n_seconds
        else:
            comptime assert False, "time unit not implemented"

    @staticmethod
    def to_delta_since_unix_epoch[
        unit: SITimeUnit, dtype: DType = DType.uint64
    ](dt: _NaiveDateTime) -> Tuple[Bool, Scalar[dtype]]:
        """The amount of time since the begining of the unix epoch (1970-01-01).

        Parameters:
            unit: The time unit.
            dtype: The dtype in which to store the time delta.

        Args:
            dt: The naive datetime.

        Returns:
            - Whether the offset is positive.
            - The amount.
        """
        var lhs = Self.to_delta_since_epoch[unit, dtype](dt)
        var rhs = Self._unix_calendar().to_delta_since_epoch[unit, dtype](dt)
        if dt.year >= 1970:
            return True, lhs - rhs
        else:
            return False, rhs - lhs

    @staticmethod
    def hash[cal_h: CalendarHashes](dt: _NaiveDateTime) -> Scalar[cal_h.dtype]:
        """Hash the given values according to the calendar's bitshifted
        component lengths, BigEndian (i.e. yyyymmdd...).

        Parameters:
            cal_h: The hashing schema (CalendarHashes).

        Args:
            dt: The naive datetime.

        Returns:
            The hash.
        """

        comptime U = Scalar[cal_h.dtype]
        comptime if cal_h.dtype == DType.uint8:
            return (U(dt.day) << cal_h.shift_8_d) | (
                U(dt.hour) << cal_h.shift_8_h
            )
        elif cal_h.dtype == DType.uint16:
            return (
                (U(dt.year) << cal_h.shift_16_y)
                | (U(Self.day_of_year(dt)) << cal_h.shift_16_d)
                | (U(dt.hour) << cal_h.shift_16_h)
            )
        elif cal_h.dtype == DType.uint32:
            return (
                (U(dt.year) << cal_h.shift_32_y)
                | (U(dt.month) << cal_h.shift_32_mon)
                | (U(dt.day) << cal_h.shift_32_d)
                | (U(dt.hour) << cal_h.shift_32_h)
                | (U(dt.minute) << cal_h.shift_32_m)
            )
        elif cal_h.dtype == DType.uint64:
            return (
                (U(dt.year) << cal_h.shift_64_y)
                | (U(dt.month) << cal_h.shift_64_mon)
                | (U(dt.day) << cal_h.shift_64_d)
                | (U(dt.hour) << cal_h.shift_64_h)
                | (U(dt.minute) << cal_h.shift_64_m)
                | (U(dt.second) << cal_h.shift_64_s)
                | (U(dt.m_second) << cal_h.shift_64_ms)
                | U(dt.u_second)
            )
        else:
            comptime assert False, "hash variant not implemented"

    @staticmethod
    def from_hash(value: Scalar) -> _NaiveDateTime:
        """Build a date from a hashed value.

        Args:
            value: The Hash.

        Returns:
            Tuple containing date data.
        """
        var result = _NaiveDateTime()
        comptime assert value.dtype in (
            DType.uint64,
            DType.uint32,
            DType.uint16,
            DType.uint8,
        ), "the hash dtype is not implemented"
        comptime cal_h = CalendarHashes[value.dtype]()

        comptime if cal_h.dtype == DType.uint8:
            result.day = {UInt8(value >> cal_h.shift_8_d) & cal_h.mask_8_d}
            result.hour = {UInt8(value >> cal_h.shift_8_h) & cal_h.mask_8_h}
        elif cal_h.dtype == DType.uint16:
            result.year = {UInt16(value >> cal_h.shift_16_y) & cal_h.mask_16_y}
            var doy = UInt16(value >> cal_h.shift_16_d) & cal_h.mask_16_d
            ref month, day = Self.day_of_month(result.year, doy)
            result.month = month
            result.day = day
            result.hour = {UInt16(value >> cal_h.shift_16_h) & cal_h.mask_16_h}
        elif cal_h.dtype == DType.uint32:
            result.year = {UInt32(value >> cal_h.shift_32_y) & cal_h.mask_32_y}
            result.month = {
                UInt32(value >> cal_h.shift_32_mon) & cal_h.mask_32_mon
            }
            result.day = {UInt32(value >> cal_h.shift_32_d) & cal_h.mask_32_d}
            result.hour = {UInt32(value >> cal_h.shift_32_h) & cal_h.mask_32_h}
            result.minute = {
                UInt32(value >> cal_h.shift_32_m) & cal_h.mask_32_m
            }
        elif cal_h.dtype == DType.uint64:
            result.year = {UInt64(value >> cal_h.shift_64_y) & cal_h.mask_64_y}
            result.month = {
                UInt64(value >> cal_h.shift_64_mon) & cal_h.mask_64_mon
            }
            result.day = {UInt64(value >> cal_h.shift_64_d) & cal_h.mask_64_d}
            result.hour = {UInt64(value >> cal_h.shift_64_h) & cal_h.mask_64_h}
            result.minute = {
                UInt64(value >> cal_h.shift_64_m) & cal_h.mask_64_m
            }
            result.second = {
                UInt64(value >> cal_h.shift_64_s) & cal_h.mask_64_s
            }
            result.m_second = {
                UInt64(value >> cal_h.shift_64_ms) & cal_h.mask_64_ms
            }
            result.u_second = {UInt64(value) & cal_h.mask_64_us}
        return result

    @staticmethod
    @always_inline
    def is_leapyear(year: UInt16) -> Bool:
        """Whether the year is a leap year.

        Args:
            year: Year.

        Returns:
            Bool.
        """
        return year % 4 == 0 and (year % 100 != 0 or year % 400 == 0)

    def __eq__(self, other: Calendar) -> Bool:
        """Compare self with other.

        Args:
            other: The other.

        Returns:
            The result.
        """
        comptime Other = type_of(other)
        comptime res = (
            Self.max_year == Other.max_year
            and Self.max_typical_days_in_year == Other.max_typical_days_in_year
            and Self.max_possible_days_in_year
            == Other.max_possible_days_in_year
            and Self.max_month == Other.max_month
            and Self.max_hour == Other.max_hour
            and Self.max_minute == Other.max_minute
            and Self.max_typical_second == Other.max_typical_second
            and Self.max_possible_second == Other.max_possible_second
            and Self.max_millisecond == Other.max_millisecond
            and Self.max_microsecond == Other.max_microsecond
            and Self.max_nanosecond == Other.max_nanosecond
            and Self.min_year == Other.min_year
            and Self.min_month == Other.min_month
            and Self.min_day == Other.min_day
            and Self.min_hour == Other.min_hour
            and Self.min_minute == Other.min_minute
            and Self.min_second == Other.min_second
            and Self.min_millisecond == Other.min_millisecond
            and Self.min_microsecond == Other.min_microsecond
            and Self.min_nanosecond == Other.min_nanosecond
        )
        return res

    def __ne__(self, other: Calendar) -> Bool:
        """Compare self with other.

        Args:
            other: The other.

        Returns:
            The result.
        """
        return not (self == other)


# ===----------------------------------------------------------------------=== #
# Gregorian calendar
# ===----------------------------------------------------------------------=== #


struct Gregorian[
    leapsec_size_: Int,
    //,
    include_leapsecs_: Bool = True,
    min_year_: UInt16 = 1,
    hashed_leapsec_array_: InlineArray[
        UInt32, leapsec_size_
    ] = gregorian_leapsecs,
](Calendar):
    """`Gregorian` Calendar.

    Parameters:
        leapsec_size_: The size of the hashed leapsec array.
        include_leapsecs_: Whether to include leap seconds in calculations.
        min_year_: The default min year for the calendar.
        hashed_leapsec_array_: The array with the hashed leap seconds.
    """

    comptime _leapsec_size = Self.hashed_leapsec_array_.size
    comptime _hashed_leapsec_array = Self.hashed_leapsec_array_
    comptime _include_leapsecs = Self.include_leapsecs_
    comptime _unix_calendar: Calendar = Gregorian[
        Self.include_leapsecs_, 1970, Self.hashed_leapsec_array_
    ]
    comptime min_year: UInt16 = Self.min_year_
    """Default minimum year in the calendar."""

    def __init__(out self):
        """Construct a `Gregorian` Calendar."""
        ...


# ===----------------------------------------------------------------------=== #
# ISO calendar
# ===----------------------------------------------------------------------=== #


struct ISOCalendar[
    leapsec_size_: Int,
    //,
    include_leapsecs_: Bool = True,
    min_year_: UInt16 = 1,
    hashed_leapsec_array_: InlineArray[
        UInt32, leapsec_size_
    ] = gregorian_leapsecs,
](Calendar):
    """An ISO-8601 Calendar.

    Parameters:
        leapsec_size_: The size of the hashed leapsec array.
        include_leapsecs_: Whether to include leap seconds in calculations.
        min_year_: The default min year for the calendar.
        hashed_leapsec_array_: The array with the hashed leap seconds.
    """

    comptime max_possible_weeks_in_year: UInt8 = 53
    """Maximum possible value of weeks in a year (with leaps)."""
    comptime min_weeks_in_year: UInt8 = 1
    """Minimum value of weeks in a year."""

    comptime MONDAY: UInt8 = 1
    """Raw Monday value for this calendar."""
    comptime TUESDAY: UInt8 = 2
    """Raw Tuesday value for this calendar."""
    comptime WEDNESDAY: UInt8 = 3
    """Raw Wednesday value for this calendar."""
    comptime THURSDAY: UInt8 = 4
    """Raw Thursday value for this calendar."""
    comptime FRIDAY: UInt8 = 5
    """Raw Friday value for this calendar."""
    comptime SATURDAY: UInt8 = 6
    """Raw Saturday value for this calendar."""
    comptime SUNDAY: UInt8 = 7
    """Raw Sunday value for this calendar."""

    comptime _leapsec_size = Self.hashed_leapsec_array_.size
    comptime _hashed_leapsec_array = Self.hashed_leapsec_array_
    comptime _include_leapsecs = Self.include_leapsecs_
    comptime _unix_calendar: Calendar = Gregorian[
        Self.include_leapsecs_, 1970, Self.hashed_leapsec_array_
    ]
    comptime _min_year: UInt16 = Self.min_year_

    comptime _greg = Gregorian[
        Self.include_leapsecs_, Self.min_year_, Self.hashed_leapsec_array_
    ]

    def __init__(out self):
        """Construct an `ISOCalendar`."""
        ...

    @staticmethod
    @always_inline
    def day_of_week(dt: _NaiveDateTime) -> UInt8:
        """Calculates the day of the week for a given date.

        Args:
            dt: The naive datetime.

        Returns:
            Day of the week [monday, sunday]: [0, 6] (Gregorian) [1, 7]
            (ISOCalendar).
        """
        return Self._greg.day_of_week(dt) + 1

    @staticmethod
    def week_of_year(dt: _NaiveDateTime) -> UInt8:
        """Calculates the week of the year for a given date.

        Args:
            dt: The naive datetime.

        Returns:
            Week of the year: [0, 52] (Gregorian), [1, 53] (ISOCalendar).

        Notes:
            Gregorian takes the first day of the year as starting week 0,
            ISOCalendar follows [ISO 8601](\
            https://en.wikipedia.org/wiki/ISO_week_date) which takes the first
            thursday of the year as starting week 1.
        """

        comptime iso_thursday = 4
        var doy = Int16(Self.day_of_year(dt))  # [1, 366]
        var dow = Int16(Self.day_of_week(dt))  # [1, 7]
        var thursday_doy = doy + iso_thursday - dow  # [-2, 369]

        # If the Thursday of this week falls in the previous year, it belongs to
        # the last week of the previous year.
        if thursday_doy < 1:
            return Self.week_of_year({dt.year - 1, 12, 31})

        # If the Thursday of this week falls in the next year, it is Week 1 of
        # that next year.
        var days_in_current_year = Int16(Self.day_of_year({dt.year, 12, 31}))
        if thursday_doy > days_in_current_year:
            return 1

        return UInt8(((thursday_doy - 1) // 7) + 1)  # [1, 53]
