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
            keep(out.byte_length())

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
            keep(out.byte_length())

    b.iter[call_fn]()


@parameter
def bench_write_locale_long_native(mut b: Bencher) raises:
    """Long locale-aware format using the native English locale.

    Exercises `%A`, `%B`, and `%p`.
    """
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
            keep(out.byte_length())

    b.iter[call_fn]()


@parameter
def bench_write_locale_short_spanish(mut b: Bencher) raises:
    """Short locale-aware format using a non-default native locale."""
    comptime fmt = "%a %d %b %Y %H:%M:%S"

    @always_inline
    @parameter
    def call_fn() raises:
        for _ in range(BATCH):
            var dt = black_box(FIXED_DT)
            var out = String()
            dt.write_to[fmt, SpanishDTLocale](out, SpanishDTLocale())
            keep(out.byte_length())

    b.iter[call_fn]()


@parameter
def bench_write_locale_short_libc(mut b: Bencher) raises:
    """Short locale-aware format using the libc-backed locale."""
    var loc = LibCLocale("C")
    comptime fmt = "%a %d %b %Y %H:%M:%S"

    @always_inline
    @parameter
    def call_fn() raises:
        for _ in range(BATCH):
            var dt = black_box(FIXED_DT)
            var out = String()
            dt.write_to[fmt, LibCLocale](out, loc.copy())
            keep(out.byte_length())

    b.iter[call_fn]()
    keep(Bool(loc._loc))


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
            keep(out.byte_length())

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
            keep(Int(dt.year))

    b.iter[call_fn]()
    keep(Bool(src))


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
            keep(Int(dt.year))

    b.iter[call_fn]()
    keep(Bool(src))


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
            keep(Int(dt.year))

    b.iter[call_fn]()
    keep(Bool(src))


@parameter
def bench_parse_locale_short_libc(mut b: Bencher) raises:
    """Short locale-aware parse using the libc-backed locale."""
    var loc = LibCLocale("C")
    comptime fmt = "%a %d %b %Y %H:%M:%S"
    var src = "Tue 28 Apr 2026 15:30:45"

    @always_inline
    @parameter
    def call_fn() raises:
        for _ in range(BATCH):
            var s = black_box(src)
            var dt = DateTime.parse[fmt, LibCLocale](s, loc.copy())
            keep(Int(dt.year))

    b.iter[call_fn]()
    keep(Bool(src))
    keep(Bool(loc._loc))


# ===----------------------------------------------------------------------=== #
# entry point
# ===----------------------------------------------------------------------=== #


def main() raises:
    var m = Bench(
        BenchConfig(
            num_repetitions=25, max_runtime_secs=5.0, num_warmup_iters=50
        )
    )
    var tput = [ThroughputMeasure(BenchMetric.elements, BATCH)]

    m.bench_function[bench_write_iso](BenchId("write_iso"), tput.copy())
    m.bench_function[bench_write_locale_short_native](
        BenchId("write_locale_short_native_en"), tput.copy()
    )
    m.bench_function[bench_write_locale_long_native](
        BenchId("write_locale_long_native_en"), tput.copy()
    )
    m.bench_function[bench_write_locale_short_spanish](
        BenchId("write_locale_short_native_es"), tput.copy()
    )
    m.bench_function[bench_write_locale_short_libc](
        BenchId("write_locale_short_libc_C"), tput.copy()
    )
    m.bench_function[bench_write_locale_c_recursion_native](
        BenchId("write_locale_c_recursion_native_en"), tput.copy()
    )

    m.bench_function[bench_parse_iso](BenchId("parse_iso"), tput.copy())
    m.bench_function[bench_parse_locale_short_native](
        BenchId("parse_locale_short_native_en"), tput.copy()
    )
    m.bench_function[bench_parse_locale_long_native](
        BenchId("parse_locale_long_native_en"), tput.copy()
    )
    m.bench_function[bench_parse_locale_short_libc](
        BenchId("parse_locale_short_libc_C"), tput^
    )

    print(m)
