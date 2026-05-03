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
from mojo_datetime.locale import (
    IsoFormat,
    _parse,
    _write_to,
    _DTSpecIterator,
    _is_valid_spec,
    NativeDTLocale,
    LibCLocale,
    GenericEnglishDTLocale,
    USDTLocale,
    SpanishDTLocale,
    FrenchDTLocale,
    PortugueseDTLocale,
    ChineseDTLocale,
    JapaneseDTLocale,
    RussianDTLocale,
    HindiDTLocale,
    ArabicDTLocale,
    BengaliDTLocale,
    GermanDTLocale,
    KoreanDTLocale,
    IndonesianDTLocale,
    ItalianDTLocale,
)
from mojo_datetime.timezone import TZ_UTC
from mojo_datetime.zoneinfo import gregorian_zoneinfo
from mojo_datetime._tz_naive_datetime import _TzNaiveDateTime

comptime parse[fmt: String] = _parse[
    fmt, PythonCalendar, gregorian_zoneinfo, GenericEnglishDTLocale
]


def test_dt_spec_iterator() raises:
    comptime DTIter = _DTSpecIterator[StaticConstantOrigin]

    var it = DTIter("hi!")
    assert_equal(next(it), DTIter.Element(False, "hi!"))
    with assert_raises():
        _ = next(it)

    # malformed unescaped or unfinished sequences should avoid reading beyond
    it = DTIter("%")
    with assert_raises():
        _ = next(it)

    it = DTIter("%%hi: %%")
    assert_equal(next(it), DTIter.Element(True, "%"))
    assert_equal(next(it), DTIter.Element(False, "hi: "))
    assert_equal(next(it), DTIter.Element(True, "%"))
    with assert_raises():
        _ = next(it)

    it = DTIter("%ahi: %b")
    assert_equal(next(it), DTIter.Element(True, "a"))
    assert_equal(next(it), DTIter.Element(False, "hi: "))
    assert_equal(next(it), DTIter.Element(True, "b"))
    with assert_raises():
        _ = next(it)

    it = DTIter("a%ahi: b%b")
    assert_equal(next(it), DTIter.Element(False, "a"))
    assert_equal(next(it), DTIter.Element(True, "a"))
    assert_equal(next(it), DTIter.Element(False, "hi: b"))
    assert_equal(next(it), DTIter.Element(True, "b"))
    with assert_raises():
        _ = next(it)

    it = DTIter("%a%ahi: %b%b")
    assert_equal(next(it), DTIter.Element(True, "a"))
    assert_equal(next(it), DTIter.Element(True, "a"))
    assert_equal(next(it), DTIter.Element(False, "hi: "))
    assert_equal(next(it), DTIter.Element(True, "b"))
    assert_equal(next(it), DTIter.Element(True, "b"))
    with assert_raises():
        _ = next(it)

    # Extensions

    it = DTIter("%:z")
    assert_equal(next(it), DTIter.Element(True, ":z"))
    with assert_raises():
        _ = next(it)

    it = DTIter("%:a")
    assert_equal(next(it), DTIter.Element(True, ":a"))
    with assert_raises():
        _ = next(it)

    it = DTIter("%:")
    assert_equal(next(it), DTIter.Element(True, ":"))
    with assert_raises():
        _ = next(it)

    # iso formats
    it = DTIter("%Y-%m-%dT%H:%M:%S%:z")
    assert_equal(next(it), DTIter.Element(True, "Y"))
    assert_equal(next(it), DTIter.Element(False, "-"))
    assert_equal(next(it), DTIter.Element(True, "m"))
    assert_equal(next(it), DTIter.Element(False, "-"))
    assert_equal(next(it), DTIter.Element(True, "d"))
    assert_equal(next(it), DTIter.Element(False, "T"))
    assert_equal(next(it), DTIter.Element(True, "H"))
    assert_equal(next(it), DTIter.Element(False, ":"))
    assert_equal(next(it), DTIter.Element(True, "M"))
    assert_equal(next(it), DTIter.Element(False, ":"))
    assert_equal(next(it), DTIter.Element(True, "S"))
    assert_equal(next(it), DTIter.Element(True, ":z"))
    with assert_raises():
        _ = next(it)

    it = DTIter("%%Y%%m%%d%%H%%M%%S%%z%%")
    assert_equal(next(it), DTIter.Element(True, "%"))
    assert_equal(next(it), DTIter.Element(False, "Y"))
    assert_equal(next(it), DTIter.Element(True, "%"))
    assert_equal(next(it), DTIter.Element(False, "m"))
    assert_equal(next(it), DTIter.Element(True, "%"))
    assert_equal(next(it), DTIter.Element(False, "d"))
    assert_equal(next(it), DTIter.Element(True, "%"))
    assert_equal(next(it), DTIter.Element(False, "H"))
    assert_equal(next(it), DTIter.Element(True, "%"))
    assert_equal(next(it), DTIter.Element(False, "M"))
    assert_equal(next(it), DTIter.Element(True, "%"))
    assert_equal(next(it), DTIter.Element(False, "S"))
    assert_equal(next(it), DTIter.Element(True, "%"))
    assert_equal(next(it), DTIter.Element(False, "z"))
    assert_equal(next(it), DTIter.Element(True, "%"))
    with assert_raises():
        _ = next(it)


