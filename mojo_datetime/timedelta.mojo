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
"""A module that defines a time-unit aware `TimeDelta`."""
from .calendar import Calendar, PythonCalendar, SITimeUnit


# FIXME(https://github.com/modular/modular/issues/6485): make this TrivialRegisterPassable
struct TimeDelta[
    unit: SITimeUnit = SITimeUnit.SECONDS, dtype: DType = DType.uint64
](Comparable, ImplicitlyCopyable, Writable) where dtype.is_unsigned():
    """A struct representing a positive (incl. 0) time delta.

    Parameters:
        unit: The time unit the `TimeDelta` contains.
        dtype: The datatype in which to store the delta in.
    """

    var value: Scalar[Self.dtype]
    """The raw time delta value."""

    @always_inline
    def __init__(out self, value: Scalar[Self.dtype]):
        """Construct a `TimeDelta`.

        Args:
            value: The value for the `TimeDelta`.
        """
        self.value = value

    @always_inline
    def __init__(out self, value: Int):
        """Construct a `TimeDelta`.

        Args:
            value: The value for the `TimeDelta`.
        """
        assert value >= 0, "A `TimeDelta`'s value is expected to be >= 0"
        self.value = Scalar[Self.dtype](value)

    @always_inline
    def __init__(out self, value: UInt):
        """Construct a `TimeDelta`.

        Args:
            value: The value for the `TimeDelta`.
        """
        self.value = Scalar[Self.dtype](value)

    @always_inline
    def __init__(
        *,
        days: Scalar[Self.dtype],
        out self: TimeDelta[SITimeUnit.DAYS, Self.dtype],
    ):
        """Construct a `Self.dtype`.

        Args:
            days: The value for the `TimeDelta`.
        """
        self.value = days

    @always_inline
    def __init__(
        *, days: IntLiteral, out self: TimeDelta[SITimeUnit.DAYS, Self.dtype]
    ):
        """Construct a `Self.dtype`.

        Args:
            days: The value for the `TimeDelta`.
        """
        comptime assert (
            type_of(days)() >= 0
        ), "A `TimeDelta`'s value is expected to be >= 0"
        self.value = days

    @always_inline
    def __init__(
        *,
        hours: Scalar[Self.dtype],
        out self: TimeDelta[SITimeUnit.HOURS, Self.dtype],
    ):
        """Construct a `TimeDelta`.

        Args:
            hours: The value for the `TimeDelta`.
        """
        self.value = hours

    @always_inline
    def __init__(
        *, hours: IntLiteral, out self: TimeDelta[SITimeUnit.HOURS, Self.dtype]
    ):
        """Construct a `Self.dtype`.

        Args:
            hours: The value for the `TimeDelta`.
        """
        comptime assert (
            type_of(hours)() >= 0
        ), "A `TimeDelta`'s value is expected to be >= 0"
        self.value = hours

    @always_inline
    def __init__(
        *,
        minutes: Scalar[Self.dtype],
        out self: TimeDelta[SITimeUnit.MINUTES, Self.dtype],
    ):
        """Construct a `TimeDelta`.

        Args:
            minutes: The value for the `TimeDelta`.
        """
        self.value = minutes

    @always_inline
    def __init__(
        *,
        minutes: IntLiteral,
        out self: TimeDelta[SITimeUnit.MINUTES, Self.dtype],
    ):
        """Construct a `Self.dtype`.

        Args:
            minutes: The value for the `TimeDelta`.
        """
        comptime assert (
            type_of(minutes)() >= 0
        ), "A `TimeDelta`'s value is expected to be >= 0"
        self.value = minutes

    @always_inline
    def __init__(
        *,
        seconds: Scalar[Self.dtype],
        out self: TimeDelta[SITimeUnit.SECONDS, Self.dtype],
    ):
        """Construct a `TimeDelta`.

        Args:
            seconds: The value for the `TimeDelta`.
        """
        self.value = seconds

    @always_inline
    def __init__(
        *,
        seconds: IntLiteral,
        out self: TimeDelta[SITimeUnit.SECONDS, Self.dtype],
    ):
        """Construct a `Self.dtype`.

        Args:
            seconds: The value for the `TimeDelta`.
        """
        comptime assert (
            type_of(seconds)() >= 0
        ), "A `TimeDelta`'s value is expected to be >= 0"
        self.value = seconds

    @always_inline
    def __init__(
        *,
        milliseconds: Scalar[Self.dtype],
        out self: TimeDelta[SITimeUnit.MILLISECONDS, Self.dtype],
    ):
        """Construct a `TimeDelta`.

        Args:
            milliseconds: The value for the `TimeDelta`.
        """
        self.value = milliseconds

    @always_inline
    def __init__(
        *,
        milliseconds: IntLiteral,
        out self: TimeDelta[SITimeUnit.MILLISECONDS, Self.dtype],
    ):
        """Construct a `Self.dtype`.

        Args:
            milliseconds: The value for the `TimeDelta`.
        """
        comptime assert (
            type_of(milliseconds)() >= 0
        ), "A `TimeDelta`'s value is expected to be >= 0"
        self.value = milliseconds

    @always_inline
    def __init__(
        *,
        microseconds: Scalar[Self.dtype],
        out self: TimeDelta[SITimeUnit.MICROSECONDS, Self.dtype],
    ):
        """Construct a `TimeDelta`.

        Args:
            microseconds: The value for the `TimeDelta`.
        """
        self.value = microseconds

    @always_inline
    def __init__(
        *,
        microseconds: IntLiteral,
        out self: TimeDelta[SITimeUnit.MICROSECONDS, Self.dtype],
    ):
        """Construct a `Self.dtype`.

        Args:
            microseconds: The value for the `TimeDelta`.
        """
        comptime assert (
            type_of(microseconds)() >= 0
        ), "A `TimeDelta`'s value is expected to be >= 0"
        self.value = microseconds

    @always_inline
    def __init__(
        *,
        nanoseconds: Scalar[Self.dtype],
        out self: TimeDelta[SITimeUnit.NANOSECONDS, Self.dtype],
    ):
        """Construct a `TimeDelta`.

        Args:
            nanoseconds: The value for the `TimeDelta`.
        """
        self.value = nanoseconds

    @always_inline
    def __init__(
        *,
        nanoseconds: IntLiteral,
        out self: TimeDelta[SITimeUnit.NANOSECONDS, Self.dtype],
    ):
        """Construct a `Self.dtype`.

        Args:
            nanoseconds: The value for the `TimeDelta`.
        """
        comptime assert (
            type_of(nanoseconds)() >= 0
        ), "A `TimeDelta`'s value is expected to be >= 0"
        self.value = nanoseconds

    @always_inline
    def __lt__(self, rhs: Self) -> Bool:
        """Define whether `self` is less than `rhs`.

        Args:
            rhs: The value to compare with.

        Returns:
            True if `self` is less than `rhs`.
        """
        return self.value < rhs.value

    @always_inline
    def __add__(self, rhs: Self) -> Self:
        """Computes `self + rhs`.

        Args:
            rhs: The rhs value.

        Returns:
            The result.
        """
        return {self.value + rhs.value}

    @always_inline
    def __sub__(self, rhs: Self) -> Self:
        """Computes `self - rhs`.

        Args:
            rhs: The rhs value.

        Returns:
            The result.
        """
        return {self.value - rhs.value}

    @always_inline
    def __mul__(self, rhs: Scalar[Self.dtype]) -> Self:
        """Computes `self.value * rhs`.

        Args:
            rhs: The rhs value.

        Returns:
            The result.
        """
        return {self.value * rhs}

    @always_inline
    def __imul__(mut self, rhs: Scalar[Self.dtype]):
        """Computes `self.value *= rhs`.

        Args:
            rhs: The rhs value.
        """
        self.value *= rhs

    @always_inline
    def __floordiv__(self, rhs: Scalar[Self.dtype]) -> Self:
        """Computes `self.value // rhs`.

        Args:
            rhs: The rhs value.

        Returns:
            The result.
        """
        return {self.value // rhs}

    @always_inline
    def __ifloordiv__(mut self, rhs: Scalar[Self.dtype]):
        """Computes `self.value //= rhs`.

        Args:
            rhs: The rhs value.
        """
        self.value //= rhs

    @always_inline
    def __mod__(self, rhs: Scalar[Self.dtype]) -> Self:
        """Computes `self.value % rhs`.

        Args:
            rhs: The rhs value.

        Returns:
            The result.
        """
        return {self.value % rhs}

    @always_inline
    def __imod__(mut self, rhs: Scalar[Self.dtype]):
        """Computes `self.value %= rhs`.

        Args:
            rhs: The rhs value.
        """
        self.value %= rhs
