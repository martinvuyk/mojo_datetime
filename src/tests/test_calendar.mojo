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

from std.testing import (
    assert_equal,
    assert_not_equal,
    assert_false,
    assert_raises,
    assert_true,
    TestSuite,
)

from mojo_datetime.calendar import (
    CalendarHashes,
    Calendar,
    Gregorian,
    UTCFastCal,
    PythonCalendar,
    UTCCalendar,
    _NaiveDateTime,
    SITimeUnit,
    ISOCalendar,
)


def test_calendar_hashes() raises:
    comptime calh64 = CalendarHashes.UINT64
    comptime calh32 = CalendarHashes.UINT32
    comptime calh16 = CalendarHashes.UINT16
    comptime calh8 = CalendarHashes.UINT8

    comptime greg = Gregorian[]
    d = _NaiveDateTime(9999, 12, 31, 23, 59, 59, 999, 999, 999)
    assert_not_equal(d, greg.from_hash(greg.hash[calh64](d)))
    d.n_second = 0
    assert_equal(d, greg.from_hash(greg.hash[calh64](d)))
    d = _NaiveDateTime(4095, 12, 31, 0, 0, 0, 0, 0)
    assert_equal(d, greg.from_hash(greg.hash[calh32](d)))

    comptime utcfast = UTCFastCal
    d = _NaiveDateTime(9999, 12, 31, 23, 59, 59, 999, 0)
    assert_equal(d, utcfast.from_hash(utcfast.hash[calh64](d)))
    d = _NaiveDateTime(4095, 12, 31, 23, 59, 0, 0, 0)
    assert_equal(d, utcfast.from_hash(utcfast.hash[calh32](d)))
    d = _NaiveDateTime(3, 12, 31, 23, 0, 0, 0, 0)
    assert_equal(d, utcfast.from_hash(utcfast.hash[calh16](d)))
    d = _NaiveDateTime(0, 0, 6, 23, 0, 0, 0, 0)
    assert_equal(d, utcfast.from_hash(utcfast.hash[calh8](d)))