def test_validate_iso() raises:
    var validated = _is_valid_spec(IsoFormat.YYYY_MM_DD_T_HH_MM_SS_TZD)
    assert_true(validated[0], validated[1])
    validated = _is_valid_spec(IsoFormat.YYYY_MM_DD___HH_MM_SS)
    assert_true(validated[0], validated[1])
    validated = _is_valid_spec(IsoFormat.YYYY_MM_DD_T_HH_MM_SS)
    assert_true(validated[0], validated[1])
    validated = _is_valid_spec(IsoFormat.YYYYMMDDHHMMSSTZD)
    assert_true(validated[0], validated[1])
    validated = _is_valid_spec(IsoFormat.YYYYMMDDHHMMSS)
    assert_true(validated[0], validated[1])
    validated = _is_valid_spec(IsoFormat.YYYY_MM_DD)
    assert_true(validated[0], validated[1])
    validated = _is_valid_spec(IsoFormat.YYYYMMDD)
    assert_true(validated[0], validated[1])
    validated = _is_valid_spec(IsoFormat.HH_MM_SS)
    assert_true(validated[0], validated[1])
    validated = _is_valid_spec(IsoFormat.HHMMSS)
    assert_true(validated[0], validated[1])


def test_validate_iso_comptime() raises:
    comptime validated0 = _is_valid_spec(IsoFormat.YYYY_MM_DD_T_HH_MM_SS_TZD)
    assert_true(validated0[0], validated0[1])
    comptime validated1 = _is_valid_spec(IsoFormat.YYYY_MM_DD___HH_MM_SS)
    assert_true(validated1[0], validated1[1])
    comptime validated2 = _is_valid_spec(IsoFormat.YYYY_MM_DD_T_HH_MM_SS)
    assert_true(validated2[0], validated2[1])
    comptime validated3 = _is_valid_spec(IsoFormat.YYYYMMDDHHMMSSTZD)
    assert_true(validated3[0], validated3[1])
    comptime validated4 = _is_valid_spec(IsoFormat.YYYYMMDDHHMMSS)
    assert_true(validated4[0], validated4[1])
    comptime validated5 = _is_valid_spec(IsoFormat.YYYY_MM_DD)
    assert_true(validated5[0], validated5[1])
    comptime validated6 = _is_valid_spec(IsoFormat.YYYYMMDD)
    assert_true(validated6[0], validated6[1])
    comptime validated7 = _is_valid_spec(IsoFormat.HH_MM_SS)
    assert_true(validated7[0], validated7[1])
    comptime validated8 = _is_valid_spec(IsoFormat.HHMMSS)
    assert_true(validated8[0], validated8[1])


