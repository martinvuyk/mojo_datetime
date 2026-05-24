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

from mojo_datetime.datetime import DateTime
from mojo_datetime.timezone import TimeZone, TZ_UTC
from mojo_datetime.timedelta import TimeDelta
from mojo_datetime.calendar import (
    Calendar,
    PythonCalendar,
    UTCCalendar,
    Gregorian,
    UTCFastCal,
)


comptime pycal = PythonCalendar
comptime unixcal = UTCCalendar
comptime tz_0_ = TZ_UTC
comptime tz_1 = TimeZone("Etc/UTC+1")
comptime tz1_ = TimeZone("Etc/UTC-1")


def test_add() raises:
    # using python and unix calendar should have no difference in results
    # test february leapyear
    result = (
        DateTime[tz_0_, pycal](2024, 2, 29) + TimeDelta(days=1)
    ).to_calendar[unixcal]()
    offset_0 = DateTime[tz_0_, unixcal](2024, 3, 1)
    offset_p_1 = DateTime[tz_1, unixcal](2024, 3, 1, hour=1)
    offset_n_1 = DateTime[tz1_, unixcal](2024, 2, 29, hour=23)
    add_seconds = DateTime[tz_0_, unixcal](2024, 2, 29).add(seconds=24 * 3600)
    assert_equal(result, offset_0.to_utc())
    assert_equal(result, offset_p_1.to_utc())
    assert_equal(result, offset_n_1.to_utc())
    assert_equal(result, add_seconds.to_utc())

    # test february not leapyear
    result = (
        DateTime[tz_0_, pycal](2023, 2, 28) + TimeDelta(days=1)
    ).to_calendar[unixcal]()
    offset_0 = DateTime[tz_0_, unixcal](2023, 3, 1)
    offset_p_1 = DateTime[tz_1, unixcal](2023, 3, 1, hour=1)
    offset_n_1 = DateTime[tz1_, unixcal](2023, 2, 28, hour=23)
    add_seconds = DateTime[tz_0_, unixcal](2023, 2, 28).add(seconds=24 * 3600)
    assert_equal(result, offset_0.to_utc())
    assert_equal(result, offset_p_1.to_utc())
    assert_equal(result, offset_n_1.to_utc())
    assert_equal(result, add_seconds.to_utc())

    # test normal month
    result = (
        DateTime[tz_0_, pycal](2024, 5, 31) + TimeDelta(days=1)
    ).to_calendar[unixcal]()
    offset_0 = DateTime[tz_0_, unixcal](2024, 6, 1)
    offset_p_1 = DateTime[tz_1, unixcal](2024, 6, 1, hour=1)
    offset_n_1 = DateTime[tz1_, unixcal](2024, 5, 31, hour=23)
    add_seconds = DateTime[tz_0_, unixcal](2024, 5, 31).add(seconds=24 * 3600)
    assert_equal(result, offset_0.to_utc())
    assert_equal(result, offset_p_1.to_utc())
    assert_equal(result, offset_n_1.to_utc())
    assert_equal(result, add_seconds.to_utc())

    # test december
    result = (
        DateTime[tz_0_, pycal](2024, 12, 31) + TimeDelta(days=1)
    ).to_calendar[unixcal]()
    offset_0 = DateTime[tz_0_, unixcal](2025, 1, 1)
    offset_p_1 = DateTime[tz_1, unixcal](2025, 1, 1, hour=1)
    offset_n_1 = DateTime[tz1_, unixcal](2024, 12, 31, hour=23)
    add_seconds = DateTime[tz_0_, unixcal](2024, 12, 31).add(seconds=24 * 3600)
    assert_equal(result, offset_0.to_utc())
    assert_equal(result, offset_p_1.to_utc())
    assert_equal(result, offset_n_1.to_utc())
    assert_equal(result, add_seconds.to_utc())

    # test year and month add
    result = (
        DateTime[tz_0_, pycal](2022, 6, 1)
        .add(years=2, months=6, days=31)
        .to_calendar[unixcal]()
    )
    offset_0 = DateTime[tz_0_, unixcal](2025, 1, 1)
    offset_p_1 = DateTime[tz_1, unixcal](2025, 1, 1, hour=1)
    offset_n_1 = DateTime[tz1_, unixcal](2024, 12, 31, hour=23)
    add_elements = DateTime[tz_1, unixcal](2022, 6, 1, hour=1).add(
        years=2, months=6, days=31
    )
    assert_equal(result, offset_0.to_utc())
    assert_equal(result, offset_p_1.to_utc())
    assert_equal(result, offset_n_1.to_utc())
    assert_equal(result, add_elements.to_utc())

    # test positive overflow pycal
    result_py = DateTime[tz_0_, pycal](9999, 12, 31) + TimeDelta(days=1)
    assert_equal(result_py, DateTime[tz_0_, pycal](1, 1, 1).to_utc())
    assert_equal(result_py, DateTime[tz_1, pycal](1, 1, 1, hour=1).to_utc())
    assert_equal(
        result_py, DateTime[tz1_, pycal](9999, 12, 31, hour=23).to_utc()
    )
    assert_equal(
        result_py,
        DateTime[tz_0_, pycal](9999, 12, 31).add(seconds=24 * 3600).to_utc(),
    )

    # test positive overflow unixcal
    result = DateTime[tz_0_, unixcal](9999, 12, 31) + TimeDelta(days=1)
    offset_0 = DateTime[tz_0_, unixcal](1970, 1, 1)
    offset_p_1 = DateTime[tz_1, unixcal](1970, 1, 1, hour=1)
    offset_n_1 = DateTime[tz1_, unixcal](9999, 12, 31, hour=23)
    add_seconds = DateTime[tz_0_, unixcal](9999, 12, 31).add(seconds=24 * 3600)
    assert_equal(result, offset_0.to_utc())
    assert_equal(result, offset_p_1.to_utc())
    assert_equal(result, offset_n_1.to_utc())
    assert_equal(result, add_seconds.to_utc())


