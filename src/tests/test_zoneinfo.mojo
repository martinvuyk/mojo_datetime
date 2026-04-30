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

from mojo_datetime.zoneinfo import Offset, TzDT, ZoneInfo, TRef


def test_offset() raises:
    comptime minutes = SIMD[DType.uint8, 4](0, 30, 45, 0)
    for k in range(2):
        is_east_utc = Bool(k == 0)
        for j in range(3):
            for i in range(UInt8(16)):
                var of = Offset(i, minutes[j], is_east_utc)
                assert_equal(of.hours, i)
                assert_equal(of.minutes, minutes[j])
                assert_equal(of.is_east_utc, is_east_utc)
                var new_of = Offset(from_hash=of.hash())
                assert_equal(new_of.hours, of.hours)
                assert_equal(new_of.minutes, of.minutes)
                assert_equal(new_of.is_east_utc, of.is_east_utc)
                assert_equal(new_of, of)


def test_tzdst() raises:
    comptime hours = SIMD[DType.uint8, 8](20, 21, 22, 23, 0, 1, 2, 3)
    for month in range(UInt8(1), UInt8(12 + 1)):
        for dow in range(UInt8(2)):
            for eomon in range(2):
                for week in range(2):
                    for hour in range(8):
                        var tzdt = TzDT(
                            month,
                            dow,
                            Bool(eomon),
                            Bool(week),
                            hours[hour],
                            TRef.UTC,
                        )
                        assert_equal(tzdt.month, month)
                        assert_equal(tzdt.day_of_week, dow)
                        assert_equal(tzdt.from_end_of_month, Bool(eomon))
                        assert_equal(tzdt.first_week, Bool(week))
                        assert_equal(tzdt.hour, hours[hour])
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
    comptime hours = SIMD[DType.uint8, 8](20, 21, 22, 23, 0, 1, 2, 3)
    comptime minutes = SIMD[DType.uint8, 4](0, 30, 45, 0)
    for month in range(UInt8(1), UInt8(13)):
        for dow in range(UInt8(2)):
            for eomon in range(2):
                for week in range(2):
                    for hour in range(8):
                        for k in range(2):
                            var is_east_utc = Bool(k == 0)
                            for j in range(3):
                                for i in range(UInt8(16)):
                                    var tzdt = TzDT(
                                        month,
                                        dow,
                                        Bool(eomon),
                                        Bool(week),
                                        hours[hour],
                                        TRef.UTC,
                                    )
                                    var of = Offset(i, minutes[j], is_east_utc)
                                    var parsed = ZoneInfo(
                                        tzdt, tzdt, of
                                    ).parse()
                                    assert_equal(tzdt.hash(), parsed[0].hash())
                                    assert_equal(tzdt.hash(), parsed[1].hash())
                                    assert_equal(of.hash(), parsed[2].hash())


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