def test_parse_write_iso() raises:
    var ref1 = _TzNaiveDateTime[PythonCalendar]({2024, 6, 16, 18, 51, 20})
    var iso_str = "2024-06-16T18:51:20+00:00"
    comptime fmt1 = IsoFormat.YYYY_MM_DD_T_HH_MM_SS_TZD
    assert_equal(ref1, parse[fmt1](iso_str))
    res = String(capacity=iso_str.byte_length())
    _write_to[fmt1, "", GenericEnglishDTLocale](res, ref1, {})
    assert_equal(iso_str, res)

    iso_str = "2024-06-16 18:51:20"
    comptime fmt2 = IsoFormat.YYYY_MM_DD___HH_MM_SS
    assert_equal(ref1, parse[fmt2](iso_str))
    res = String(capacity=iso_str.byte_length())
    _write_to[fmt2, "", GenericEnglishDTLocale](res, ref1, {})
    assert_equal(iso_str, res)

    iso_str = "2024-06-16T18:51:20"
    comptime fmt3 = IsoFormat.YYYY_MM_DD_T_HH_MM_SS
    assert_equal(ref1, parse[fmt3](iso_str))
    res = String(capacity=iso_str.byte_length())
    _write_to[fmt3, "", GenericEnglishDTLocale](res, ref1, {})
    assert_equal(iso_str, res)

    iso_str = "20240616185120+0000"
    comptime fmt4 = IsoFormat.YYYYMMDDHHMMSSTZD
    assert_equal(ref1, parse[fmt4](iso_str))
    res = String(capacity=iso_str.byte_length())
    _write_to[fmt4, "", GenericEnglishDTLocale](res, ref1, {})
    assert_equal(iso_str, res)

    iso_str = "20240616185120"
    comptime fmt5 = IsoFormat.YYYYMMDDHHMMSS
    assert_equal(ref1, parse[fmt5](iso_str))
    res = String(capacity=iso_str.byte_length())
    _write_to[fmt5, "", GenericEnglishDTLocale](res, ref1, {})
    assert_equal(iso_str, res)

    ref1 = _TzNaiveDateTime[PythonCalendar]({2024, 6, 16, 0, 0, 0})
    iso_str = "2024-06-16"
    comptime fmt6 = IsoFormat.YYYY_MM_DD
    assert_equal(ref1, parse[fmt6](iso_str))
    res = String(capacity=iso_str.byte_length())
    _write_to[fmt6, "", GenericEnglishDTLocale](res, ref1, {})
    assert_equal(iso_str, res)

    iso_str = "20240616"
    comptime fmt7 = IsoFormat.YYYYMMDD
    assert_equal(ref1, parse[fmt7](iso_str))
    res = String(capacity=iso_str.byte_length())
    _write_to[fmt7, "", GenericEnglishDTLocale](res, ref1, {})
    assert_equal(iso_str, res)

    ref1 = _TzNaiveDateTime[PythonCalendar]({2024, 1, 1, 18, 51, 20})
    var ref2 = _TzNaiveDateTime[PythonCalendar]({1, 1, 1, 18, 51, 20})
    iso_str = "18:51:20"
    comptime fmt8 = IsoFormat.HH_MM_SS
    assert_equal(ref2, parse[fmt8](iso_str))
    res = String(capacity=iso_str.byte_length())
    _write_to[fmt8, "", GenericEnglishDTLocale](res, ref1, {})
    assert_equal(iso_str, res)
    res = String(capacity=iso_str.byte_length())
    _write_to[fmt8, "", GenericEnglishDTLocale](res, ref2, {})
    assert_equal(iso_str, res)

    iso_str = "185120"
    comptime fmt9 = IsoFormat.HHMMSS
    assert_equal(ref2, parse[fmt9](iso_str))
    res = String(capacity=iso_str.byte_length())
    _write_to[fmt9, "", GenericEnglishDTLocale](res, ref1, {})
    assert_equal(iso_str, res)
    res = String(capacity=iso_str.byte_length())
    _write_to[fmt9, "", GenericEnglishDTLocale](res, ref2, {})
    assert_equal(iso_str, res)


def test_parse_write_to_emojii() raises:
    var ref1 = _TzNaiveDateTime[PythonCalendar]({9, 6, 1})
    comptime fmt1 = "mojo: %Y🔥%m🤯%d"
    var res_str = "mojo: 0009🔥06🤯01"
    var res = String(capacity=res_str.byte_length())
    _write_to[fmt1, "", GenericEnglishDTLocale](res, ref1, {})
    assert_equal(res_str, res)
    assert_equal(ref1, parse[fmt1](res_str))


def test_parse_write_to_microseconds() raises:
    var ref1 = _TzNaiveDateTime[PythonCalendar]({2024, 9, 9, 9, 9, 9, 9, 9})
    comptime fmt1 = "%Y-%m-%d %H:%M:%S.%f"
    var res_str = "2024-09-09 09:09:09.009009"
    var res = String(capacity=res_str.byte_length())
    _write_to[fmt1, "", GenericEnglishDTLocale](res, ref1, {})
    assert_equal(res_str, res)
    assert_equal(ref1, parse[fmt1](res_str))