def test_python_calendar() raises:
    comptime cal = PythonCalendar

    dt_0 = _NaiveDateTime(2024, 12, 31, 3, 4, 5, 6, 7, 8)
    dt_1 = _NaiveDateTime(2025, 1, 1, 3, 4, 5, 6, 7, 8)
    assert_equal(cal.leapdays_since_epoch(dt_0), cal.leapdays_since_epoch(dt_1))
    assert_equal(cal.days_since_epoch(dt_0), cal.days_since_epoch(dt_1) - 1)

    assert_equal(3, Int(cal.day_of_week({2023, 6, 15})))
    assert_equal(5, Int(cal.day_of_week({2024, 6, 15})))
    assert_equal(166, Int(cal.day_of_year({2023, 6, 15})))
    assert_equal(167, Int(cal.day_of_year({2024, 6, 15})))
    assert_equal(365, Int(cal.day_of_year({2023, 12, 31})))
    assert_equal(366, Int(cal.day_of_year({2024, 12, 31})))

    for i in range(UInt16(1), UInt16(3_000)):
        if i % 4 == 0 and (i % 100 != 0 or i % 400 == 0):
            assert_true(cal.is_leapyear(i))
            assert_equal(29, Int(cal.max_days_in_month({i, 2})))
        else:
            assert_false(cal.is_leapyear(i))
            assert_equal(28, Int(cal.max_days_in_month({i, 2})))

    assert_equal(27, Int(cal.leapsecs_since_epoch({2017, 1, 2})))
    var first_day, days_in_month = cal.month_range({2023, 2})
    assert_equal(2, Int(first_day))
    assert_equal(28, Int(days_in_month))
    first_day, days_in_month = cal.month_range({2024, 2})
    assert_equal(3, Int(first_day))
    assert_equal(29, Int(days_in_month))
    assert_equal(60, Int(cal.max_second({1972, 6, 30, 23, 59})))
    assert_equal(60, Int(cal.max_second({1972, 12, 31, 23, 59})))
    assert_equal(60, Int(cal.max_second({1973, 12, 31, 23, 59})))
    assert_equal(60, Int(cal.max_second({1974, 12, 31, 23, 59})))
    assert_equal(60, Int(cal.max_second({1975, 12, 31, 23, 59})))
    assert_equal(60, Int(cal.max_second({1976, 12, 31, 23, 59})))
    assert_equal(60, Int(cal.max_second({1977, 12, 31, 23, 59})))
    assert_equal(60, Int(cal.max_second({1978, 12, 31, 23, 59})))
    assert_equal(60, Int(cal.max_second({1979, 12, 31, 23, 59})))
    assert_equal(60, Int(cal.max_second({1981, 6, 30, 23, 59})))
    assert_equal(60, Int(cal.max_second({1982, 6, 30, 23, 59})))
    assert_equal(60, Int(cal.max_second({1983, 6, 30, 23, 59})))
    assert_equal(60, Int(cal.max_second({1985, 6, 30, 23, 59})))
    assert_equal(60, Int(cal.max_second({1987, 12, 31, 23, 59})))
    assert_equal(60, Int(cal.max_second({1989, 12, 31, 23, 59})))
    assert_equal(60, Int(cal.max_second({1990, 12, 31, 23, 59})))
    assert_equal(60, Int(cal.max_second({1992, 6, 30, 23, 59})))
    assert_equal(60, Int(cal.max_second({1993, 6, 30, 23, 59})))
    assert_equal(60, Int(cal.max_second({1994, 6, 30, 23, 59})))
    assert_equal(60, Int(cal.max_second({1995, 12, 31, 23, 59})))
    assert_equal(60, Int(cal.max_second({1997, 6, 30, 23, 59})))
    assert_equal(60, Int(cal.max_second({1998, 12, 31, 23, 59})))
    assert_equal(60, Int(cal.max_second({2005, 12, 31, 23, 59})))
    assert_equal(60, Int(cal.max_second({2008, 12, 31, 23, 59})))
    assert_equal(60, Int(cal.max_second({2012, 6, 30, 23, 59})))
    assert_equal(60, Int(cal.max_second({2015, 6, 30, 23, 59})))
    assert_equal(60, Int(cal.max_second({2016, 12, 31, 23, 59})))
    assert_equal(
        UInt64(120),
        cal.to_delta_since_epoch[SITimeUnit.SECONDS]({1, 1, 1, 0, 2, 0}),
    )
    assert_equal(
        UInt64(120 * 1_000),
        cal.to_delta_since_epoch[SITimeUnit.MILLISECONDS](
            {1, 1, 1, 0, 2, 0, 0}
        ),
    )
    assert_equal(
        UInt64(120 * (10**9)),
        cal.to_delta_since_epoch[SITimeUnit.NANOSECONDS](
            {1, 1, 1, 0, 2, 0, 0, 0, 0}
        ),
    )
    d1 = cal.to_delta_since_epoch[SITimeUnit.SECONDS]({2024, 1, 1, 0, 2, 0})
    d2 = cal.to_delta_since_epoch[SITimeUnit.SECONDS]({2024, 1, 1, 0, 0, 0})
    assert_equal(120, Int(d1 - d2))
    d1 = cal.to_delta_since_epoch[SITimeUnit.MILLISECONDS](
        {2024, 1, 1, 0, 2, 0, 0}
    )
    d2 = cal.to_delta_since_epoch[SITimeUnit.MILLISECONDS](
        {2024, 1, 1, 0, 0, 0, 0}
    )
    assert_equal(120 * 1_000, Int(d1 - d2))
    d1 = cal.to_delta_since_epoch[SITimeUnit.NANOSECONDS](
        {500, 1, 1, 0, 2, 0, 0, 0, 0}
    )
    d2 = cal.to_delta_since_epoch[SITimeUnit.NANOSECONDS](
        {500, 1, 1, 0, 0, 0, 0, 0, 0}
    )
    assert_equal(Int(120 * (10**9)), Int(d1 - d2))

    comptime day_to_sec: UInt64 = 24 * 60 * 60
    comptime sec_to_nano: UInt64 = 1_000_000_000

    dt_0 = _NaiveDateTime(1, 1, 1, 0, 0, 0, 0, 0, 0)
    dt_1 = _NaiveDateTime(1, 1, 2, 0, 0, 0, 0, 0, 0)
    d1 = cal.to_delta_since_epoch[SITimeUnit.DAYS](dt_0)
    assert_equal(UInt64(0), d1)
    d2 = cal.to_delta_since_epoch[SITimeUnit.DAYS](dt_1)
    assert_equal(UInt64(1), d2 - d1)

    d1 = cal.to_delta_since_epoch[SITimeUnit.HOURS](dt_0)
    assert_equal(UInt64(0), d1)
    d2 = cal.to_delta_since_epoch[SITimeUnit.HOURS](dt_1)
    assert_equal(UInt64(24), d2 - d1)
    d1 = cal.to_delta_since_epoch[SITimeUnit.SECONDS](dt_0)
    assert_equal(UInt64(0), d1)
    d2 = cal.to_delta_since_epoch[SITimeUnit.SECONDS](dt_1)
    assert_equal(day_to_sec, d2 - d1)
    d1 = cal.to_delta_since_epoch[SITimeUnit.MILLISECONDS](dt_0)
    assert_equal(UInt64(0), d1)
    d2 = cal.to_delta_since_epoch[SITimeUnit.MILLISECONDS](dt_1)
    assert_equal(day_to_sec * 1_000, d2 - d1)
    d1 = cal.to_delta_since_epoch[SITimeUnit.MICROSECONDS](dt_0)
    assert_equal(UInt64(0), d1)
    d2 = cal.to_delta_since_epoch[SITimeUnit.MICROSECONDS](dt_1)
    assert_equal(day_to_sec * 10**6, d2 - d1)
    d1 = cal.to_delta_since_epoch[SITimeUnit.NANOSECONDS](dt_0)
    assert_equal(UInt64(0), d1)
    d2 = cal.to_delta_since_epoch[SITimeUnit.NANOSECONDS](dt_1)
    assert_equal(day_to_sec * 10**9, d2 - d1)

    d1 = cal.to_delta_since_epoch[SITimeUnit.SECONDS]({2024, 12, 31, 3, 4, 5})
    d2 = cal.to_delta_since_epoch[SITimeUnit.SECONDS]({2025, 1, 1, 3, 4, 5})
    assert_equal(1 * day_to_sec, d2 - d1)
    d1 = cal.to_delta_since_epoch[SITimeUnit.MILLISECONDS](
        {2024, 12, 31, 3, 4, 5, 6}
    )
    d2 = cal.to_delta_since_epoch[SITimeUnit.MILLISECONDS](
        {2025, 1, 1, 3, 4, 5, 6}
    )
    assert_equal(1 * day_to_sec * 1_000, d2 - d1)
    d1 = cal.to_delta_since_epoch[SITimeUnit.NANOSECONDS](
        {500, 12, 31, 3, 4, 5, 6, 7, 8}
    )
    d2 = cal.to_delta_since_epoch[SITimeUnit.NANOSECONDS](
        {501, 1, 1, 3, 4, 5, 6, 7, 8}
    )
    assert_equal(1 * day_to_sec * sec_to_nano, d2 - d1)


