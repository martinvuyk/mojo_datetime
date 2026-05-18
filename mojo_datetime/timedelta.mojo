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
](Comparable, ImplicitlyCopyable):
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
        comptime assert Self.dtype.is_unsigned()
        self.value = value

    @always_inline
    def __init__(out self, value: Int):
        """Construct a `TimeDelta`.

        Args:
            value: The value for the `TimeDelta`.
        """
        comptime assert Self.dtype.is_unsigned()
        assert value >= 0, "A `TimeDelta`'s value is expected to be >= 0"
        self.value = Scalar[Self.dtype](value)

    @always_inline
    def __init__(out self, value: UInt):
        """Construct a `TimeDelta`.

        Args:
            value: The value for the `TimeDelta`.
        """
        comptime assert Self.dtype.is_unsigned()
        self.value = Scalar[Self.dtype](value)

    @always_inline
    def __init__[
        v_dtype: DType = Self.dtype
    ](
        *, days: Scalar[v_dtype], out self: TimeDelta[SITimeUnit.DAYS, v_dtype]
    ) where v_dtype.is_unsigned():
        """Construct a `TimeDelta`.

        Parameters:
            v_dtype: The dtype of the value.

        Args:
            days: The value for the `TimeDelta`.
        """
        comptime assert v_dtype.is_unsigned()
        self.value = days

    @always_inline
    def __init__[
        v_dtype: DType = Self.dtype
    ](
        *,
        hours: Scalar[v_dtype],
        out self: TimeDelta[SITimeUnit.HOURS, v_dtype],
    ) where v_dtype.is_unsigned():
        """Construct a `TimeDelta`.

        Parameters:
            v_dtype: The dtype of the value.

        Args:
            hours: The value for the `TimeDelta`.
        """
        comptime assert v_dtype.is_unsigned()
        self.value = hours

    @always_inline
    def __init__[
        v_dtype: DType = Self.dtype
    ](
        *,
        minutes: Scalar[v_dtype],
        out self: TimeDelta[SITimeUnit.MINUTES, v_dtype],
    ) where v_dtype.is_unsigned():
        """Construct a `TimeDelta`.

        Parameters:
            v_dtype: The dtype of the value.

        Args:
            minutes: The value for the `TimeDelta`.
        """
        comptime assert v_dtype.is_unsigned()
        self.value = minutes

    @always_inline
    def __init__[
        v_dtype: DType = Self.dtype
    ](
        *,
        seconds: Scalar[v_dtype],
        out self: TimeDelta[SITimeUnit.SECONDS, v_dtype],
    ) where v_dtype.is_unsigned():
        """Construct a `TimeDelta`.

        Parameters:
            v_dtype: The dtype of the value.

        Args:
            seconds: The value for the `TimeDelta`.
        """
        comptime assert v_dtype.is_unsigned()
        self.value = seconds

    @always_inline
    def __init__[
        v_dtype: DType = Self.dtype
    ](
        *,
        milliseconds: Scalar[v_dtype],
        out self: TimeDelta[SITimeUnit.MILLISECONDS, v_dtype],
    ) where v_dtype.is_unsigned():
        """Construct a `TimeDelta`.

        Parameters:
            v_dtype: The dtype of the value.

        Args:
            milliseconds: The value for the `TimeDelta`.
        """
        comptime assert v_dtype.is_unsigned()
        self.value = milliseconds

    @always_inline
    def __init__[
        v_dtype: DType = Self.dtype
    ](
        *,
        microseconds: Scalar[v_dtype],
        out self: TimeDelta[SITimeUnit.MICROSECONDS, v_dtype],
    ) where v_dtype.is_unsigned():
        """Construct a `TimeDelta`.

        Parameters:
            v_dtype: The dtype of the value.

        Args:
            microseconds: The value for the `TimeDelta`.
        """
        comptime assert v_dtype.is_unsigned()
        self.value = microseconds

    @always_inline
    def __init__[
        v_dtype: DType = Self.dtype
    ](
        *,
        nanoseconds: Scalar[v_dtype],
        out self: TimeDelta[SITimeUnit.NANOSECONDS, v_dtype],
    ) where v_dtype.is_unsigned():
        """Construct a `TimeDelta`.

        Parameters:
            v_dtype: The dtype of the value.

        Args:
            nanoseconds: The value for the `TimeDelta`.
        """
        comptime assert v_dtype.is_unsigned()
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