def test_subtract() raises:
    # using python and unix calendar should have no difference in results
    # test february leapyear
    result = (
        DateTime[tz_0_, pycal](2024, 3, 1) - TimeDelta(days=1)
    ).to_calendar[unixcal]()
    offset_0 = DateTime[tz_0_, unixcal](2024, 2, 29)
    offset_p_1 = DateTime[tz_1, unixcal](2024, 2, 29, hour=1)
    offset_n_1 = DateTime[tz1_, unixcal](2024, 2, 28, hour=23)
    sub_seconds = DateTime[tz_0_, unixcal](2024, 3, 1).subtract(days=1)
    assert_equal(result, offset_0.to_utc())
    assert_equal(result, offset_p_1.to_utc())
    assert_equal(result, offset_n_1.to_utc())
    assert_equal(result, sub_seconds.to_utc())

    # test february not leapyear
    result = (
        DateTime[tz_0_, pycal](2023, 3, 1) - TimeDelta(days=1)
    ).to_calendar[unixcal]()
    offset_0 = DateTime[tz_0_, unixcal](2023, 2, 28)
    offset_p_1 = DateTime[tz_1, unixcal](2023, 2, 28, hour=1)
    offset_n_1 = DateTime[tz1_, unixcal](2023, 2, 27, hour=23)
    sub_seconds = DateTime[tz_0_, unixcal](2023, 3, 1).subtract(days=1)
    assert_equal(result, offset_0.to_utc())
    assert_equal(result, offset_p_1.to_utc())
    assert_equal(result, offset_n_1.to_utc())
    assert_equal(result, sub_seconds.to_utc())

    # test normal month
    result = (
        DateTime[tz_0_, pycal](2024, 6, 1) - TimeDelta(days=1)
    ).to_calendar[unixcal]()
    offset_0 = DateTime[tz_0_, unixcal](2024, 5, 31)
    offset_p_1 = DateTime[tz_1, unixcal](2024, 5, 31, hour=1)
    offset_n_1 = DateTime[tz1_, unixcal](2024, 5, 30, hour=23)
    sub_seconds = DateTime[tz_0_, unixcal](2024, 6, 1).subtract(days=1)
    assert_equal(result, offset_0.to_utc())
    assert_equal(result, offset_p_1.to_utc())
    assert_equal(result, offset_n_1.to_utc())
    assert_equal(result, sub_seconds.to_utc())

    # test december
    result = (
        DateTime[tz_0_, pycal](2025, 1, 1) - TimeDelta(days=1)
    ).to_calendar[unixcal]()
    offset_0 = DateTime[tz_0_, unixcal](2024, 12, 31)
    offset_p_1 = DateTime[tz_1, unixcal](2024, 12, 31, hour=1)
    offset_n_1 = DateTime[tz1_, unixcal](2024, 12, 30, hour=23)
    sub_seconds = DateTime[tz_0_, unixcal](2025, 1, 1).subtract(days=1)
    assert_equal(result, offset_0.to_utc())
    assert_equal(result, offset_p_1.to_utc())
    assert_equal(result, offset_n_1.to_utc())
    assert_equal(result, sub_seconds.to_utc())

    # test year and month subtract
    result = (
        DateTime[tz_0_, pycal](2025, 1, 1)
        .subtract(years=2, months=6, days=31)
        .to_calendar[unixcal]()
    )
    offset_0 = DateTime[tz_0_, unixcal](2022, 6, 1)
    offset_p_1 = DateTime[tz_1, unixcal](2022, 6, 1, hour=1)
    offset_n_1 = DateTime[tz1_, unixcal](2022, 5, 31, hour=23)
    sub_elements = DateTime[tz_1, unixcal](2025, 1, 1, hour=1).subtract(
        years=2, months=6, days=31
    )
    assert_equal(result, offset_0.to_utc())
    assert_equal(result, offset_p_1.to_utc())
    assert_equal(result, offset_n_1.to_utc())
    assert_equal(result, sub_elements.to_utc())

    # test negative overflow pycal
    result_py = DateTime[tz_0_, pycal](1, 1, 1) - TimeDelta(days=1)
    assert_equal(result_py, DateTime[tz_0_, pycal](9999, 12, 31).to_utc())
    assert_equal(
        result_py, DateTime[tz_1, pycal](9999, 12, 31, hour=1).to_utc()
    )
    assert_equal(
        result_py, DateTime[tz1_, pycal](9999, 12, 30, hour=23).to_utc()
    )
    assert_equal(
        result_py, DateTime[tz_0_, pycal](1, 1, 1).subtract(days=1).to_utc()
    )

    # test negative overflow unixcal
    result = DateTime[tz_0_, unixcal](1970, 1, 1) - TimeDelta(days=1)
    offset_0 = DateTime[tz_0_, unixcal](9999, 12, 31)
    offset_p_1 = DateTime[tz_1, unixcal](9999, 12, 31, hour=1)
    offset_n_1 = DateTime[tz1_, unixcal](9999, 12, 30, hour=23)
    sub_seconds = DateTime[tz_0_, unixcal](1970, 1, 1).subtract(days=1)
    assert_equal(result, offset_0.to_utc())
    assert_equal(result, offset_p_1.to_utc())
    assert_equal(result, offset_n_1.to_utc())
    assert_equal(result, sub_seconds.to_utc())