def test_gregorian_utc_calendar() raises:
    comptime cal = UTCCalendar

    dt_0 = _NaiveDateTime(2024, 12, 31, 3, 4, 5, 6, 7, 8)
    dt_1 = _NaiveDateTime(2025, 1, 1, 3, 4, 5, 6, 7, 8)
    assert_equal(cal.leapdays_since_epoch(dt_0), cal.leapdays_since_epoch(dt_1))
    assert_equal(cal.days_since_epoch(dt_0), cal.days_since_epoch(dt_1) - 1)

    assert_equal(3, Int(cal.day_of_week({2023, 6, 15})))
    assert_equal(5, Int(cal.day_of_week({2024, 6, 15})))
    assert_equal(166, Int(cal.day_of_year({2023, 6, 15})))
    assert_equal(167, Int(cal.day_of_year({2024, 6, 15})))
    assert_equal(27, Int(cal.leapsecs_since_epoch({2017, 1, 2})))
    var first_day, days_in_month = cal.month_range({2023, 2})
    assert_equal(2, Int(first_day))
    assert_equal(28, Int(days_in_month))
    first_day, days_in_month = cal.month_range({2024, 2})
    assert_equal(3, Int(first_day))
    assert_equal(29, Int(days_in_month))
    assert_equal(
        UInt64(120),
        cal.to_delta_since_epoch[SITimeUnit.SECONDS]({1970, 1, 1, 0, 2, 0}),
    )
    assert_equal(
        UInt64(120 * 1_000),
        cal.to_delta_since_epoch[SITimeUnit.MILLISECONDS](
            {1970, 1, 1, 0, 2, 0, 0}
        ),
    )
    assert_equal(
        UInt64(120 * (10**9)),
        cal.to_delta_since_epoch[SITimeUnit.NANOSECONDS](
            {1970, 1, 1, 0, 2, 0, 0, 0, 0}
        ),
    )
    d1 = cal.to_delta_since_epoch[SITimeUnit.SECONDS]({2024, 1, 1, 0, 2, 0})
    d2 = cal.to_delta_since_epoch[SITimeUnit.SECONDS]({2024, 1, 1, 0, 0, 0})
    assert_equal(UInt64(120), d1 - d2)
    d1 = cal.to_delta_since_epoch[SITimeUnit.MILLISECONDS](
        {2024, 1, 1, 0, 2, 0, 0}
    )
    d2 = cal.to_delta_since_epoch[SITimeUnit.MILLISECONDS](
        {2024, 1, 1, 0, 0, 0, 0}
    )
    assert_equal(UInt64(120 * 1_000), d1 - d2)
    d1 = cal.to_delta_since_epoch[SITimeUnit.NANOSECONDS](
        {2024, 1, 1, 0, 2, 0, 0, 0, 0}
    )
    d2 = cal.to_delta_since_epoch[SITimeUnit.NANOSECONDS](
        {2024, 1, 1, 0, 0, 0, 0, 0, 0}
    )
    assert_equal(UInt64(Int(120 * (10**9))), d1 - d2)

    comptime day_to_sec: UInt64 = 24 * 60 * 60
    comptime sec_to_nano: UInt64 = 1_000_000_000

    dt_0 = _NaiveDateTime(1970, 1, 1, 0, 0, 0, 0, 0, 0)
    dt_1 = _NaiveDateTime(1970, 1, 2, 0, 0, 0, 0, 0, 0)
    d1 = cal.to_delta_since_epoch[SITimeUnit.DAYS](dt_0)
    assert_equal(UInt64(0), d1)
    d2 = cal.to_delta_since_epoch[SITimeUnit.DAYS](dt_1)
    assert_equal(UInt64(1), d2 - d1)
    d1 = cal.to_delta_since_epoch[SITimeUnit.HOURS](dt_0)
    assert_equal(UInt64(0), d1)
    d2 = cal.to_delta_since_epoch[SITimeUnit.HOURS](dt_1)
    assert_equal(UInt64(24), d2 - d1)
    d1 = cal.to_delta_since_epoch[SITimeUnit.SECONDS](dt_0)
    assert_equal(UInt64(0), d1)
    d2 = cal.to_delta_since_epoch[SITimeUnit.SECONDS](dt_1)
    assert_equal(day_to_sec, d2 - d1)
    d1 = cal.to_delta_since_epoch[SITimeUnit.MILLISECONDS](dt_0)
    assert_equal(UInt64(0), d1)
    d2 = cal.to_delta_since_epoch[SITimeUnit.MILLISECONDS](dt_1)
    assert_equal(day_to_sec * 1_000, d2 - d1)
    d1 = cal.to_delta_since_epoch[SITimeUnit.MICROSECONDS](dt_0)
    assert_equal(UInt64(0), d1)
    d2 = cal.to_delta_since_epoch[SITimeUnit.MICROSECONDS](dt_1)
    assert_equal(day_to_sec * 10**6, d2 - d1)
    d1 = cal.to_delta_since_epoch[SITimeUnit.NANOSECONDS](dt_0)
    assert_equal(UInt64(0), d1)
    d2 = cal.to_delta_since_epoch[SITimeUnit.NANOSECONDS](dt_1)
    assert_equal(day_to_sec * 10**9, d2 - d1)

    dt_0 = _NaiveDateTime(2024, 12, 31, 3, 4, 5, 6, 7, 8)
    dt_1 = _NaiveDateTime(2025, 1, 1, 3, 4, 5, 6, 7, 8)
    d1 = cal.to_delta_since_epoch[SITimeUnit.DAYS](dt_0)
    d2 = cal.to_delta_since_epoch[SITimeUnit.DAYS](dt_1)
    assert_equal(UInt64(1), d2 - d1)
    d1 = cal.to_delta_since_epoch[SITimeUnit.HOURS](dt_0)
    d2 = cal.to_delta_since_epoch[SITimeUnit.HOURS](dt_1)
    assert_equal(UInt64(24), d2 - d1)
    d1 = cal.to_delta_since_epoch[SITimeUnit.SECONDS](dt_0)
    d2 = cal.to_delta_since_epoch[SITimeUnit.SECONDS](dt_1)
    assert_equal(day_to_sec, d2 - d1)
    d1 = cal.to_delta_since_epoch[SITimeUnit.MILLISECONDS](dt_0)
    d2 = cal.to_delta_since_epoch[SITimeUnit.MILLISECONDS](dt_1)
    assert_equal(day_to_sec * 1_000, d2 - d1)
    d1 = cal.to_delta_since_epoch[SITimeUnit.MICROSECONDS](dt_0)
    d2 = cal.to_delta_since_epoch[SITimeUnit.MICROSECONDS](dt_1)
    assert_equal(day_to_sec * 10**6, d2 - d1)
    d1 = cal.to_delta_since_epoch[SITimeUnit.NANOSECONDS](dt_0)
    d2 = cal.to_delta_since_epoch[SITimeUnit.NANOSECONDS](dt_1)
    assert_equal(day_to_sec * 10**9, d2 - d1)


