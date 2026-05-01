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
"""Benchmarks for `DateTime.write_to` and `DateTime.parse`.

Run via the `bench` pixi task. Use this baseline to measure the impact of
optimizations to the format / parse pipeline (e.g. the `DTLocale` slice-return
change) by comparing results across branches.

# Reproducibility

These ops are sub-microsecond, so noise from the host (CPU frequency scaling,
turbo, scheduler jitter, sibling load) easily swamps a 10-30% real change.
For a meaningful comparison across branches:

- Pin to a single physical core: `taskset -c 2 pixi run bench`.
- Set the governor to performance (root):
  `cpupower frequency-set -g performance`.
- Disable turbo to avoid frequency drift between repetitions:
  `echo 1 | sudo tee /sys/devices/system/cpu/intel_pstate/no_turbo`.
- Quiesce the box (close browser/IDE/sync clients).
- Run the bench three times back-to-back; trust the median per row.

Without those, treat the absolute numbers as soft and only compare
order-of-magnitude differences.
"""

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
from mojo_datetime.calendar import PythonCalendar
from mojo_datetime.locale import (
    _write_to,
    _parse,
    GenericEnglishDTLocale,
    LibCLocale,
    SpanishDTLocale,
)
from mojo_datetime._tz_naive_datetime import _TzNaiveDateTime
from mojo_datetime.zoneinfo import gregorian_zoneinfo

comptime BATCH = 1000
"""Inner-loop batch size: amortizes per-iteration timer overhead for the
sub-microsecond ops we're measuring."""

comptime FIXED_DT = _TzNaiveDateTime[PythonCalendar]({2026, 4, 28, 15, 30, 45})
"""A reference datetime used by every benchmark."""

# ===----------------------------------------------------------------------=== #
# write_to benchmarks
# ===----------------------------------------------------------------------=== #


comptime FIXED_DT_TZ = DateTime(2026, 4, 28, 15, 30, 45)
"""TZ-aware reference datetime used by the ISO write benchmark."""


@parameter
def bench_write_iso(mut b: Bencher) raises:
    """ISO-8601 datetime with TZ designator: no locale-aware codes."""
    comptime fmt = IsoFormat.YYYY_MM_DD_T_HH_MM_SS_TZD

    @always_inline
    @parameter
    def call_fn() raises:
        for _ in range(BATCH):
            var dt = black_box(FIXED_DT_TZ)
            var out = String()
            dt.write_to[fmt](out)
            keep(out.byte_length())

    b.iter[call_fn]()


@parameter
def bench_write_locale_short_native(mut b: Bencher) raises:
    """Short locale-aware format using the native English locale.

    Exercises `%a` and `%b` which call into `DTLocale.day_of_week_short` and
    `month_short`. Pre-PR these allocated; post-PR they return slices.
    """
    comptime fmt = "%a %d %b %Y %H:%M:%S"

    @always_inline
    @parameter
    def call_fn() raises:
        for _ in range(BATCH):
            var dt = black_box(FIXED_DT)
            var out = String()
            _write_to[fmt, "", GenericEnglishDTLocale](
                out, dt, {}, GenericEnglishDTLocale()
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
            _write_to[fmt, "", GenericEnglishDTLocale](
                out, dt, {}, GenericEnglishDTLocale()
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
            _write_to[fmt, "", SpanishDTLocale](out, dt, {}, SpanishDTLocale())
            keep(out.byte_length())

    b.iter[call_fn]()


@parameter
def bench_write_locale_short_libc(mut b: Bencher) raises:
    """Short locale-aware format using the libc-backed locale.

    The libc path is the worst-case allocator user pre-PR (every nl_langinfo
    return was wrapped in `String`).
    """
    var loc = LibCLocale("C")
    comptime fmt = "%a %d %b %Y %H:%M:%S"

    @always_inline
    @parameter
    def call_fn() raises:
        for _ in range(BATCH):
            var dt = black_box(FIXED_DT)
            var out = String()
            _write_to[fmt, "", LibCLocale](out, dt, {}, loc.copy())
            keep(out.byte_length())

    b.iter[call_fn]()
    keep(Bool(loc._loc))


@parameter
def bench_write_locale_c_recursion_native(mut b: Bencher) raises:
    """`%c` triggers `datetime_fmt[calendar]()` and recurses through several
    locale-aware codes. The deepest format hot path."""
    comptime fmt = "%c"

    @always_inline
    @parameter
    def call_fn() raises:
        for _ in range(BATCH):
            var dt = black_box(FIXED_DT)
            var out = String()
            _write_to[fmt, "", GenericEnglishDTLocale](
                out, dt, {}, GenericEnglishDTLocale()
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
            var dt = _parse[
                fmt, PythonCalendar, gregorian_zoneinfo, GenericEnglishDTLocale
            ](s, GenericEnglishDTLocale())
            keep(Int(dt.dt.year))

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
            var dt = _parse[
                fmt, PythonCalendar, gregorian_zoneinfo, GenericEnglishDTLocale
            ](s, GenericEnglishDTLocale())
            keep(Int(dt.dt.year))

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
            var dt = _parse[
                fmt, PythonCalendar, gregorian_zoneinfo, LibCLocale
            ](s, loc.copy())
            keep(Int(dt.dt.year))

    b.iter[call_fn]()
    keep(Bool(src))
    keep(Bool(loc._loc))


# ===----------------------------------------------------------------------=== #
# entry point
# ===----------------------------------------------------------------------=== #


def main() raises:
    # 25 repetitions × ~5 s each gives the harness enough samples to expose
    # >5% deltas above the host noise floor. See module docstring for tips on
    # quieting the host before trusting absolute numbers.
    var m = Bench(BenchConfig(num_repetitions=25, max_runtime_secs=5.0))

    # Each call_fn batches BATCH ops, so per-batch throughput in elements/s
    # gives us a single-figure ns-per-op number.
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