def test_logic() raises:
    # using python and unix calendar should have no difference in results

    var ref1 = DateTime[tz_0_, pycal](1970, 1, 1)
    var ref2 = DateTime[tz_0_, unixcal](1970, 1, 1).to_calendar[pycal]()
    assert_true(ref1 == ref2)
    var ref3 = DateTime[tz_1, unixcal](1970, 1, 1, 1).to_calendar[pycal]()
    assert_true(ref1 == ref3)
    assert_true(ref1 == DateTime[tz1_, pycal](1969, 12, 31, 23))
    var ref4 = DateTime[tz_0_, unixcal](1970, 1, 2).to_calendar[pycal]()
    assert_true(ref1 < ref4)
    assert_true(ref1 <= ref4)
    assert_true(ref1 > DateTime[tz_0_, pycal](1969, 12, 31))
    assert_true(ref1 >= DateTime[tz_0_, pycal](1969, 12, 31))


def test_bitwise() raises:
    # using python and unix calendar should have no difference in results
    ref1 = DateTime[tz_0_, pycal](1970, 1, 1).hash()
    assert_true(ref1 ^ DateTime[tz_0_, unixcal](1970, 1, 1).hash() == 0)
    assert_true(ref1 ^ DateTime[tz_1, unixcal](1970, 1, 1).hash() == 0)
    assert_true(ref1 ^ DateTime[tz1_, pycal](1969, 12, 31).hash() != 0)
    assert_true((ref1 ^ DateTime[tz_0_, pycal](1970, 1, 2).hash()) != 0)
    assert_true(
        (ref1 | (DateTime[tz_0_, pycal](1970, 1, 2).hash() & 0)) == ref1
    )
    assert_true((ref1 & ~ref1) == 0)
    assert_true(~(ref1 ^ ~ref1) == 0)


