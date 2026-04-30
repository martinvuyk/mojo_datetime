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

from .calendar import Calendar, _NaiveDateTime


@fieldwise_init
struct _TzNaiveDateTime[calendar: Calendar](
    Comparable, Defaultable, ImplicitlyCopyable, Writable
):
    var dt: _NaiveDateTime

    def __init__(out self):
        self = {
            {
                Self.calendar.min_year,
                Self.calendar.min_month,
                Self.calendar.min_day,
                Self.calendar.min_hour,
                Self.calendar.min_minute,
                Self.calendar.min_second,
                Self.calendar.min_millisecond,
                Self.calendar.min_microsecond,
                Self.calendar.min_nanosecond,
            }
        }

    @always_inline
    def __lt__(self, other: Self) -> Bool:
        """Lt.

        Args:
            other: Other.

        Returns:
            Bool.
        """
        return self.dt < other.dt

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

        Notes:
            On overflow, the `DateTime` starts from the beginning of the
            calendar's epoch and keeps evaluating until valid.
        """

        var max_year = UInt64(self.calendar.max_year)
        var y = UInt64(self.dt.year) + years
        if y > max_year:
            self.dt.year = self.calendar.min_year
            self = self.add(years=y - (max_year + 1))
        else:
            self.dt.year = UInt16(y)

        var max_mon = UInt64(self.calendar.max_month)
        var mon = UInt64(self.dt.month) + months
        if mon > max_mon:
            self.dt.month = self.calendar.min_month
            self = self.add(years=1, months=mon - (max_mon + 1))
        else:
            self.dt.month = UInt8(mon)

        var max_day = UInt64(self.calendar.max_days_in_month(self.dt))
        var d = UInt64(self.dt.day) + days
        if d > max_day:
            self.dt.day = self.calendar.min_day
            self = self.add(months=1, days=d - (max_day + 1))
        else:
            self.dt.day = UInt8(d)

        var max_hour = UInt64(self.calendar.max_hour)
        var h = UInt64(self.dt.hour) + hours
        if h > max_hour:
            self.dt.hour = self.calendar.min_hour
            self = self.add(days=1, hours=h - (max_hour + 1))
        else:
            self.dt.hour = UInt8(h)

        var max_min = UInt64(self.calendar.max_minute)
        var mi = UInt64(self.dt.minute) + minutes
        if mi > max_min:
            self.dt.minute = self.calendar.min_minute
            self = self.add(hours=1, minutes=mi - (max_min + 1))
        else:
            self.dt.minute = UInt8(mi)

        var max_sec = self.calendar.max_second(self.dt)
        var s = UInt64(self.dt.second) + seconds
        if s > UInt64(max_sec):
            self.dt.second = self.calendar.min_second
            self = self.add(minutes=1, seconds=s - (UInt64(max_sec) + 1))
        else:
            self.dt.second = UInt8(s)

        var max_msec = UInt64(self.calendar.max_millisecond)
        var ms = UInt64(self.dt.m_second) + m_seconds
        if ms > max_msec:
            self.dt.m_second = self.calendar.min_millisecond
            self = self.add(seconds=1, m_seconds=ms - (max_msec + 1))
        else:
            self.dt.m_second = UInt16(ms)

        var max_usec = UInt64(self.calendar.max_microsecond)
        var us = UInt64(self.dt.u_second) + u_seconds
        if us > max_usec:
            self.dt.u_second = self.calendar.min_microsecond
            self = self.add(m_seconds=1, u_seconds=us - (max_usec + 1))
        else:
            self.dt.u_second = UInt16(us)

        var max_nsec = UInt64(self.calendar.max_nanosecond)
        var ns = UInt64(self.dt.n_second) + n_seconds
        if ns > max_nsec:
            self.dt.n_second = self.calendar.min_nanosecond
            self = self.add(u_seconds=1, n_seconds=ns - (max_nsec + 1))
        else:
            self.dt.n_second = UInt16(ns)
        return self

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

        Notes:
            On overflow, the `DateTime` goes to the end of the calendar's epoch
            and keeps evaluating until valid.
        """

        var min_nsec = Int64(self.calendar.min_nanosecond)
        var ns = Int64(self.dt.n_second) - Int64(n_seconds)
        if ns < min_nsec:
            self.dt.n_second = self.calendar.max_nanosecond
            self = self.subtract(
                u_seconds=1, n_seconds=UInt64((Int64(min_nsec) - 1) - ns)
            )
        else:
            self.dt.n_second = UInt16(ns)

        var min_usec = Int64(self.calendar.min_microsecond)
        var us = Int64(self.dt.u_second) - Int64(u_seconds)
        if us < min_usec:
            self.dt.u_second = self.calendar.max_microsecond
            self = self.subtract(
                m_seconds=1, u_seconds=UInt64((Int64(min_usec) - 1) - us)
            )
        else:
            self.dt.u_second = UInt16(us)

        var min_msec = Int64(self.calendar.min_millisecond)
        var ms = Int64(self.dt.m_second) - Int64(m_seconds)
        if ms < min_msec:
            self.dt.m_second = self.calendar.max_millisecond
            self = self.subtract(
                seconds=1, m_seconds=UInt64((Int64(min_msec) - 1) - ms)
            )
        else:
            self.dt.m_second = UInt16(ms)

        var min_sec = Int64(self.calendar.min_second)
        var s = Int64(self.dt.second) - Int64(seconds)
        if s < min_sec:
            sec = self.calendar.max_second(self.dt)
            self.dt.second = sec
            self = self.subtract(
                minutes=1, seconds=UInt64((Int64(min_sec) - 1) - s)
            )
        else:
            self.dt.second = UInt8(s)

        var min_min = Int64(self.calendar.min_minute)
        var mi = Int64(self.dt.minute) - Int64(minutes)
        if mi < min_min:
            self.dt.minute = self.calendar.max_minute
            self = self.subtract(
                hours=1, minutes=UInt64((Int64(min_min) - 1) - mi)
            )
        else:
            self.dt.minute = UInt8(mi)

        var min_hour = Int64(self.calendar.min_hour)
        var h = Int64(self.dt.hour) - Int64(hours)
        if h < min_hour:
            self.dt.hour = self.calendar.max_hour
            self = self.subtract(
                days=1, hours=UInt64((Int64(min_hour) - 1) - h)
            )
        else:
            self.dt.hour = UInt8(h)

        var min_day = Int64(self.calendar.min_day)
        var d = Int64(self.dt.day) - Int64(days)
        if d < min_day:
            self.dt.day = 1
            self = self.subtract(months=1)
            self.dt.day = self.calendar.max_days_in_month(self.dt)
            self = self.subtract(days=UInt64((Int64(min_day) - 1) - d))
        else:
            self.dt.day = UInt8(d)

        var min_month = Int64(self.calendar.min_month)
        var mon = Int64(self.dt.month) - Int64(months)
        if mon < min_month:
            self.dt.month = self.calendar.max_month
            self = self.subtract(
                years=1, months=UInt64((Int64(min_month) - 1) - mon)
            )
        else:
            self.dt.month = UInt8(mon)

        var min_year = Int64(self.calendar.min_year)
        var y = Int64(self.dt.year) - Int64(years)
        if y < min_year:
            self.dt.year = self.calendar.max_year
            self = self.subtract(years=UInt64((min_year - 1) - y))
        else:
            self.dt.year = UInt16(y)
        return self.add(days=0)  #  to correct days and months

    def to_calendar[cal: Calendar](self) -> _TzNaiveDateTime[cal]:
        comptime if Self.calendar() == cal:
            return rebind[_TzNaiveDateTime[cal]](self)

        var is_positive, seconds = self.calendar.to_delta_since_unix_epoch[
            SITimeUnit.SECONDS
        ](self.dt)
        var m_seconds = seconds * UInt64(
            self.calendar.max_millisecond + 1
        ) + UInt64(self.dt.m_second - self.calendar.min_millisecond)
        var u_seconds = m_seconds * UInt64(
            self.calendar.max_microsecond + 1
        ) + UInt64(self.dt.u_second - self.calendar.min_microsecond)
        var n_seconds = u_seconds * UInt64(
            self.calendar.max_nanosecond + 1
        ) + UInt64(self.dt.n_second - self.calendar.min_nanosecond)
        if is_positive:
            return _TzNaiveDateTime[cal]().add(
                seconds=seconds,
                m_seconds=m_seconds,
                u_seconds=u_seconds,
                n_seconds=n_seconds,
            )
        else:
            return _TzNaiveDateTime[cal]().subtract(
                seconds=seconds,
                m_seconds=m_seconds,
                u_seconds=u_seconds,
                n_seconds=n_seconds,
            )
