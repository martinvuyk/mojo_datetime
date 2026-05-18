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

from mojo_datetime import DateTime, Calendar, IsoFormat, TZ_UTC, TimeDelta
from mojo_datetime.calendar import PythonCalendar, UTCCalendar


def test_example() raises:
    var dt = DateTime(2024, 6, 18, 22, 14, 7)
    assert_equal("2024-06-18T22:14:07+00:00", String(dt))
    var res = String()
    dt.write_to[IsoFormat.HH_MM_SS](res)
    dt = DateTime.parse[IsoFormat.HH_MM_SS](res)
    assert_equal("0001-01-01T22:14:07+00:00", String(dt))

    var dt1 = DateTime["Etc/UTC-4"](2024, 6, 18, hour=0)
    var dt2 = DateTime["Etc/UTC-3"](2024, 6, 18, hour=1)
    assert_equal(dt1.to_utc(), dt2.to_utc())

    # time delta
    assert_equal((dt1 + TimeDelta(hours=4)).replace[tz=TZ_UTC](), dt2.to_utc())

    # using python and unix calendar should have no difference in results
    var dt1_p = DateTime["Etc/UTC-4", PythonCalendar](2024, 6, 18, hour=0)
    var dt2_u = DateTime["Etc/UTC-3", UTCCalendar](2024, 6, 18, hour=1)
    assert_equal(dt1_p.to_calendar[UTCCalendar]().to_utc(), dt2_u.to_utc())

    comptime fstr = "mojo: %Y🔥%m🤯%d"
    res = ""
    var ref1 = DateTime(9, 6, 1)
    ref1.write_to[fstr](res)
    assert_equal("mojo: 0009🔥06🤯01", res)
    assert_equal(ref1, DateTime.parse[fstr](res))

    comptime fstr2 = "%Y-%m-%d %H:%M:%S.%f"
    res = ""
    ref1 = DateTime(2024, 9, 9, 9, 9, 9, 9, 9)
    ref1.write_to[fstr2](res)
    assert_equal("2024-09-09 09:09:09.009009", res)
    assert_equal(ref1, DateTime.parse[fstr2](res))

    dt = DateTime({2026, 4, 28, 15, 30, 0})
    res = ""
    comptime fstr3 = "%a %d %b %Y %H:%M:%S"
    dt.write_to[fstr3](res)
    assert_equal(res, "Tue 28 Apr 2026 15:30:00")
    assert_equal(dt, DateTime.parse[fstr3](res))

    res = ""
    comptime fstr4 = "%A %d %B %Y %I:%M:%S %p"
    dt.write_to[fstr4](res)
    assert_equal(res, "Tuesday 28 April 2026 03:30:00 PM")
    assert_equal(dt, DateTime.parse[fstr4](res))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