def test_utcfast_calendar() raises:
    comptime cal = UTCFastCal
    assert_equal(3, Int(cal.day_of_week({2023, 6, 15})))
    assert_equal(5, Int(cal.day_of_week({2024, 6, 15})))
    assert_equal(166, Int(cal.day_of_year({2023, 6, 15})))
    assert_equal(167, Int(cal.day_of_year({2024, 6, 15})))
    assert_equal(365, Int(cal.day_of_year({2023, 12, 31})))
    assert_equal(366, Int(cal.day_of_year({2024, 12, 31})))

    assert_equal(0, Int(cal.leapsecs_since_epoch({2017, 1, 2})))
    var first_day, days_in_month = cal.month_range({2023, 2})
    assert_equal(2, Int(first_day))
    assert_equal(28, Int(days_in_month))
    first_day, days_in_month = cal.month_range({2024, 2})
    assert_equal(3, Int(first_day))
    assert_equal(29, Int(days_in_month))
    assert_equal(
        UInt64(120),
        cal.to_delta_since_epoch[SITimeUnit.SECONDS]({1970, 1, 1, 0, 2, 0}),
    )
    assert_equal(
        UInt64(120 * 1_000),
        cal.to_delta_since_epoch[SITimeUnit.MILLISECONDS](
            {1970, 1, 1, 0, 2, 0, 0}
        ),
    )
    assert_equal(
        UInt64(120 * (10**9)),
        cal.to_delta_since_epoch[SITimeUnit.NANOSECONDS](
            {1970, 1, 1, 0, 2, 0, 0, 0, 0}
        ),
    )
    d1 = cal.to_delta_since_epoch[SITimeUnit.SECONDS]({2024, 1, 1, 0, 2, 0})
    d2 = cal.to_delta_since_epoch[SITimeUnit.SECONDS]({2024, 1, 1, 0, 0, 0})
    assert_equal(120, Int(d1 - d2))
    d1 = cal.to_delta_since_epoch[SITimeUnit.MILLISECONDS](
        {2024, 1, 1, 0, 2, 0, 0}
    )
    d2 = cal.to_delta_since_epoch[SITimeUnit.MILLISECONDS](
        {2024, 1, 1, 0, 0, 0, 0}
    )
    assert_equal(120 * 1_000, Int(d1 - d2))
    d1 = cal.to_delta_since_epoch[SITimeUnit.NANOSECONDS](
        {2024, 1, 1, 0, 2, 0, 0, 0, 0}
    )
    d2 = cal.to_delta_since_epoch[SITimeUnit.NANOSECONDS](
        {2024, 1, 1, 0, 0, 0, 0, 0, 0}
    )
    assert_equal(Int(120 * (10**9)), Int(d1 - d2))

    comptime day_to_sec: UInt64 = 24 * 60 * 60
    comptime sec_to_nano: UInt64 = 1_000_000_000
    d1 = cal.to_delta_since_epoch[SITimeUnit.SECONDS]({2024, 12, 31, 3, 4, 5})
    d2 = cal.to_delta_since_epoch[SITimeUnit.SECONDS]({2025, 1, 1, 3, 4, 5})
    assert_equal(1 * day_to_sec, d2 - d1)
    d1 = cal.to_delta_since_epoch[SITimeUnit.MILLISECONDS](
        {2024, 12, 31, 3, 4, 5, 6}
    )
    d2 = cal.to_delta_since_epoch[SITimeUnit.MILLISECONDS](
        {2025, 1, 1, 3, 4, 5, 6}
    )
    assert_equal(1 * day_to_sec * 1_000, d2 - d1)
    d1 = cal.to_delta_since_epoch[SITimeUnit.NANOSECONDS](
        {2024, 12, 31, 3, 4, 5, 6, 7, 8}
    )
    d2 = cal.to_delta_since_epoch[SITimeUnit.NANOSECONDS](
        {2025, 1, 1, 3, 4, 5, 6, 7, 8}
    )
    assert_equal(1 * day_to_sec * sec_to_nano, d2 - d1)


