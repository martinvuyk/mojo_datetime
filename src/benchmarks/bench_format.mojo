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
"""Benchmarks for `DateTime.write_to` and `DateTime.parse`."""

from std.benchmark import (
    Bench,
    BenchConfig,
    Bencher,
    BenchId,
    BenchMetric,
    ThroughputMeasure,
    black_box,
    keep,
)

from mojo_datetime import DateTime, IsoFormat
from mojo_datetime.locale import (
    GenericEnglishDTLocale,
    LibCLocale,
    SpanishDTLocale,
)

comptime BATCH = 10_000
comptime FIXED_DT = DateTime(2026, 4, 28, 15, 30, 45)

# ===----------------------------------------------------------------------=== #
# write_to benchmarks
# ===----------------------------------------------------------------------=== #


@parameter
def bench_write_iso(mut b: Bencher) raises:
    """ISO-8601 datetime with TZ designator: no locale-aware codes."""
    comptime fmt = IsoFormat.YYYY_MM_DD_T_HH_MM_SS_TZD

    @always_inline
    @parameter
    def call_fn() raises:
        for _ in range(BATCH):
            var dt = black_box(FIXED_DT)
            var out = String()
            dt.write_to[fmt](out)
            keep(out)

    b.iter[call_fn]()


@parameter
def bench_write_locale_short_native(mut b: Bencher) raises:
    """Short locale-aware format using the native English locale.

    Exercises `%a` and `%b`.
    """
    comptime fmt = "%a %d %b %Y %H:%M:%S"

    @always_inline
    @parameter
    def call_fn() raises:
        for _ in range(BATCH):
            var dt = black_box(FIXED_DT)
            var out = String()
            dt.write_to[fmt, GenericEnglishDTLocale](
                out, GenericEnglishDTLocale()
            )
            keep(out)

    b.iter[call_fn]()


@parameter
def bench_write_locale_long_native(mut b: Bencher) raises:
    """Long locale-aware format using the native English locale."""
    comptime fmt = "%A %d %B %Y %I:%M:%S %p"

    @always_inline
    @parameter
    def call_fn() raises:
        for _ in range(BATCH):
            var dt = black_box(FIXED_DT)
            var out = String()
            dt.write_to[fmt, GenericEnglishDTLocale](
                out, GenericEnglishDTLocale()
            )
            keep(out)

    b.iter[call_fn]()


@parameter
def bench_write_locale_short_libc(mut b: Bencher) raises:
    """Short locale-aware format using the libc-backed locale."""
    comptime fmt = "%a %d %b %Y %H:%M:%S"
    var loc = LibCLocale("C")

    @always_inline
    @parameter
    def call_fn() raises:
        for _ in range(BATCH):
            var dt = black_box(FIXED_DT)
            var out = String()
            dt.write_to[fmt, LibCLocale](out, loc.copy())
            keep(out)

    b.iter[call_fn]()
    keep(loc)


@parameter
def bench_write_locale_long_libc(mut b: Bencher) raises:
    """Long locale-aware format using the libc-backed locale."""
    comptime fmt = "%A %d %B %Y %I:%M:%S %p"
    var loc = LibCLocale("C")

    @always_inline
    @parameter
    def call_fn() raises:
        for _ in range(BATCH):
            var dt = black_box(FIXED_DT)
            var out = String()
            dt.write_to[fmt, LibCLocale](out, loc.copy())
            keep(out)

    b.iter[call_fn]()
    keep(loc)


@parameter
def bench_write_locale_c_recursion_native(mut b: Bencher) raises:
    """`%c` triggers `datetime_fmt[calendar]()` and recurses through several
    locale-aware codes."""
    comptime fmt = "%c"

    @always_inline
    @parameter
    def call_fn() raises:
        for _ in range(BATCH):
            var dt = black_box(FIXED_DT)
            var out = String()
            dt.write_to[fmt, GenericEnglishDTLocale](
                out, GenericEnglishDTLocale()
            )
            keep(out)

    b.iter[call_fn]()


@parameter
def bench_write_locale_c_recursion_libc(mut b: Bencher) raises:
    """`%c` triggers `datetime_fmt[calendar]()` and recurses through several
    locale-aware codes."""
    comptime fmt = "%c"
    var loc = LibCLocale("C")

    @always_inline
    @parameter
    def call_fn() raises:
        for _ in range(BATCH):
            var dt = black_box(FIXED_DT)
            var out = String()
            dt.write_to[fmt, LibCLocale](out, loc.copy())
            keep(out)

    b.iter[call_fn]()


# ===----------------------------------------------------------------------=== #
# parse benchmarks
# ===----------------------------------------------------------------------=== #


@parameter
def bench_parse_iso(mut b: Bencher) raises:
    """ISO-8601 parse: no locale-aware codes."""
    comptime fmt = IsoFormat.YYYY_MM_DD_T_HH_MM_SS_TZD
    var src = "2026-04-28T15:30:45+00:00"

    @always_inline
    @parameter
    def call_fn() raises:
        for _ in range(BATCH):
            var s = black_box(src)
            var dt = DateTime.parse[fmt](s)
            keep(dt)

    b.iter[call_fn]()
    keep(src)


