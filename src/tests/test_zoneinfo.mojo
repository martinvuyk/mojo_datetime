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

from mojo_datetime._tz_naive_datetime import _TzNaiveDateTime
from mojo_datetime.calendar import PythonCalendar, SITimeUnit
from mojo_datetime.timedelta import TimeDelta
from mojo_datetime.zoneinfo import Offset, TzDT, ZoneInfo, TRef


def test_offset() raises:
    var minutes_arr = [UInt8(0), UInt8(30), UInt8(45)]
    for is_east_utc_n in range(2):
        var is_east_utc = Bool(is_east_utc_n)
        for minutes in minutes_arr:
            for of_hour in range(UInt8(16)):
                var of = Offset(of_hour, minutes, is_east_utc)
                assert_equal(of.hours, of_hour)
                assert_equal(of.minutes, minutes)
                assert_equal(of.is_east_utc, is_east_utc)
                var new_of = Offset(from_hash=of.hash())
                assert_equal(new_of.hours, of.hours)
                assert_equal(new_of.minutes, of.minutes)
                assert_equal(new_of.is_east_utc, of.is_east_utc)
                assert_equal(new_of, of)


def test_tzdst() raises:
    for month in range(UInt8(1), UInt8(12 + 1)):
        for dow in range(UInt8(7)):
            for from_end_of_month_n in range(2):
                var from_end_of_month = Bool(from_end_of_month_n)
                for first_week_n in range(2):
                    var first_week = Bool(first_week_n)
                    for hour in range(UInt8(24)):
                        var tzdt = TzDT(
                            month,
                            dow,
                            from_end_of_month,
                            first_week,
                            hour,
                            TRef.UTC,
                        )
                        assert_equal(tzdt.month, month)
                        assert_equal(tzdt.day_of_week, dow)
                        assert_equal(tzdt.from_end_of_month, from_end_of_month)
                        assert_equal(tzdt.first_week, first_week)
                        assert_equal(tzdt.hour, hour)
                        assert_equal(tzdt.t_ref, TRef.UTC)
                        var new_tzdt = TzDT(from_hash=tzdt.hash())
                        assert_equal(new_tzdt.month, tzdt.month)
                        assert_equal(new_tzdt.day_of_week, tzdt.day_of_week)
                        assert_equal(
                            new_tzdt.from_end_of_month, tzdt.from_end_of_month
                        )
                        assert_equal(new_tzdt.first_week, tzdt.first_week)
                        assert_equal(new_tzdt.hour, tzdt.hour)
                        assert_equal(new_tzdt.t_ref, tzdt.t_ref)
                        assert_equal(new_tzdt, tzdt)


def test_zone_info() raises:
    var minutes_arr = [UInt8(0), UInt8(30), UInt8(45)]
    for month in range(UInt8(1), UInt8(12 + 1)):
        for dow in range(UInt8(7)):
            for from_end_of_month_n in range(2):
                var from_end_of_month = Bool(from_end_of_month_n)
                for first_week_n in range(2):
                    var first_week = Bool(first_week_n)
                    for is_east_utc_n in range(2):
                        var is_east_utc = Bool(is_east_utc_n)
                        for minutes in minutes_arr:
                            for of_hour in range(UInt8(16)):
                                var of = Offset(of_hour, minutes, is_east_utc)
                                var of_2 = of + Offset(1, 0, True)
                                for hour in range(UInt8(24)):
                                    var tzdt = TzDT(
                                        month,
                                        dow,
                                        from_end_of_month,
                                        first_week,
                                        hour,
                                        TRef.UTC,
                                    )
                                    var start, end, std, dst = ZoneInfo(
                                        tzdt, tzdt, of
                                    ).parse()
                                    assert_equal(tzdt, start)
                                    assert_equal(tzdt.hash(), start.hash())
                                    assert_equal(tzdt, end)
                                    assert_equal(tzdt.hash(), end.hash())
                                    assert_equal(of, std)
                                    assert_equal(of.hash(), std.hash())
                                    assert_equal(of_2, dst)
                                    assert_equal(of_2.hash(), dst.hash())
                                    start, end, std, dst = ZoneInfo(
                                        tzdt, tzdt, of, of_2
                                    ).parse()
                                    assert_equal(tzdt, start)
                                    assert_equal(tzdt.hash(), start.hash())
                                    assert_equal(tzdt, end)
                                    assert_equal(tzdt.hash(), end.hash())
                                    assert_equal(of, std)
                                    assert_equal(of.hash(), std.hash())
                                    assert_equal(of_2, dst)
                                    assert_equal(of_2.hash(), dst.hash())