def test_parse_write_to_yyyy_ddd() raises:
    comptime fmt1 = "%Y-%j %H:%M:%S.%f"

    # test normal year
    var ref1 = _TzNaiveDateTime[PythonCalendar]({2025, 9, 9, 9, 9, 9, 9, 9})
    res_str = "2025-252 09:09:09.009009"
    res = String(capacity=res_str.byte_length())
    _write_to[fmt1, "", GenericEnglishDTLocale](res, ref1, {})
    assert_equal(res_str, res)
    assert_equal(ref1, parse[fmt1](res_str))

    # test leap year
    ref1 = _TzNaiveDateTime[PythonCalendar]({2024, 9, 9, 9, 9, 9, 9, 9})
    res_str = "2024-253 09:09:09.009009"
    res = String(capacity=res_str.byte_length())
    _write_to[fmt1, "", GenericEnglishDTLocale](res, ref1, {})
    assert_equal(res_str, res)
    assert_equal(ref1, parse[fmt1](res_str))

    # test leap year december
    ref1 = _TzNaiveDateTime[PythonCalendar]({2024, 12, 31, 9, 9, 9, 9, 9})
    res_str = "2024-366 09:09:09.009009"
    res = String(capacity=res_str.byte_length())
    _write_to[fmt1, "", GenericEnglishDTLocale](res, ref1, {})
    assert_equal(res_str, res)
    assert_equal(ref1, parse[fmt1](res_str))

    # test start of calendar
    ref1 = _TzNaiveDateTime[PythonCalendar]({1, 1, 1, 9, 9, 9, 9, 9})
    res_str = "0001-001 09:09:09.009009"
    res = String(capacity=res_str.byte_length())
    _write_to[fmt1, "", GenericEnglishDTLocale](res, ref1, {})
    assert_equal(res_str, res)
    assert_equal(ref1, parse[fmt1](res_str))

    # test end of calendar
    ref1 = _TzNaiveDateTime[PythonCalendar]({9999, 12, 31, 9, 9, 9, 9, 9})
    res_str = "9999-365 09:09:09.009009"
    res = String(capacity=res_str.byte_length())
    _write_to[fmt1, "", GenericEnglishDTLocale](res, ref1, {})
    assert_equal(res_str, res)
    assert_equal(ref1, parse[fmt1](res_str))


def test_parse_write_to_am_pm() raises:
    comptime fmt1 = "%Y-%m-%d %I:%M%p"

    var ref1 = _TzNaiveDateTime[PythonCalendar]({2024, 9, 9, 1, 1})
    var res_str = "2024-09-09 01:01AM"
    var res = String(capacity=res_str.byte_length())
    _write_to[fmt1, "", GenericEnglishDTLocale](res, ref1, {})
    assert_equal(res_str, res)
    assert_equal(ref1, parse[fmt1](res_str))

    for h in range(UInt8(1), UInt8(12 + 1)):
        for m in range(UInt8(60)):
            for is_pm in [True, False]:
                var h2 = UInt8(12 if is_pm else 0) if h == 12 else (
                    h + UInt8(12 if is_pm else 0)
                )
                var ref1 = _TzNaiveDateTime[PythonCalendar]({2024, 9, 9, h2, m})
                var res = String(capacity=res_str.byte_length())
                _write_to[fmt1, "", GenericEnglishDTLocale](res, ref1, {})
                var should_be = String(
                    "2024-09-09 ",
                    "0" if h < 10 else "",
                    h,
                    ":",
                    "0" if m < 10 else "",
                    m,
                    "PM" if is_pm else "AM",
                )
                assert_equal(should_be, res)
                assert_equal(ref1, parse[fmt1](res))


