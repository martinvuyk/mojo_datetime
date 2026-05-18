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

from mojo_datetime.calendar import PythonCalendar
from mojo_datetime.timezone import TimeZone
from mojo_datetime._tz_naive_datetime import _TzNaiveDateTime


def test_tz() raises:
    var tz0 = TimeZone("Etc/UTC")
    var tz_1 = TimeZone("Etc/UTC+1")
    var tz_2 = TimeZone("Etc/UTC+2")
    var tz_3 = TimeZone("Etc/UTC+3")
    var tz1_ = TimeZone("Etc/UTC-1")
    var tz2_ = TimeZone("Etc/UTC-2")
    var tz3_ = TimeZone("Etc/UTC-3")
    assert_true(tz0 == TimeZone())
    assert_true(tz1_ != tz_1)
    assert_true(tz2_ != tz_2)
    assert_true(tz3_ != tz_3)
    var d = _TzNaiveDateTime[PythonCalendar]({1970, 1, 1, 0, 0, 0})
    var tz0_of = tz0.zone_info.offset_at_utc_time(d)
    var tz_1_of = tz_1.zone_info.offset_at_utc_time(d)
    var tz_2_of = tz_2.zone_info.offset_at_utc_time(d)
    var tz_3_of = tz_3.zone_info.offset_at_utc_time(d)
    var tz1__of = tz1_.zone_info.offset_at_utc_time(d)
    var tz2__of = tz2_.zone_info.offset_at_utc_time(d)
    var tz3__of = tz3_.zone_info.offset_at_utc_time(d)
    assert_equal(tz0_of.hours, 0)
    assert_equal(tz0_of.minutes, 0)
    assert_equal(tz0_of.is_east_utc, True)
    assert_equal(tz_1_of.hours, 1)
    assert_equal(tz_1_of.minutes, 0)
    assert_equal(tz_1_of.is_east_utc, True)
    assert_equal(tz_2_of.hours, 2)
    assert_equal(tz_2_of.minutes, 0)
    assert_equal(tz_2_of.is_east_utc, True)
    assert_equal(tz_3_of.hours, 3)
    assert_equal(tz_3_of.minutes, 0)
    assert_equal(tz_3_of.is_east_utc, True)
    assert_equal(tz1__of.hours, 1)
    assert_equal(tz1__of.minutes, 0)
    assert_equal(tz1__of.is_east_utc, False)
    assert_equal(tz2__of.hours, 2)
    assert_equal(tz2__of.minutes, 0)
    assert_equal(tz2__of.is_east_utc, False)
    assert_equal(tz3__of.hours, 3)
    assert_equal(tz3__of.minutes, 0)
    assert_equal(tz3__of.is_east_utc, False)


def test_tz_comptime() raises:
    comptime tz0 = TimeZone("Etc/UTC")
    comptime tz0_2 = TimeZone()
    assert_true(materialize[tz0]() == materialize[tz0_2]())
    assert_equal(materialize[tz0](), materialize[tz0_2]())


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