def test_zone_info_transitions() raises:
    @always_inline
    def _test(
        std: Offset,
        from_end_of_month: Bool,
        is_first_week: Bool,
        tref_start: TRef,
        tref_end: TRef,
        month_start: UInt8,
        month_end: UInt8,
        dow: UInt8,
        hour: UInt8,
    ) raises:
        var dst_start = TzDT(
            month_start, dow, from_end_of_month, is_first_week, hour, tref_start
        )
        var dst_end = TzDT(
            month_end, dow, from_end_of_month, is_first_week, hour, tref_end
        )
        var dst = std + Offset(1, 0, True)

        var zi = ZoneInfo(dst_start, dst_end, std, dst)

        var ref_dt = _TzNaiveDateTime[PythonCalendar]({2026, 6, 15, 12, 0, 0})
        var start_utc, end_utc = ZoneInfo._get_datetimes_for_relative_rules(
            ref_dt, dst_start, dst_end, std, dst
        )

        var before_start_utc = start_utc.subtract(seconds=1)
        var after_start_utc = start_utc.add(seconds=1)

        # UTC Validation
        assert_equal(zi.offset_at_utc_time(before_start_utc), std)
        assert_equal(zi.offset_at_utc_time(after_start_utc), dst)

        # Local Validation
        var before_start_local = std.utc_to_local(before_start_utc)
        var after_start_local = dst.utc_to_local(after_start_utc)

        assert_equal(zi.offset_at_local_time(before_start_local), std)
        assert_equal(zi.offset_at_local_time(after_start_local), dst)

        # The gap hour: 30 minutes after local standard time transition bounds.
        # We default to dst if a gap time is requested
        var gap_local = before_start_local.add(minutes=30)
        assert_equal(zi.offset_at_local_time(gap_local), dst)

        var before_end_utc = end_utc.subtract(seconds=1)
        var after_end_utc = end_utc.add(seconds=1)

        # UTC Validation
        assert_equal(zi.offset_at_utc_time(before_end_utc), dst)
        assert_equal(zi.offset_at_utc_time(after_end_utc), std)

        # Local Validation
        var before_end_local = dst.utc_to_local(before_end_utc)
        var after_end_local = std.utc_to_local(after_end_utc)

        # The overlap hour: Time happens twice
        # We default to dst if an overlap time is requested
        assert_equal(zi.offset_at_local_time(before_end_local), dst)
        assert_equal(zi.offset_at_local_time(after_end_local), dst)

        # Once the overlap is fully over
        var fully_after_overlap_local = after_end_local.add(hours=1)
        assert_equal(zi.offset_at_local_time(fully_after_overlap_local), std)

    var minutes_arr = [UInt8(0), UInt8(15), UInt8(30), UInt8(45)]
    var trefs = [TRef.UTC, TRef.STD, TRef.DST]
    for is_east_utc_n in range(2):
        var is_east_utc = Bool(is_east_utc_n)
        for minutes in minutes_arr:
            # 3 hours is enough to test around 0, this is to speed up testing
            for std_hour in range(UInt8(3)):
                var std = Offset(std_hour, minutes, is_east_utc)
                for month_start in range(UInt8(1), UInt8(12 + 1)):
                    for month_end in range(UInt8(1), UInt8(12 + 1)):
                        var d = Int8(month_start) - Int8(month_end)
                        # typically at least 6 months, this is mostly to speed up testing
                        if abs(d) <= 3:
                            continue
                        for hour in range(UInt8(24)):
                            # skipping daylight hours to speed up testing
                            if UInt8(5) <= hour <= 20:
                                continue
                            for from_end_of_month_n in range(2):
                                var from_end_of_month = Bool(
                                    from_end_of_month_n
                                )
                                for is_first_week_n in range(2):
                                    var is_first_week = Bool(is_first_week_n)
                                    for tref_start in trefs:
                                        for tref_end in trefs:
                                            for dow in range(UInt8(7)):
                                                _test(
                                                    std,
                                                    from_end_of_month,
                                                    is_first_week,
                                                    tref_start,
                                                    tref_end,
                                                    month_start,
                                                    month_end,
                                                    dow,
                                                    hour,
                                                )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