def test_add_seconds_large() raises:
    var delta = TimeDelta(seconds=1779159763)
    var dt_leaps = DateTime(DateTime[].calendar._unix_epoch).add(delta)
    assert_equal(dt_leaps, DateTime(2026, 5, 19, 3, 2, 16))


def test_unix_epoch() raises:
    var delta = TimeDelta(seconds=1779159763)
    var dt_leaps = DateTime.from_unix_epoch(delta)
    assert_equal(dt_leaps, DateTime(2026, 5, 19, 3, 2, 16))

    var dt_no_leaps = DateTime[_, UTCFastCal].from_unix_epoch(delta)
    assert_equal(dt_no_leaps, DateTime[_, UTCFastCal](2026, 5, 19, 3, 2, 43))

    assert_equal(dt_no_leaps.to_calendar[dt_leaps.calendar](), dt_leaps)
    assert_equal(dt_leaps.to_calendar[dt_no_leaps.calendar](), dt_no_leaps)


def test_midnight_leap_second_gap() raises:
    var dt_before = DateTime[tz_0_, unixcal](
        1972, 6, 29, hour=23, minute=59, second=59
    )
    var dt_midnight = DateTime[tz_0_, unixcal](
        1972, 6, 30, hour=0, minute=0, second=0
    )
    assert_equal(dt_midnight - dt_before, TimeDelta(seconds=1))

    var dt_leap_start = DateTime[tz_0_, unixcal](
        1972, 6, 30, hour=23, minute=59, second=59
    )
    var dt_after_leap = DateTime[tz_0_, unixcal](
        1972, 7, 1, hour=0, minute=0, second=0
    )
    assert_equal(dt_after_leap - dt_leap_start, TimeDelta(seconds=2))

    assert_equal(dt_before.add(seconds=1), dt_midnight)
    assert_equal(dt_leap_start.add(seconds=2), dt_after_leap)


def test_hash() raises:
    ref1 = DateTime[tz_0_, pycal](1970, 1, 1)
    assert_equal(ref1, DateTime[tz_0_, pycal].from_hash(ref1.hash()))
    ref2 = DateTime[tz_0_, unixcal](1970, 1, 1)
    assert_equal(ref2, DateTime[tz_0_, unixcal].from_hash(ref2.hash()))
    assert_equal(ref1.hash(), ref2.hash())


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
