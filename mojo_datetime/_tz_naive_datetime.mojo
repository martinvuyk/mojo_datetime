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


# FIXME(https://github.com/modular/modular/issues/6460): make this TrivialRegisterPassable
@fieldwise_init
struct _TzNaiveDateTime[calendar: Calendar](
    Comparable, Defaultable, ImplicitlyCopyable, Writable
):
    var dt: _NaiveDateTime

    @always_inline
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
        if y <= max_year:
            self.dt.year = UInt16(y)
        else:
            var max_val = UInt64(
                self.calendar.max_year + UInt16(self.calendar.min_year == 0)
            )
            var delta = y - (max_year + 1)
            self.dt.year = self.calendar.min_year + UInt16(delta % max_val)

        var max_mon = UInt64(self.calendar.max_month)
        var mon = UInt64(self.dt.month) + months
        if mon <= max_mon:
            self.dt.month = UInt8(mon)
        else:
            var years = UInt64(1)
            var delta = mon - (max_mon + 1)
            var max_val = UInt64(
                self.calendar.max_month + UInt8(self.calendar.min_month == 0)
            )
            if delta >= max_val:
                years += delta // max_val
                delta = delta % max_val
            self.dt.month = self.calendar.min_month + UInt8(delta)
            self = self.add(years=years)

        var max_day = UInt64(self.calendar.max_days_in_month(self.dt))
        var d = UInt64(self.dt.day) + days
        if d <= max_day:
            self.dt.day = UInt8(d)
        else:
            self.dt.day = self.calendar.min_day
            self = self.add(months=1)

            var delta = d - (max_day + 1)
            var max_val = UInt64(
                self.calendar.max_possible_days_in_month
                + UInt8(self.calendar.min_day == 0)
            )
            if delta >= max_val:
                var days_before = self.calendar.days_since_epoch(self.dt)
                self = self.add(months=delta // max_val)
                var days_after = self.calendar.days_since_epoch(self.dt)
                var diff = Int64(days_after) - Int64(days_before)
                if diff < 0:
                    var y, m = self.calendar.max_year, self.calendar.max_month
                    var md = self.calendar.max_days_in_month(
                        {y, m, self.calendar.min_day}
                    )
                    diff += Int64(
                        self.calendar.days_since_epoch({y, m, md}) + 1
                    )
                delta -= UInt64(diff)

            while delta > 0:
                var curr_month_days = UInt64(
                    self.calendar.max_days_in_month(self.dt)
                    + UInt8(self.calendar.min_day == 0)
                )
                if delta >= curr_month_days:
                    delta -= curr_month_days
                    self = self.add(months=1)
                else:
                    self.dt.day = self.calendar.min_day + UInt8(delta)
                    delta = 0

        var max_hour = UInt64(self.calendar.max_hour)
        var h = UInt64(self.dt.hour) + hours
        if h <= max_hour:
            self.dt.hour = UInt8(h)
        else:
            var days = UInt64(1)
            var delta = h - (max_hour + 1)
            var max_val = UInt64(
                self.calendar.max_hour + UInt8(self.calendar.min_hour == 0)
            )
            if delta >= max_val:
                days += delta // max_val
                delta = delta % max_val
            self.dt.hour = self.calendar.min_hour + UInt8(delta)
            self = self.add(days=days)

        var max_min = UInt64(self.calendar.max_minute)
        var mi = UInt64(self.dt.minute) + minutes
        if mi <= max_min:
            self.dt.minute = UInt8(mi)
        else:
            var hours = UInt64(1)
            var delta = mi - (max_min + 1)
            var max_val = UInt64(
                self.calendar.max_minute + UInt8(self.calendar.min_minute == 0)
            )
            if delta >= max_val:
                hours += delta // max_val
                delta = delta % max_val
            self.dt.minute = self.calendar.min_minute + UInt8(delta)
            self = self.add(hours=hours)

        var max_sec = UInt64(self.calendar.max_second(self.dt))
        var s = UInt64(self.dt.second) + seconds
        if s <= max_sec:
            self.dt.second = UInt8(s)
        else:
            self.dt.second = self.calendar.min_second
            self = self.add(minutes=1)

            var delta = s - (max_sec + 1)
            var max_val = UInt64(
                self.calendar.max_possible_second
                + UInt8(self.calendar.min_second == 0)
            )
            if delta >= max_val:
                var seconds_before = self.calendar.to_delta_since_epoch[
                    SITimeUnit.SECONDS
                ](self.dt)
                self = self.add(minutes=delta // max_val)
                var seconds_after = self.calendar.to_delta_since_epoch[
                    SITimeUnit.SECONDS
                ](self.dt)
                var diff = Int64(seconds_after) - Int64(seconds_before)
                if diff < 0:
                    var y, m = self.calendar.max_year, self.calendar.max_month
                    var md = self.calendar.max_days_in_month(
                        {y, m, self.calendar.min_day}
                    )
                    var h = self.calendar.max_hour
                    var mi = self.calendar.max_minute
                    var s = self.calendar.max_second({y, m, md, h, mi})
                    var epoch = self.calendar.to_delta_since_epoch[
                        SITimeUnit.SECONDS
                    ]({y, m, md, h, mi, s})
                    diff += Int64(epoch + 1)
                delta -= UInt64(diff)

            var curr_minute_seconds = UInt64(
                self.calendar.max_second(self.dt)
                + UInt8(self.calendar.min_second == 0)
            )

            while delta >= curr_minute_seconds:
                delta -= curr_minute_seconds
                self = self.add(minutes=1)
                curr_minute_seconds = UInt64(
                    self.calendar.max_second(self.dt)
                    + UInt8(self.calendar.min_second == 0)
                )

            self.dt.second = self.calendar.min_second + UInt8(delta)

        var max_msec = UInt64(self.calendar.max_millisecond)
        var ms = UInt64(self.dt.m_second) + m_seconds
        if ms <= max_msec:
            self.dt.m_second = UInt16(ms)
        else:
            var seconds = UInt64(1)
            var delta = ms - (max_msec + 1)
            var max_val = UInt64(
                self.calendar.max_millisecond
                + UInt16(self.calendar.min_millisecond == 0)
            )
            if delta >= max_val:
                seconds += delta // max_val
                delta = delta % max_val
            self.dt.m_second = self.calendar.min_millisecond + UInt16(delta)
            self = self.add(seconds=seconds)

        var max_usec = UInt64(self.calendar.max_microsecond)
        var us = UInt64(self.dt.u_second) + u_seconds
        if us <= max_usec:
            self.dt.u_second = UInt16(us)
        else:
            var m_seconds = UInt64(1)
            var delta = us - (max_usec + 1)
            var max_val = UInt64(
                self.calendar.max_microsecond
                + UInt16(self.calendar.min_microsecond == 0)
            )
            if delta >= max_val:
                m_seconds += delta // max_val
                delta = delta % max_val
            self.dt.u_second = self.calendar.min_microsecond + UInt16(delta)
            self = self.add(m_seconds=m_seconds)

        var max_nsec = UInt64(self.calendar.max_nanosecond)
        var ns = UInt64(self.dt.n_second) + n_seconds
        if ns <= max_nsec:
            self.dt.n_second = UInt16(ns)
        else:
            var u_seconds = UInt64(1)
            var delta = ns - (max_nsec + 1)
            var max_val = UInt64(
                self.calendar.max_nanosecond
                + UInt16(self.calendar.min_nanosecond == 0)
            )
            if delta >= max_val:
                u_seconds += delta // max_val
                delta = delta % max_val
            self.dt.n_second = self.calendar.min_nanosecond + UInt16(delta)
            self = self.add(u_seconds=u_seconds)
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
        if ns >= min_nsec:
            self.dt.n_second = UInt16(ns)
        else:
            var u_seconds = UInt64(1)
            var delta = UInt64((Int64(min_nsec) - 1) - ns)
            var max_val = UInt64(
                self.calendar.max_nanosecond
                + UInt16(self.calendar.min_nanosecond == 0)
            )
            if delta >= max_val:
                u_seconds += delta // max_val
                delta = delta % max_val
            self.dt.n_second = self.calendar.max_nanosecond - UInt16(delta)
            self = self.subtract(u_seconds=u_seconds)

        var min_usec = Int64(self.calendar.min_microsecond)
        var us = Int64(self.dt.u_second) - Int64(u_seconds)
        if us >= min_usec:
            self.dt.u_second = UInt16(us)
        else:
            var m_seconds = UInt64(1)
            var delta = UInt64((Int64(min_usec) - 1) - us)
            var max_val = UInt64(
                self.calendar.max_microsecond
                + UInt16(self.calendar.min_microsecond == 0)
            )
            if delta >= max_val:
                m_seconds += delta // max_val
                delta = delta % max_val
            self.dt.u_second = self.calendar.max_microsecond - UInt16(delta)
            self = self.subtract(m_seconds=m_seconds)

        var min_msec = Int64(self.calendar.min_millisecond)
        var ms = Int64(self.dt.m_second) - Int64(m_seconds)
        if ms >= min_msec:
            self.dt.m_second = UInt16(ms)
        else:
            var seconds = UInt64(1)
            var delta = UInt64((Int64(min_msec) - 1) - ms)
            var max_val = UInt64(
                self.calendar.max_millisecond
                + UInt16(self.calendar.min_millisecond == 0)
            )
            if delta >= max_val:
                seconds += delta // max_val
                delta = delta % max_val
            self.dt.m_second = self.calendar.max_millisecond - UInt16(delta)
            self = self.subtract(seconds=seconds)

        var min_sec = Int64(self.calendar.min_second)
        var s = Int64(self.dt.second) - Int64(seconds)
        if s >= min_sec:
            self.dt.second = UInt8(s)
        else:
            self = self.subtract(minutes=1)

            var delta = UInt64((Int64(min_sec) - 1) - s)
            var max_val = UInt64(
                self.calendar.max_possible_second
                + UInt8(self.calendar.min_second == 0)
            )
            if delta >= max_val:
                var seconds_before = self.calendar.to_delta_since_epoch[
                    SITimeUnit.SECONDS
                ](self.dt)
                self = self.subtract(minutes=delta // max_val)
                var seconds_after = self.calendar.to_delta_since_epoch[
                    SITimeUnit.SECONDS
                ](self.dt)

                var diff = Int64(seconds_before) - Int64(seconds_after)
                if diff < 0:
                    var y, m = self.calendar.min_year, self.calendar.min_month
                    var md = self.calendar.max_days_in_month(
                        {y, m, self.calendar.min_day}
                    )
                    var h = self.calendar.min_hour
                    var mi = self.calendar.min_minute
                    var s = self.calendar.min_second
                    var epoch = self.calendar.to_delta_since_epoch[
                        SITimeUnit.SECONDS
                    ]({y, m, md, h, mi, s})
                    diff -= Int64(epoch + 1)
                delta -= UInt64(diff)

            var prev_minute_seconds = UInt64(
                self.calendar.max_second(self.dt)
                + UInt8(self.calendar.min_second == 0)
            )

            while delta >= prev_minute_seconds:
                delta -= prev_minute_seconds
                self = self.subtract(minutes=1)
                prev_minute_seconds = UInt64(
                    self.calendar.max_second(self.dt)
                    + UInt8(self.calendar.min_second == 0)
                )

            self.dt.second = self.calendar.max_second(self.dt) - UInt8(delta)

        var min_min = Int64(self.calendar.min_minute)
        var mi = Int64(self.dt.minute) - Int64(minutes)
        if mi >= min_min:
            self.dt.minute = UInt8(mi)
        else:
            var hours = UInt64(1)
            var delta = UInt64((Int64(min_min) - 1) - mi)
            var max_val = UInt64(
                self.calendar.max_minute + UInt8(self.calendar.min_minute == 0)
            )
            if delta >= max_val:
                hours += delta // max_val
                delta = delta % max_val
            self.dt.minute = self.calendar.max_minute - UInt8(delta)
            self = self.subtract(hours=hours)

        var min_hour = Int64(self.calendar.min_hour)
        var h = Int64(self.dt.hour) - Int64(hours)
        if h >= min_hour:
            self.dt.hour = UInt8(h)
        else:
            var days = UInt64(1)
            var delta = UInt64((Int64(min_hour) - 1) - h)
            var max_val = UInt64(
                self.calendar.max_hour + UInt8(self.calendar.min_hour == 0)
            )
            if delta >= max_val:
                days += delta // max_val
                delta = delta % max_val
            self.dt.hour = self.calendar.max_hour - UInt8(delta)
            self = self.subtract(days=days)

        var min_day = Int64(self.calendar.min_day)
        var d = Int64(self.dt.day) - Int64(days)
        if d >= min_day:
            self.dt.day = UInt8(d)
        else:
            self.dt.day = self.calendar.min_day
            self = self.subtract(months=1)

            var delta = UInt64((min_day - 1) - d)
            var max_val = UInt64(
                self.calendar.max_possible_days_in_month
                + UInt8(self.calendar.min_day == 0)
            )
            if delta >= max_val:
                var days_before = self.calendar.days_since_epoch(self.dt)
                self = self.subtract(months=delta // max_val)
                var days_after = self.calendar.days_since_epoch(self.dt)
                var diff = Int64(days_before) - Int64(days_after)
                if diff < 0:
                    var y, m = self.calendar.max_year, self.calendar.max_month
                    var md = self.calendar.max_days_in_month(
                        {y, m, self.calendar.min_day}
                    )
                    diff += Int64(
                        self.calendar.days_since_epoch({y, m, md}) + 1
                    )
                delta -= UInt64(diff)

            var prev_month_max = UInt64(
                self.calendar.max_days_in_month(self.dt)
                + UInt8(self.calendar.min_day == 0)
            )

            while delta >= prev_month_max:
                delta -= prev_month_max
                self = self.subtract(months=1)
                # Recompute the new month's length for the next iteration
                prev_month_max = UInt64(
                    self.calendar.max_days_in_month(self.dt)
                    + UInt8(self.calendar.min_day == 0)
                )

            self.dt.day = self.calendar.max_days_in_month(self.dt) - UInt8(
                delta
            )

        var min_month = Int64(self.calendar.min_month)
        var mon = Int64(self.dt.month) - Int64(months)
        if mon >= min_month:
            self.dt.month = UInt8(mon)
        else:
            var years = UInt64(1)
            var delta = UInt64((Int64(min_month) - 1) - mon)
            var max_val = UInt64(
                self.calendar.max_month + UInt8(self.calendar.min_month == 0)
            )
            if delta >= max_val:
                years += delta // max_val
                delta = delta % max_val
            self.dt.month = self.calendar.max_month - UInt8(delta)
            self = self.subtract(years=years)

        var min_year = Int64(self.calendar.min_year)
        var y = Int64(self.dt.year) - Int64(years)
        if y >= min_year:
            self.dt.year = UInt16(y)
        else:
            var max_val = UInt64(
                self.calendar.max_year + UInt16(self.calendar.min_year == 0)
            )
            var delta = UInt64((min_year - 1) - y)
            self.dt.year = self.calendar.max_year - UInt16(delta % max_val)

        return self.add(days=0)  #  to correct days and months

    def to_calendar[cal: Calendar](self) -> _TzNaiveDateTime[cal]:
        comptime if Self.calendar() == cal():
            return rebind[_TzNaiveDateTime[cal]](self)

        var is_positive, seconds = self.calendar.to_delta_since_unix_epoch[
            SITimeUnit.SECONDS
        ](self.dt)
        var m_seconds = UInt64(self.dt.m_second - self.calendar.min_millisecond)
        var u_seconds = UInt64(self.dt.u_second - self.calendar.min_microsecond)
        var n_seconds = UInt64(self.dt.n_second - self.calendar.min_nanosecond)
        if is_positive:
            return _TzNaiveDateTime[cal](cal._unix_epoch).add(
                seconds=seconds,
                m_seconds=m_seconds,
                u_seconds=u_seconds,
                n_seconds=n_seconds,
            )
        else:
            return (
                _TzNaiveDateTime[cal](cal._unix_epoch)
                .subtract(seconds=seconds)
                .add(
                    m_seconds=m_seconds,
                    u_seconds=u_seconds,
                    n_seconds=n_seconds,
                )
            )

    @always_inline
    def subtract[
        unit: SITimeUnit = SITimeUnit.SECONDS, dtype: DType = DType.uint64
    ](var self, other: Self) -> TimeDelta[
        unit, dtype
    ] where dtype.is_unsigned():
        var s = self.calendar.to_delta_since_epoch[unit, dtype](self.dt)
        var o = other.calendar.to_delta_since_epoch[unit, dtype](other.dt)
        return {(s - o) if self >= other else (o - s)}
