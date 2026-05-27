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
from std.python import Python, PythonObject

from mojo_datetime._tz_naive_datetime import _TzNaiveDateTime
from mojo_datetime.timedelta import TimeDelta
from mojo_datetime.calendar import (
    Calendar,
    PythonCalendar,
    UTCCalendar,
    UTCFastCal,
    ISOCalendar,
    SITimeUnit,
)


def _test_gregorian_add_subtract[
    cal: Calendar
](
    delta: TimeDelta[SITimeUnit.SECONDS],
    expected_no_leaps: _TzNaiveDateTime[cal],
    expected_leaps: _TzNaiveDateTime[cal],
) raises:
    comptime DT = _TzNaiveDateTime[cal]
    var dt = DT(cal._unix_epoch)._add_generic(seconds=delta.value)
    comptime if cal.includes_leapsecs:
        assert_equal(dt, expected_leaps)
    else:
        assert_equal(dt, expected_no_leaps)

    assert_equal(dt._subtract_generic(seconds=delta.value), DT(cal._unix_epoch))

    dt = DT(cal._unix_epoch)._add_gregorian(seconds=delta.value)
    comptime if cal.includes_leapsecs:
        assert_equal(dt, expected_leaps)
    else:
        assert_equal(dt, expected_no_leaps)

    assert_equal(
        dt._subtract_gregorian(seconds=delta.value), DT(cal._unix_epoch)
    )


def _test_gregorian_subtract_add[
    cal: Calendar
](
    delta: TimeDelta[SITimeUnit.SECONDS],
    expected_no_leaps: _TzNaiveDateTime[cal],
    expected_leaps: _TzNaiveDateTime[cal],
) raises:
    comptime DT = _TzNaiveDateTime[cal]

    var dt = DT(cal._unix_epoch)._subtract_generic(seconds=delta.value)
    comptime if cal.includes_leapsecs:
        assert_equal(dt, expected_leaps)
    else:
        assert_equal(dt, expected_no_leaps)

    assert_equal(dt._add_generic(seconds=delta.value), DT(cal._unix_epoch))

    dt = DT(cal._unix_epoch)._subtract_gregorian(seconds=delta.value)
    comptime if cal.includes_leapsecs:
        assert_equal(dt, expected_leaps)
    else:
        assert_equal(dt, expected_no_leaps)

    assert_equal(dt._add_gregorian(seconds=delta.value), DT(cal._unix_epoch))