@parameter
def bench_parse_locale_short_native(mut b: Bencher) raises:
    """Short locale-aware parse using the native English locale."""
    comptime fmt = "%a %d %b %Y %H:%M:%S"
    var src = "Tue 28 Apr 2026 15:30:45"

    @always_inline
    @parameter
    def call_fn() raises:
        for _ in range(BATCH):
            var s = black_box(src)
            var dt = DateTime.parse[fmt, GenericEnglishDTLocale](
                s, GenericEnglishDTLocale()
            )
            keep(dt)

    b.iter[call_fn]()
    keep(src)


@parameter
def bench_parse_locale_long_native(mut b: Bencher) raises:
    """Long locale-aware parse using the native English locale."""
    comptime fmt = "%A %d %B %Y %I:%M:%S %p"
    var src = "Tuesday 28 April 2026 03:30:45 PM"

    @always_inline
    @parameter
    def call_fn() raises:
        for _ in range(BATCH):
            var s = black_box(src)
            var dt = DateTime.parse[fmt, GenericEnglishDTLocale](
                s, GenericEnglishDTLocale()
            )
            keep(dt)

    b.iter[call_fn]()
    keep(src)


@parameter
def bench_parse_locale_short_libc(mut b: Bencher) raises:
    """Short locale-aware parse using the libc-backed locale."""
    comptime fmt = "%a %d %b %Y %H:%M:%S"
    var src = "Tue 28 Apr 2026 15:30:45"
    var loc = LibCLocale("C")

    @always_inline
    @parameter
    def call_fn() raises:
        for _ in range(BATCH):
            var s = black_box(src)
            var dt = DateTime.parse[fmt, LibCLocale](s, loc.copy())
            keep(dt)

    b.iter[call_fn]()
    keep(src)
    keep(loc)


@parameter
def bench_parse_locale_long_libc(mut b: Bencher) raises:
    """Long locale-aware parse using the libc-backed locale."""
    comptime fmt = "%A %d %B %Y %I:%M:%S %p"
    var src = "Tuesday 28 April 2026 03:30:45 PM"
    var loc = LibCLocale("C")

    @always_inline
    @parameter
    def call_fn() raises:
        for _ in range(BATCH):
            var s = black_box(src)
            var dt = DateTime.parse[fmt, LibCLocale](s, loc.copy())
            keep(dt)

    b.iter[call_fn]()
    keep(src)
    keep(loc)


@parameter
def bench_parse_locale_c_recursion_native(mut b: Bencher) raises:
    """`%c` triggers `datetime_fmt[calendar]()` and recurses through several
    locale-aware codes."""
    comptime fmt = "%c"
    var src = "Tue, 28 Apr 2026 15:30:00 +0000"

    @always_inline
    @parameter
    def call_fn() raises:
        for _ in range(BATCH):
            var s = black_box(src)
            var dt = DateTime.parse[fmt, GenericEnglishDTLocale](
                s, GenericEnglishDTLocale()
            )
            keep(dt)

    b.iter[call_fn]()
    keep(src)


@parameter
def bench_parse_locale_c_recursion_libc(mut b: Bencher) raises:
    """`%c` triggers `datetime_fmt[calendar]()` and recurses through several
    locale-aware codes."""
    comptime fmt = "%c"
    var src = "Tue Apr 28 15:30:00 2026"
    var loc = LibCLocale("C")

    @always_inline
    @parameter
    def call_fn() raises:
        for _ in range(BATCH):
            var s = black_box(src)
            var dt = DateTime.parse[fmt, LibCLocale](s, loc.copy())
            keep(dt)

    b.iter[call_fn]()
    keep(src)
    keep(loc)


# ===----------------------------------------------------------------------=== #
# entry point
# ===----------------------------------------------------------------------=== #


def main() raises:
    var m = Bench(
        BenchConfig(num_repetitions=1, num_warmup_iters=100, max_iters=100)
    )
    var tput = [ThroughputMeasure(BenchMetric.elements, BATCH)]

    m.bench_function[bench_write_iso](BenchId("write_iso"), tput.copy())
    m.bench_function[bench_write_locale_short_native](
        BenchId("write_locale_short_native"), tput.copy()
    )
    m.bench_function[bench_write_locale_long_native](
        BenchId("write_locale_long_native"), tput.copy()
    )
    m.bench_function[bench_write_locale_short_libc](
        BenchId("write_locale_short_libc"), tput.copy()
    )
    m.bench_function[bench_write_locale_long_libc](
        BenchId("write_locale_long_libc"), tput.copy()
    )
    m.bench_function[bench_write_locale_c_recursion_native](
        BenchId("write_locale_c_recursion_native"), tput.copy()
    )
    m.bench_function[bench_write_locale_c_recursion_libc](
        BenchId("write_locale_c_recursion_libc"), tput.copy()
    )

    m.bench_function[bench_parse_iso](BenchId("parse_iso"), tput.copy())
    m.bench_function[bench_parse_locale_short_native](
        BenchId("parse_locale_short_native"), tput.copy()
    )
    m.bench_function[bench_parse_locale_long_native](
        BenchId("parse_locale_long_native"), tput.copy()
    )
    m.bench_function[bench_parse_locale_short_libc](
        BenchId("parse_locale_short_libc"), tput.copy()
    )
    m.bench_function[bench_parse_locale_long_libc](
        BenchId("parse_locale_long_libc"), tput.copy()
    )
    m.bench_function[bench_parse_locale_c_recursion_native](
        BenchId("parse_locale_c_recursion_native"), tput.copy()
    )
    m.bench_function[bench_parse_locale_c_recursion_libc](
        BenchId("parse_locale_c_recursion_libc"), tput.copy()
    )

    print(m)