def test_iso_calendar() raises:
    comptime iso = ISOCalendar[]

    # Monday, Jan 2, 2023
    assert_equal(iso.day_of_week({2023, 1, 2}), 1)
    # Wednesday, Jan 1, 2025
    assert_equal(iso.day_of_week({2025, 1, 1}), 3)
    # Thursday, Dec 31, 2026
    assert_equal(iso.day_of_week({2026, 12, 31}), 4)
    # Sunday, Jan 1, 2023
    assert_equal(iso.day_of_week({2023, 1, 1}), 7)

    # Jan 1, 2023 is a Sunday. The first Thursday of 2023 is Jan 5th.
    # Therefore, Jan 1 belongs to the last week of 2022 (Week 52).
    assert_equal(iso.week_of_year({2023, 1, 1}), 52)
    # Start of year (Monday, Jan 2, 2023 is the start of Week 1)
    assert_equal(iso.week_of_year({2023, 1, 2}), 1)

    # Year starts exactly on Monday (Jan 1, 2024)
    assert_equal(iso.week_of_year({2024, 1, 1}), 1)

    # Jan 1, 2025 is a Wednesday. The first Thursday is Jan 2.
    # So Dec 31, 2024 is actually Week 1 of 2025.
    assert_equal(iso.week_of_year({2024, 12, 31}), 1)

    # Long year (53 weeks)
    # 2026 ends on a Thursday (Dec 31).
    # The first Thursday of 2027 is Jan 7.
    # The week starting Monday Dec 28, 2026 contains Dec 31 (Thu), Jan 1 (Fri),
    # Jan 2 (Sat), and Jan 3 (Sun). This is Week 53 of 2026.
    assert_equal(iso.week_of_year({2026, 12, 31}), 53)
    assert_equal(iso.week_of_year({2027, 1, 3}), 53)

    # Monday, Jan 4, 2027 is the start of Week 1 of 2027.
    assert_equal(iso.week_of_year({2027, 1, 4}), 1)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