def _test_gregorian_calendar[cal: Calendar]() raises:
    _test_gregorian_add_subtract[cal](
        TimeDelta(seconds=1779159763),
        {{2026, 5, 19, 3, 2, 43}},
        {{2026, 5, 19, 3, 2, 16}},
    )
    _test_gregorian_add_subtract[cal](
        TimeDelta(seconds=68169600),
        {{1972, 2, 29, 0, 0, 0}},
        {{1972, 2, 29, 0, 0, 0}},
    )
    _test_gregorian_add_subtract[cal](
        TimeDelta(seconds=864000000),
        {{1997, 5, 19, 0, 0, 0}},
        {{1997, 5, 18, 23, 59, 40}},
    )
    _test_gregorian_add_subtract[cal](
        TimeDelta(seconds=946684799),
        {{1999, 12, 31, 23, 59, 59}},
        {{1999, 12, 31, 23, 59, 37}},
    )
    _test_gregorian_add_subtract[cal](
        TimeDelta(seconds=1000000000),
        {{2001, 9, 9, 1, 46, 40}},
        {{2001, 9, 9, 1, 46, 18}},
    )
    _test_gregorian_add_subtract[cal](
        TimeDelta(seconds=2147483647),
        {{2038, 1, 19, 3, 14, 7}},
        {{2038, 1, 19, 3, 13, 40}},
    )

    # overflow and underflow tests

    comptime if cal.min_year == 1:
        _test_gregorian_subtract_add[cal](
            TimeDelta(seconds=1),
            {{1969, 12, 31, 23, 59, 59}},
            {{1969, 12, 31, 23, 59, 59}},
        )
        _test_gregorian_subtract_add[cal](
            TimeDelta(seconds=315619200),
            {{1960, 1, 1, 0, 0, 0}},
            {{1960, 1, 1, 0, 0, 0}},
        )
        _test_gregorian_subtract_add[cal](
            TimeDelta(seconds=62135596800),
            {{1, 1, 1, 0, 0, 0}},
            {{1, 1, 1, 0, 0, 0}},
        )
        _test_gregorian_subtract_add[cal](
            TimeDelta(seconds=62135596801),
            {{9999, 12, 31, 23, 59, 59}},
            {{9999, 12, 31, 23, 59, 59}},
        )
    elif cal.min_year == 1970:
        _test_gregorian_subtract_add[cal](
            TimeDelta(seconds=1),
            {{9999, 12, 31, 23, 59, 59}},
            {{9999, 12, 31, 23, 59, 59}},
        )
        _test_gregorian_subtract_add[cal](
            TimeDelta(seconds=1000),
            {{9999, 12, 31, 23, 43, 20}},
            {{9999, 12, 31, 23, 43, 20}},
        )

    # test add and subtract invariants for big-endian and little-endian back
    # and forth

    # add subtract

    comptime DT = _TzNaiveDateTime[cal]
    var dt = DT({2022, 6, 1})._add_generic(years=2, months=6, days=31)
    assert_equal(dt, DT({2025, 1, 1}))
    assert_equal(
        dt._subtract_generic(years=2, months=6, days=31), DT({2022, 6, 1})
    )

    dt = DT({2022, 6, 1})._add_gregorian(years=2, months=6, days=31)
    assert_equal(dt, DT({2025, 1, 1}))
    assert_equal(
        dt._subtract_gregorian(years=2, months=6, days=31), DT({2022, 6, 1})
    )

    # subtract add

    dt = DT({2025, 1, 1})._subtract_generic(years=2, months=6, days=31)
    assert_equal(dt, DT({2022, 6, 1}))
    assert_equal(dt._add_generic(years=2, months=6, days=31), DT({2025, 1, 1}))

    dt = DT({2025, 1, 1})._subtract_gregorian(years=2, months=6, days=31)
    assert_equal(dt, DT({2022, 6, 1}))
    assert_equal(
        dt._add_gregorian(years=2, months=6, days=31), DT({2025, 1, 1})
    )


def test_add_subtract_pycal() raises:
    _test_gregorian_calendar[PythonCalendar]()


def test_add_subtract_utccalendar() raises:
    _test_gregorian_calendar[UTCCalendar]()


def test_add_subtract_utcfastcal() raises:
    _test_gregorian_calendar[UTCFastCal]()


def test_add_subtract_isocalendar() raises:
    _test_gregorian_calendar[ISOCalendar[]]()


def test_unix_epoch() raises:
    comptime DT = _TzNaiveDateTime[UTCFastCal]
    var delta = TimeDelta(seconds=1779159763)
    var dt_leaps = DT().add(delta).to_calendar[PythonCalendar]()
    assert_equal(
        dt_leaps, _TzNaiveDateTime[PythonCalendar]({2026, 5, 19, 3, 2, 16})
    )

    var dt_no_leaps = DT().add(delta)
    assert_equal(dt_no_leaps, DT({2026, 5, 19, 3, 2, 43}))

    assert_equal(dt_no_leaps.to_calendar[dt_leaps.calendar](), dt_leaps)
    assert_equal(dt_leaps.to_calendar[dt_no_leaps.calendar](), dt_no_leaps)

    # test resolution

    var dt = DT().add(TimeDelta(seconds=1779725919))
    assert_equal(dt, DT({2026, 5, 25, 16, 18, 39}))

    dt = DT().add(TimeDelta(milliseconds=1779725919111))
    assert_equal(dt, DT({2026, 5, 25, 16, 18, 39, 111}))

    dt = DT().add(TimeDelta(microseconds=1779725919111222))
    assert_equal(dt, DT({2026, 5, 25, 16, 18, 39, 111, 222}))

    dt = DT().add(TimeDelta(nanoseconds=1779725919111222333))
    assert_equal(dt, DT({2026, 5, 25, 16, 18, 39, 111, 222, 333}))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
