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

        Notes:
            On overflow, the `DateTime` starts from the beginning of the
            calendar's epoch and keeps evaluating until valid.
        """
        comptime if Self.calendar._is_gregorian_family:
            return self._add_gregorian(
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
        else:
            return self._add_generic(
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

    def _add_generic(
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
            self = self._add_generic(years=years)

        var max_day = UInt64(self.calendar.max_days_in_month(self.dt))
        var d = UInt64(self.dt.day) + days
        if d <= max_day:
            self.dt.day = UInt8(d)
        else:
            self.dt.day = self.calendar.min_day
            self = self._add_generic(months=1)

            var delta = d - (max_day + 1)
            var max_val = UInt64(
                self.calendar.max_possible_days_in_month
                + UInt8(self.calendar.min_day == 0)
            )
            if delta >= max_val:
                var days_before = self.calendar.days_since_epoch(self.dt)
                self = self._add_generic(months=delta // max_val)
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
                    self = self._add_generic(months=1)
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
            self = self._add_generic(days=days)

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
            self = self._add_generic(hours=hours)

        var max_sec = UInt64(self.calendar.max_second(self.dt))
        var s = UInt64(self.dt.second) + seconds
        if s <= max_sec:
            self.dt.second = UInt8(s)
        else:
            self.dt.second = self.calendar.min_second
            self = self._add_generic(minutes=1)

            var delta = s - (max_sec + 1)
            var max_val = UInt64(
                self.calendar.max_possible_second
                + UInt8(self.calendar.min_second == 0)
            )
            if delta >= max_val:
                var seconds_before = self.calendar.to_delta_since_epoch[
                    SITimeUnit.SECONDS
                ](self.dt)
                self = self._add_generic(minutes=delta // max_val)
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
                self = self._add_generic(minutes=1)
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
            self = self._add_generic(seconds=seconds)

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
            self = self._add_generic(m_seconds=m_seconds)

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
            self = self._add_generic(u_seconds=u_seconds)
        return self

    @always_inline
    @staticmethod
    def _ymd_to_days(y: UInt16, m: UInt8, d: UInt8) -> UInt64:
        """Hinnant's algorithm to convert Y/M/D to days since 0001-01-01."""
        var y_int = Int64(y)
        var m_int = Int64(m)
        var d_int = Int64(d)

        y_int -= Int64(m_int <= 2)
        var era = y_int // 400
        var yoe = y_int - era * 400
        var mp = m_int + Int64(9 if m_int <= 2 else -3)
        var doy = (153 * mp + 2) // 5 + d_int - 1
        var doe = yoe * 365 + yoe // 4 - yoe // 100 + doy
        return UInt64(era * 146097 + doe - 306)

    @always_inline
    @staticmethod
    def _days_to_ymd(days: UInt64) -> Tuple[UInt16, UInt8, UInt8]:
        """Hinnant's algorithm to convert days since 0001-01-01 to Y/M/D."""
        var z = Int64(days) + 306
        var era = z // 146097
        var doe = z - era * 146097
        var yoe = (doe - doe // 1460 + doe // 36524 - doe // 146096) // 365
        var y = yoe + era * 400
        var doy = doe - (365 * yoe + yoe // 4 - yoe // 100)
        var mp = (5 * doy + 2) // 153
        var d = doy - (153 * mp + 2) // 5 + 1
        var m = mp + Int64(3 if mp < 10 else -9)
        var final_year = y + Int64(m <= 2)
        return UInt16(final_year), UInt8(m), UInt8(d)

    @always_inline
    @staticmethod
    def _from_days_since_epoch(days: UInt32) -> Tuple[UInt16, UInt8, UInt8]:
        """Safely maps Calendar epoch days back to Y/M/D."""
        comptime epoch_start = Self._ymd_to_days(Self.calendar.min_year, 1, 1)
        return Self._days_to_ymd(UInt64(days) + epoch_start)

    def _add_gregorian(
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
        var curr_ns = (
            UInt64(self.dt.m_second) * 1_000_000
            + UInt64(self.dt.u_second) * 1_000
            + UInt64(self.dt.n_second)
        )
        var add_ns = m_seconds * 1_000_000 + u_seconds * 1_000 + n_seconds

        var total_ns = curr_ns + add_ns
        var overflow_s = total_ns // 1_000_000_000
        var final_ns = total_ns % 1_000_000_000

        var total_added_s = hours * 3600 + minutes * 60 + seconds + overflow_s

        var y_temp = UInt64(self.dt.year) + years
        var m_temp = UInt64(self.dt.month) - 1 + months
        y_temp += m_temp // 12
        var final_month = UInt8((m_temp % 12) + 1)

        comptime max_y = UInt64(9999)
        if y_temp > max_y:
            comptime max_val = max_y + UInt64(Self.calendar.min_year == 0)
            var delta = y_temp - (max_y + 1)
            y_temp = UInt64(Self.calendar.min_year) + (delta % max_val)

        var final_year = UInt16(y_temp)

        var curr_days = Self._ymd_to_days(final_year, final_month, self.dt.day)
        var target_epoch_day = curr_days + days

        comptime min_y_days = Self._ymd_to_days(Self.calendar.min_year, 1, 1)
        comptime max_y_days = Self._ymd_to_days(9999, 12, 31)

        if target_epoch_day > max_y_days:
            comptime cal_total_days = max_y_days - min_y_days + 1
            var delta_days = target_epoch_day - (max_y_days + 1)
            target_epoch_day = min_y_days + (delta_days % cal_total_days)

        var f_y, f_m, f_d = Self._days_to_ymd(target_epoch_day)

        var start_linear_s = Self.calendar.to_delta_since_epoch[
            SITimeUnit.SECONDS, DType.int64
        ]({f_y, f_m, f_d, self.dt.hour, self.dt.minute, self.dt.second})
        var target_linear_s = start_linear_s + Int64(total_added_s)

        var cal_s = Self.calendar.to_delta_since_epoch[
            SITimeUnit.SECONDS, DType.int64
        ]({9999, 12, 31, 23, 59, 59})
        var cal_total_s = cal_s + 1

        if target_linear_s >= cal_total_s:
            target_linear_s = target_linear_s % cal_total_s

        var est_epoch_day = UInt32(target_linear_s // 86400)
        var est_y, est_m, est_d = Self._from_days_since_epoch(est_epoch_day)
        var est_linear = Self.calendar.to_delta_since_epoch[
            SITimeUnit.SECONDS, DType.int64
        ]({est_y, est_m, est_d})

        if est_linear > target_linear_s:
            est_epoch_day -= 1
            est_y, est_m, est_d = Self._from_days_since_epoch(est_epoch_day)
            est_linear = Self.calendar.to_delta_since_epoch[
                SITimeUnit.SECONDS, DType.int64
            ]({est_y, est_m, est_d})

        self.dt.year = est_y
        self.dt.month = est_m
        self.dt.day = est_d

        var rem_s = UInt64(target_linear_s - est_linear)
        if rem_s < 86400:
            self.dt.hour = UInt8(rem_s // 3600)
            self.dt.minute = UInt8((rem_s % 3600) // 60)
            self.dt.second = UInt8(rem_s % 60)
        else:  # leap second day
            self.dt.hour = 23
            self.dt.minute = 59
            self.dt.second = UInt8(59 + (rem_s - 86399))

        self.dt.m_second = UInt16(final_ns // 1_000_000)
        self.dt.u_second = UInt16((final_ns % 1_000_000) // 1_000)
        self.dt.n_second = UInt16(final_ns % 1_000)

        return self

    @always_inline
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
        comptime if Self.calendar._is_gregorian_family:
            return self._subtract_gregorian(
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
        else:
            return self._subtract_generic(
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

    def _subtract_generic(
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
            self = self._subtract_generic(u_seconds=u_seconds)

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
            self = self._subtract_generic(m_seconds=m_seconds)

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
            self = self._subtract_generic(seconds=seconds)

        var min_sec = Int64(self.calendar.min_second)
        var s = Int64(self.dt.second) - Int64(seconds)
        if s >= min_sec:
            self.dt.second = UInt8(s)
        else:
            self = self._subtract_generic(minutes=1)

            var delta = UInt64((Int64(min_sec) - 1) - s)
            var max_val = UInt64(
                self.calendar.max_possible_second
                + UInt8(self.calendar.min_second == 0)
            )
            if delta >= max_val:
                var seconds_before = self.calendar.to_delta_since_epoch[
                    SITimeUnit.SECONDS
                ](self.dt)
                self = self._subtract_generic(minutes=delta // max_val)
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
                self = self._subtract_generic(minutes=1)
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
            self = self._subtract_generic(hours=hours)

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
            self = self._subtract_generic(days=days)

        var min_day = Int64(self.calendar.min_day)
        var d = Int64(self.dt.day) - Int64(days)
        if d >= min_day:
            self.dt.day = UInt8(d)
        else:
            self.dt.day = self.calendar.min_day
            self = self._subtract_generic(months=1)

            var delta = UInt64((min_day - 1) - d)
            var max_val = UInt64(
                self.calendar.max_possible_days_in_month
                + UInt8(self.calendar.min_day == 0)
            )
            if delta >= max_val:
                var days_before = self.calendar.days_since_epoch(self.dt)
                self = self._subtract_generic(months=delta // max_val)
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
                self = self._subtract_generic(months=1)
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
            self = self._subtract_generic(years=years)

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

        return self._add_generic(days=0)  #  to correct days and months

    def _subtract_gregorian(
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
        var sub_ns = (
            n_seconds % 1_000_000_000
            + (u_seconds % 1_000_000) * 1_000
            + (m_seconds % 1_000) * 1_000_000
        )
        var sub_s_from_ns = (
            n_seconds // 1_000_000_000
            + u_seconds // 1_000_000
            + m_seconds // 1_000
            + sub_ns // 1_000_000_000
        )
        var final_sub_ns = sub_ns % 1_000_000_000

        var current_ns = (
            UInt64(self.dt.m_second) * 1_000_000
            + UInt64(self.dt.u_second) * 1_000
            + UInt64(self.dt.n_second)
        )

        var ns_borrow = UInt64(0)
        if current_ns < final_sub_ns:
            ns_borrow = 1
            current_ns += 1_000_000_000

        var final_ns = current_ns - final_sub_ns
        var total_sub_s = (
            hours * 3600 + minutes * 60 + seconds + sub_s_from_ns + ns_borrow
        )

        var current_days = Int64(
            Self._ymd_to_days(self.dt.year, self.dt.month, self.dt.day)
        )
        var target_epoch_day_signed = current_days - Int64(days)

        comptime min_y_days = Int64(
            Self._ymd_to_days(Self.calendar.min_year, 1, 1)
        )
        comptime max_y_days = Int64(Self._ymd_to_days(9999, 12, 31))

        if target_epoch_day_signed < min_y_days:
            comptime cal_total_days = max_y_days - min_y_days + 1
            var delta_days = min_y_days - 1 - target_epoch_day_signed
            target_epoch_day_signed = max_y_days - (delta_days % cal_total_days)

        var target_epoch_day = UInt64(target_epoch_day_signed)
        var f_y, f_m, f_d = Self._days_to_ymd(target_epoch_day)

        var y_int = Int64(f_y) - Int64(years)
        var m_temp = UInt64(f_m) - 1

        if months > m_temp:
            var diff = months - m_temp
            var years_to_sub = (diff // 12) + UInt64(diff % 12 != 0)
            y_int -= Int64(years_to_sub)
            m_temp = 12 - (diff % 12)
            if m_temp == 12:
                m_temp = 0
        else:
            m_temp -= months

        comptime min_y = Int64(Self.calendar.min_year)
        if y_int < min_y:
            comptime max_val = Int64(9999) + Int64(min_y == 0)
            var delta = (min_y - 1) - y_int
            y_int = Int64(9999) - (delta % max_val)

        f_y = UInt16(y_int)
        f_m = UInt8(m_temp + 1)

        var start_linear_s = Self.calendar.to_delta_since_epoch[
            SITimeUnit.SECONDS, DType.int64
        ]({f_y, f_m, f_d, self.dt.hour, self.dt.minute, self.dt.second})
        var target_linear_s = start_linear_s - Int64(total_sub_s)

        if target_linear_s < 0:
            var cal_s = Self.calendar.to_delta_since_epoch[
                SITimeUnit.SECONDS, DType.int64
            ]({9999, 12, 31, 23, 59, 59})
            var cal_total_s = cal_s + 1

            var delta_s = -target_linear_s
            target_linear_s = cal_total_s - 1 - ((delta_s - 1) % cal_total_s)

        var est_epoch_day = UInt32(target_linear_s // 86400)
        var est_y, est_m, est_d = Self._from_days_since_epoch(est_epoch_day)
        var est_linear = Self.calendar.to_delta_since_epoch[
            SITimeUnit.SECONDS, DType.int64
        ]({est_y, est_m, est_d})

        if est_linear > target_linear_s:
            est_epoch_day -= 1
            est_y, est_m, est_d = Self._from_days_since_epoch(est_epoch_day)
            est_linear = Self.calendar.to_delta_since_epoch[
                SITimeUnit.SECONDS, DType.int64
            ]({est_y, est_m, est_d})

        self.dt.year = est_y
        self.dt.month = est_m
        self.dt.day = est_d

        var rem_s = UInt64(target_linear_s - est_linear)
        if rem_s < 86400:
            self.dt.hour = UInt8(rem_s // 3600)
            self.dt.minute = UInt8((rem_s % 3600) // 60)
            self.dt.second = UInt8(rem_s % 60)
        else:
            self.dt.hour = 23
            self.dt.minute = 59
            self.dt.second = UInt8(59 + (rem_s - 86399))

        self.dt.m_second = UInt16(final_ns // 1_000_000)
        self.dt.u_second = UInt16((final_ns % 1_000_000) // 1_000)
        self.dt.n_second = UInt16(final_ns % 1_000)

        return self

    @always_inline
    def add(var self, other: TimeDelta) -> Self:
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
        unit: SITimeUnit = SITimeUnit.SECONDS, dtype: DType = DType.uint64
    ](var self, other: Self) -> TimeDelta[
        unit, dtype
    ] where dtype.is_unsigned():
        var s = self.calendar.to_delta_since_epoch[unit, dtype](self.dt)
        var o = other.calendar.to_delta_since_epoch[unit, dtype](other.dt)
        return {(s - o) if self >= other else (o - s)}

    def to_calendar[cal: Calendar](self) -> _TzNaiveDateTime[cal]:
        comptime if Self.calendar() == cal():
            return rebind[_TzNaiveDateTime[cal]](self)
        elif Self.calendar._is_gregorian_family and cal._is_gregorian_family:
            comptime if Self.calendar.includes_leapsecs and (
                cal.includes_leapsecs
            ):
                return _TzNaiveDateTime[cal](self.dt)
            elif Self.calendar.includes_leapsecs:
                var leapsecs = UInt64(
                    self.calendar.leapsecs_since_epoch(self.dt)
                )
                return _TzNaiveDateTime[cal](self.dt).add(seconds=leapsecs)
            else:
                var leapsecs = UInt64(cal.leapsecs_since_epoch(self.dt))
                return _TzNaiveDateTime[cal](self.dt).subtract(seconds=leapsecs)

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
