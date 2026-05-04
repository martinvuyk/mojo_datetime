# mojo_datetime

A flexible Mojo datetime implementation.

Fully Mojo native, no external dependencies.

## Distribution channels

- Github releases for both 0.26.2 and nightly versions
- The latest 0.26.2 version should be in the `modular-community` channel

## About the library

Many of the core types are able to be injected with updated values in case this
library becomes out-of-date. The default values like leap seconds and daylight
savings time transition rules are provided on a best-effort basis.

- `DateTime`
    - A structure aware of TimeZone, Calendar, and leap days and seconds.
- `TimeZone`
    - By default UTC, highly customizable.
- `DayOfWeek`
    - A calendar-aware day of the week struct, it provides a safe abstraction
        over the different calendar's interpretation of what a day of the week's
        value range looks like.
- `TimeDelta`
    - A struct representing a positive (incl. 0) time delta. It is aware of what
        SI unit of time it contains.

## Localization system

A trait `DTLocale` is provided that allows one to specify a dynamic handled
Locale with a lifetime, like what Libc requires.

As a fallback, an implementation for `LibCLocale` is provided, which enables
one to use any locale supported by the platform's Libc. But using a Mojo native
implementation of the trait should be preferred.

Native Mojo locales are provided for these locales, with a trait
`NativeDTLocale` that can be extended that enables fast bringup:
- `GenericEnglishDTLocale`
- `USDTLocale`
- `SpanishDTLocale`
- `FrenchDTLocale`
- `PortugueseDTLocale`
- `ChineseDTLocale`
- `JapaneseDTLocale`
- `RussianDTLocale`
- `HindiDTLocale`
- `ArabicDTLocale`
- `BengaliDTLocale`
- `GermanDTLocale`
- `KoreanDTLocale`
- `IndonesianDTLocale`
- `ItalianDTLocale`

## Examples:

```mojo
from std.testing import assert_equal, assert_true
from mojo_datetime import DateTime, Calendar, IsoFormat, TZ_UTC, TimeDelta
from mojo_datetime.calendar import PythonCalendar, UTCCalendar

def main() raises:
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
    comptime fstr3 = "%a %d %b %Y %H:%M:%S"
    res = ""
    dt.write_to[fstr3](res)
    assert_equal(res, "Tue 28 Apr 2026 15:30:00")
    assert_equal(dt, DateTime.parse[fstr3](res))

    comptime fstr4 = "%A %d %B %Y %I:%M:%S %p"
    res = ""
    dt.write_to[fstr4](res)
    assert_equal(res, "Tuesday 28 April 2026 03:30:00 PM")
    assert_equal(dt, DateTime.parse[fstr4](res))
```