def test_native_locales() raises:
    var dt = _TzNaiveDateTime[PythonCalendar]({2026, 4, 28, 15, 30, 0})

    def _test_n[
        locale_t: NativeDTLocale, fmt: String
    ](dt: _TzNaiveDateTime[PythonCalendar], expected: String) raises:
        var loc = locale_t()
        var res = String()
        _write_to[fmt, "", locale_t](res, dt, {}, loc.copy())
        assert_equal(expected, res)
        var parsed = _parse[fmt, PythonCalendar, gregorian_zoneinfo, locale_t](
            expected, loc^
        )
        assert_equal(dt, parsed)

    comptime fmt_short = "%a %d %b %Y %H:%M:%S"
    comptime fmt_long = "%A %d %B %Y %I:%M:%S %p"

    comptime G = GenericEnglishDTLocale
    _test_n[G, fmt_short](dt, "Tue 28 Apr 2026 15:30:00")
    _test_n[G, fmt_long](dt, "Tuesday 28 April 2026 03:30:00 PM")
    _test_n[USDTLocale, fmt_short](dt, "Tue 28 Apr 2026 15:30:00")
    _test_n[USDTLocale, fmt_long](dt, "Tuesday 28 April 2026 03:30:00 PM")
    _test_n[SpanishDTLocale, fmt_short](dt, "Mar 28 Abr 2026 15:30:00")
    _test_n[SpanishDTLocale, fmt_long](dt, "Martes 28 Abril 2026 03:30:00 PM")
    _test_n[FrenchDTLocale, fmt_short](dt, "Mar 28 Avr 2026 15:30:00")
    _test_n[FrenchDTLocale, fmt_long](dt, "Mardi 28 Avril 2026 03:30:00 PM")
    comptime P = PortugueseDTLocale
    _test_n[P, fmt_short](dt, "Ter 28 Abr 2026 15:30:00")
    _test_n[P, fmt_long](dt, "Terça-feira 28 Abril 2026 03:30:00 PM")
    _test_n[ChineseDTLocale, fmt_short](dt, "周二 28 4月 2026 15:30:00")
    _test_n[ChineseDTLocale, fmt_long](dt, "星期二 28 四月 2026 03:30:00 下午")
    _test_n[JapaneseDTLocale, fmt_short](dt, "火 28 4月 2026 15:30:00")
    _test_n[JapaneseDTLocale, fmt_long](dt, "火曜日 28 4月 2026 03:30:00 午後")
    _test_n[RussianDTLocale, fmt_short](dt, "Вт 28 апр 2026 15:30:00")
    _test_n[RussianDTLocale, fmt_long](dt, "Вторник 28 апреля 2026 03:30:00 ПП")
    comptime H = HindiDTLocale
    _test_n[H, fmt_short](dt, "मंगल 28 अप्रैल 2026 15:30:00")
    _test_n[H, fmt_long](dt, "मंगलवार 28 अप्रैल 2026 03:30:00 अपराह्न")
    _test_n[ArabicDTLocale, fmt_short](dt, "الثلاثاء 28 أبريل 2026 15:30:00")
    _test_n[ArabicDTLocale, fmt_long](dt, "الثلاثاء 28 أبريل 2026 03:30:00 م")
    comptime B = BengaliDTLocale
    _test_n[B, fmt_short](dt, "মঙ্গল 28 এপ্রিল 2026 15:30:00")
    _test_n[B, fmt_long](dt, "মঙ্গলবার 28 এপ্রিল 2026 03:30:00 অপরাহ্ণ")
    comptime Ge = GermanDTLocale
    _test_n[Ge, fmt_short](dt, "Di 28 Apr 2026 15:30:00")
    _test_n[Ge, fmt_long](dt, "Dienstag 28 April 2026 03:30:00 nachm.")
    _test_n[KoreanDTLocale, fmt_short](dt, "화 28 4월 2026 15:30:00")
    _test_n[KoreanDTLocale, fmt_long](dt, "화요일 28 4월 2026 03:30:00 오후")
    comptime I = IndonesianDTLocale
    _test_n[I, fmt_short](dt, "Sel 28 Apr 2026 15:30:00")
    _test_n[I, fmt_long](dt, "Selasa 28 April 2026 03:30:00 PM")
    _test_n[ItalianDTLocale, fmt_short](dt, "Mar 28 Apr 2026 15:30:00")
    _test_n[ItalianDTLocale, fmt_long](dt, "Martedì 28 Aprile 2026 03:30:00 PM")


def test_libc_c_locale() raises:
    var dt = _TzNaiveDateTime[PythonCalendar]({2026, 4, 28, 15, 30, 0})
    comptime fmt_short = "%a %d %b %Y %H:%M:%S"
    comptime fmt_long = "%A %d %B %Y %I:%M:%S %p"

    comptime short_res = "Tue 28 Apr 2026 15:30:00"
    comptime long_res = "Tuesday 28 April 2026 03:30:00 PM"

    var res = String()
    # C and POSIX are guaranteed to exist on Unix systems.
    for locale_name in ["C", "POSIX"]:
        var loc = LibCLocale(locale_name)

        _write_to[fmt_short, "", LibCLocale](res, dt, {}, loc.copy())
        assert_equal(short_res, res)
        parsed = _parse[
            fmt_short, PythonCalendar, gregorian_zoneinfo, LibCLocale
        ](short_res, loc.copy())
        assert_equal(dt, parsed)
        res = ""

        _write_to[fmt_long, "", LibCLocale](res, dt, {}, loc.copy())
        assert_equal(long_res, res)
        parsed = _parse[
            fmt_long, PythonCalendar, gregorian_zoneinfo, LibCLocale
        ](long_res, loc^)
        assert_equal(dt, parsed)
        res = ""


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
