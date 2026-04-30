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
"""`ZoneInfo` module."""


from ._tz_naive_datetime import _TzNaiveDateTime
from .calendar import _NaiveDateTime

# ===----------------------------------------------------------------------=== #
# UTC Offset
# ===----------------------------------------------------------------------=== #


struct Offset(Defaultable, Equatable, TrivialRegisterPassable, Writable):
    """An offset from UTC."""

    var hours: UInt8
    """Hours: [0, 15]."""
    var minutes: UInt8
    """Minutes: {0, 30, 45}."""
    var is_east_utc: Bool
    """Whether the offset is east of UTC."""

    @always_inline
    def __init__(out self):
        """Construct a UTC `Offset`."""
        self.hours = 0
        self.minutes = 0
        self.is_east_utc = True

    @always_inline
    def __init__(out self, *, from_hash: UInt8):
        """Construct an `Offset` from a hash.

        Args:
            from_hash: The hash.
        """

        self.is_east_utc = Bool(from_hash >> 6)
        self.hours = (from_hash >> 2) & 0b1111
        m = from_hash & 0b11
        self.minutes = UInt8(0) if m == 0 else (UInt8(30) if m == 1 else 45)

    @always_inline
    def __init__(out self, hour: UInt8, minute: UInt8, is_east_utc: Bool):
        """Construct an `Offset` from values.

        Args:
            hour: Hour.
            minute: Minute.
            is_east_utc: Whether the sign of the offset is east of UTC.
        """

        assert UInt8(0) <= hour < UInt8(24) and UInt8(0) <= minute < UInt8(
            60
        ), ("utc offset hours be in: [0, 24) and minutes in: [0, 60)",)

        self.hours = hour
        self.minutes = minute
        self.is_east_utc = is_east_utc

    @staticmethod
    def parse(iso_tzd_std: StringSlice) raises -> Tuple[Offset, Int]:
        """Construct an `Offset` for DST start/end.

        Args:
            iso_tzd_std: String with the ISO8601 TZD
                {`±hh:mm`, `±hhmm`, `±hh`} or a literal "Z" character.

        Notes:
            Using the `±hh` format is ambiguous and is not recommended unless
            it is at the end of the string, otherwise this implementation will
            raise because it will try to parse the next characters as the minute
            numeric values.
        """
        if iso_tzd_std.startswith("Z"):
            return Offset(), 1
        if iso_tzd_std.byte_length() < 3:
            raise Error("Offset string is too short.")
        var b0 = iso_tzd_std.unsafe_ptr()[0]
        comptime signs = SIMD[DType.uint8, 2](Byte(ord("+")), Byte(ord("-")))
        if b0 not in signs:
            raise Error("Offset doesn't start with a sign.")
        var offset = Offset(
            UInt8(atol(iso_tzd_std[byte=1:2])), 0, b0 == signs[0]
        )
        if iso_tzd_std.byte_length() == 3:
            return offset, 3
        var idx = 3 + Int(iso_tzd_std.unsafe_ptr()[3] == Byte(ord(":")))
        var length = idx + 2
        if iso_tzd_std.byte_length() < length:
            raise Error("Offset minute section is too short.")
        offset.minutes = UInt8(atol(iso_tzd_std[byte=idx:length]))
        return offset, length

    @always_inline
    def hash(self) -> UInt8:
        """Create a hash for the `Offset` (7 bits total).

        Returns:
            The hash for the `Offset`.
        """
        var m = UInt8(1) if self.minutes == 30 else (
            UInt8(2) if self.minutes == 45 else 0
        )
        return (UInt8(self.is_east_utc) << 6) | (self.hours << 2) | m

    def write_to(self, mut writer: Some[Writer]):
        """Write the UTCOffset's [ISO 8601](
        https://es.wikipedia.org/wiki/ISO_8601) representation (full format e.g.
        `+00:00`).

        Args:
            writer: The writer.
        """

        h = self.hours
        m = self.minutes

        writer.write(
            "-" if not self.is_east_utc and not (h == 0 and m == 0) else "+"
        )
        writer.write("0" if h < 10 else "", h)
        writer.write(":")
        writer.write("0" if m < 10 else "", m)

    @always_inline
    def __eq__(self, other: Self) -> Bool:
        """Whether the given Offset is equal to self.

        Args:
            other: The other Offset.

        Returns:
            The result.
        """
        return self.hash() == other.hash()

    @always_inline
    def __lt__(self, other: Self) -> Bool:
        """Whether self is less than other.

        Args:
            other: The other Offset.

        Returns:
            The result.
        """
        return (self.is_east_utc, self.hours, self.minutes) < (
            other.is_east_utc,
            other.hours,
            other.minutes,
        )

    @always_inline
    def local_to_utc(self, dt: _TzNaiveDateTime) -> type_of(dt):
        """Translate the local time to UTC according to the `Offset`.

        Args:
            dt: The naive datetime.
        """
        if not self.is_east_utc:
            return dt.add(
                hours=UInt64(self.hours), minutes=UInt64(self.minutes)
            )
        else:
            return dt.subtract(
                hours=UInt64(self.hours), minutes=UInt64(self.minutes)
            )

    @always_inline
    def utc_to_local(self, dt: _TzNaiveDateTime) -> type_of(dt):
        """Translate the UTC time to local according to the `Offset`.

        Args:
            dt: The naive datetime.
        """
        return (-self).local_to_utc(dt)

    @always_inline
    def __neg__(self) -> Self:
        """Negate the utc offset.

        Returns:
            The same UTC offset with the sign changed.
        """
        var new = self.copy()
        new.is_east_utc = not new.is_east_utc
        return new

    def __add__(self, other: Self) -> Self:
        """Add self to other.

        Args:
            other: The other.

        Returns:
            The result.
        """
        if self.is_east_utc == other.is_east_utc:
            return {
                self.hours + other.hours,
                self.minutes + other.minutes,
                self.is_east_utc,
            }
        elif self < other:
            return {
                other.hours - self.hours,
                other.minutes - self.minutes,
                other.is_east_utc,
            }
        else:
            return {
                self.hours - other.hours,
                self.minutes - other.minutes,
                self.is_east_utc,
            }

    @always_inline
    def __iadd__(mut self, other: Self):
        """Add self to other.

        Args:
            other: The other.
        """
        self = self + other


# ===----------------------------------------------------------------------=== #
# Transition rules
# ===----------------------------------------------------------------------=== #


@fieldwise_init
struct TRef(Equatable, TrivialRegisterPassable, Writable):
    """The time reference type."""

    comptime UTC = Self(0)
    """UTC time."""
    comptime STD = Self(1)
    """Standard time (local time)."""
    comptime DST = Self(2)
    """Daylight savings time (local time)."""
    var _value: UInt8


@fieldwise_init
struct TzDT(Equatable, TrivialRegisterPassable, Writable):
    """UTC time zone daylight savings time rule stores the rule for DST
    start/end. The rules are expected to be expressed in terms of UTC."""

    var month: UInt8
    """Month: Month: [1, 12]."""
    var day_of_week: UInt8
    """Day of week: [0, 6] (monday - sunday)."""
    var from_end_of_month: Bool
    """Whether to count from the beginning of the month or the end."""
    var first_week: Bool
    """If first_week=True -> first week of the month,
    if it's first_week=False -> second week. In the case that
    from_end_of_month=False, first_week=True -> last week of the month
    and first_week=False -> second to last."""
    var hour: UInt8
    """Hour: [0, 23] Hour at which DST starts/ends."""
    var t_ref: TRef
    """The type of reference."""

    @always_inline
    def __init__(out self, *, from_hash: UInt16):
        """Get the values from hash.

        Args:
            from_hash: The hash.
        """

        self.month = (UInt8(from_hash >> 12) & 0b1111) + 1
        self.day_of_week = UInt8(from_hash >> 9) & 0b111
        self.from_end_of_month = Bool((from_hash >> 8) & 0b1)
        self.first_week = Bool((from_hash >> 7) & 0b1)
        self.hour = UInt8((from_hash >> 2) & 0b11111)
        self.t_ref = {UInt8(from_hash & 0b11)}

    @always_inline
    def hash(self) -> UInt16:
        """Create a hash for the `TzDT` (16 bits total).

        Returns:
            The hash for the `TzDT`.
        """

        var mon = UInt16(self.month - 1)
        var d = UInt16(self.day_of_week)
        var eo = UInt16(self.from_end_of_month)
        var w = UInt16(self.first_week)
        var h = UInt16(self.hour)
        var t_ref = UInt16(self.t_ref._value)

        return (mon << 12) | (d << 9) | (eo << 8) | (w << 7) | (h << 2) | t_ref

    @always_inline
    def __eq__(self, other: Self) -> Bool:
        """Eq.

        Args:
            other: Other.

        Returns:
            Bool.
        """
        return self.hash() == other.hash()


# ===----------------------------------------------------------------------=== #
# Zone info
# ===----------------------------------------------------------------------=== #


trait UTCZoneInfo(Defaultable, Equatable, TrivialRegisterPassable):
    def offset_at_local_time(self, dt: _TzNaiveDateTime) -> Offset:
        """Return the UTC offset for the `TimeZone` at the given date.

        Args:
            dt: The naive datetime.

        Returns:
            The offset.
        """
        ...

    def offset_at_utc_time(self, dt: _TzNaiveDateTime) -> Offset:
        """Return the UTC offset for the `TimeZone` at the given date.

        Args:
            dt: The naive datetime.

        Returns:
            The offset.
        """
        ...


struct ZoneInfo(UTCZoneInfo):
    """`ZoneInfo` stores both start and end dates of DST (in case there
    is one), and the offset for standard time and dailight savings time for the
    given timezone.
    """

    var _hash: UInt64

    @always_inline
    def __init__(out self):
        """Construct a default `ZoneInfo`."""
        self = Self(Offset(0, 0, True))

    @always_inline
    def __init__(out self, *, from_hash: UInt64):
        """Construct a `ZoneDST` from a buffer.

        Args:
            from_hash: The buffer.
        """
        self._hash = from_hash

    def __init__(
        out self,
        dst_start: TzDT,
        dst_end: TzDT,
        std_offset: Offset,
        dst_offset: Optional[Offset] = None,
    ):
        """Construct a `ZoneDST` for a timezone with DST.

        Args:
            dst_start: TzDT, is expected to be in local time.
            dst_end: TzDT, is expected to be in local time.
            std_offset: The standard time Offset.
            dst_offset: The daylight savings time Offset, defaults to std + an
                hour (agnostic of east or west of UTC).
        """
        var dst = dst_offset.or_else(std_offset)
        if not dst_offset:
            dst.hours += 1
        self._hash = (
            (UInt64(dst_start.hash()) << (32 + 16))
            | (UInt64(dst_end.hash()) << 32)
            | (UInt64(std_offset.hash()) << 8)
            | UInt64(dst.hash())
        )

    @always_inline
    def __init__(out self, offset: Offset):
        """Construct a `ZoneDST` for a timezone with no DST.

        Args:
            offset: Offset.
        """
        var h = UInt64(offset.hash())
        self._hash = (h << 8) | h

    @always_inline
    def parse(self) -> Tuple[TzDT, TzDT, Offset, Offset]:
        """Get the values from hash.

        Returns:
            The values for (dst_start, dst_end, std_offset, dst_offset).
        """

        comptime b16 = 0b1111_1111_1111_1111
        comptime b8 = 0b1111_1111
        return (
            TzDT(from_hash=UInt16((self._hash >> (32 + 16)) & b16)),
            TzDT(from_hash=UInt16((self._hash >> 32) & b16)),
            Offset(from_hash=UInt8((self._hash >> 8) & b8)),
            Offset(from_hash=UInt8(self._hash & b8)),
        )

    @staticmethod
    def get_datetime_for_relative_rule(
        reference_dt: _TzNaiveDateTime, rule: TzDT, std: Offset, dst: Offset
    ) -> type_of(reference_dt):
        """Return the datetime for the relative rule at the given reference
        UTC datetime.

        Args:
            reference_dt: The reference naive datetime.
            rule: The DST/STD transition rule.
            std: The std offset.
            dst: The dst offset.

        Returns:
            The UTC datetime the relative transition rule falls in for the given
            reference datetime.
        """
        var is_end_mon = rule.from_end_of_month
        var dt = type_of(reference_dt)(
            {reference_dt.dt.year, rule.month, 1, rule.hour}
        )

        var maxdays = dt.calendar.max_days_in_month(dt.dt)
        var iterable = range(0, Int(maxdays), step=1)
        if is_end_mon:
            iterable = range(Int(maxdays - 1), -1, step=-1)

        var is_first_week = True
        for i in iterable:
            dt.dt.day = UInt8(i + 1)
            if dt.calendar.day_of_week(dt.dt) == rule.day_of_week:
                if is_first_week == rule.first_week:
                    break  # we found it
                is_first_week = False

        if rule.t_ref == TRef.UTC:
            return dt

        return (std if rule.t_ref == TRef.STD else dst).local_to_utc(dt)

    def offset_at_local_time(self, dt: _TzNaiveDateTime) -> Offset:
        """Return the UTC offset for the `TimeZone` at the given date.

        Args:
            dt: The naive datetime.

        Returns:
            The offset.

        Notes:
            During the overlap time (usually an hour) between the transition
            from daylight savings time to standard time, the earlier offset
            is returned (daylight savings time).
        """
        ref _, _, std, dst = self.parse()

        var offset_1 = self.offset_at_utc_time(std.local_to_utc(dt))
        var offset_2 = self.offset_at_utc_time(dst.local_to_utc(dt))

        if offset_1 == std and offset_2 == dst:  # overlap
            return dst
        elif offset_1 == std:
            return std
        else:
            return dst

    def offset_at_utc_time(self, dt: _TzNaiveDateTime) -> Offset:
        """Return the UTC offset for the `TimeZone` at the given date.

        Args:
            dt: The datetime.

        Returns:
            The offset.
        """
        ref dst_start, dst_end, std, dst = self.parse()
        if dst_start == dst_end:
            return std

        var dst_start_dt = Self.get_datetime_for_relative_rule(
            dt, dst_start, std, dst
        )
        var dst_end_dt = Self.get_datetime_for_relative_rule(
            dt, dst_end, std, dst
        )

        if dst_start_dt < dst_end_dt:  # Northern
            return dst if dst_start_dt < dt <= dst_end_dt else std
        else:  # Southern
            return dst if dt > dst_start_dt or dt <= dst_end_dt else std


# ===----------------------------------------------------------------------=== #
# Offset Constants
# ===----------------------------------------------------------------------=== #

comptime `-12:00` = Offset(12, 0, False)
"""Raw offset from UTC."""
comptime `-11:00` = Offset(11, 0, False)
"""Raw offset from UTC."""
comptime `-10:00` = Offset(10, 0, False)
"""Raw offset from UTC."""
comptime `-09:30` = Offset(9, 30, False)
"""Raw offset from UTC."""
comptime `-09:00` = Offset(9, 0, False)
"""Raw offset from UTC."""
comptime `-08:00` = Offset(8, 0, False)
"""Raw offset from UTC."""
comptime `-07:00` = Offset(7, 0, False)
"""Raw offset from UTC."""
comptime `-06:00` = Offset(6, 0, False)
"""Raw offset from UTC."""
comptime `-05:00` = Offset(5, 0, False)
"""Raw offset from UTC."""
comptime `-04:00` = Offset(4, 0, False)
"""Raw offset from UTC."""
comptime `-03:30` = Offset(3, 30, False)
"""Raw offset from UTC."""
comptime `-03:00` = Offset(3, 0, False)
"""Raw offset from UTC."""
comptime `-02:00` = Offset(2, 0, False)
"""Raw offset from UTC."""
comptime `-01:00` = Offset(1, 0, False)
"""Raw offset from UTC."""

comptime `+00:00` = Offset(0, 0, True)
"""Raw offset from UTC."""

comptime `+01:00` = Offset(1, 0, True)
"""Raw offset from UTC."""
comptime `+02:00` = Offset(2, 0, True)
"""Raw offset from UTC."""
comptime `+03:00` = Offset(3, 0, True)
"""Raw offset from UTC."""
comptime `+03:30` = Offset(3, 30, True)
"""Raw offset from UTC."""
comptime `+04:00` = Offset(4, 0, True)
"""Raw offset from UTC."""
comptime `+04:30` = Offset(4, 30, True)
"""Raw offset from UTC."""
comptime `+05:00` = Offset(5, 0, True)
"""Raw offset from UTC."""
comptime `+05:30` = Offset(5, 30, True)
"""Raw offset from UTC."""
comptime `+05:45` = Offset(5, 45, True)
"""Raw offset from UTC."""
comptime `+06:00` = Offset(6, 0, True)
"""Raw offset from UTC."""
comptime `+06:30` = Offset(6, 30, True)
"""Raw offset from UTC."""
comptime `+07:00` = Offset(7, 0, True)
"""Raw offset from UTC."""
comptime `+08:00` = Offset(8, 0, True)
"""Raw offset from UTC."""
comptime `+08:45` = Offset(8, 45, True)
"""Raw offset from UTC."""
comptime `+09:00` = Offset(9, 0, True)
"""Raw offset from UTC."""
comptime `+09:30` = Offset(9, 30, True)
"""Raw offset from UTC."""
comptime `+10:00` = Offset(10, 0, True)
"""Raw offset from UTC."""
comptime `+10:30` = Offset(10, 30, True)
"""Raw offset from UTC."""
comptime `+11:00` = Offset(11, 0, True)
"""Raw offset from UTC."""
comptime `+12:00` = Offset(12, 0, True)
"""Raw offset from UTC."""
comptime `+12:45` = Offset(12, 45, True)
"""Raw offset from UTC."""
comptime `+13:00` = Offset(13, 0, True)
"""Raw offset from UTC."""
comptime `+14:00` = Offset(14, 0, True)
"""Raw offset from UTC."""


# ===----------------------------------------------------------------------=== #
# ZoneInfo constants
# ===----------------------------------------------------------------------=== #

# TODO: check these sources

comptime _eu_dst_start = TzDT(3, 6, True, True, 1, TRef.UTC)
"""Europe: Last Sunday of March at 01:00 UTC. [Source](
https://en.wikipedia.org/wiki/Summer_Time_in_Europe
)."""
comptime _eu_dst_end = TzDT(10, 6, True, True, 1, TRef.UTC)
"""Europe: Last Sunday of October at 01:00 UTC. [Source](
https://en.wikipedia.org/wiki/Summer_Time_in_Europe
)."""
comptime _zone_eu_minus_2 = ZoneInfo(_eu_dst_start, _eu_dst_end, `-02:00`)
"""Greenland (Nuuk) transitioned to EU rules in 2023. [Source](
https://en.wikipedia.org/wiki/Time_in_Greenland
)."""
comptime _zone_eu_minus_1 = ZoneInfo(_eu_dst_start, _eu_dst_end, `-01:00`)
comptime _zone_eu_0 = ZoneInfo(_eu_dst_start, _eu_dst_end, `+00:00`)
comptime _zone_eu_1 = ZoneInfo(_eu_dst_start, _eu_dst_end, `+01:00`)
comptime _zone_eu_2 = ZoneInfo(_eu_dst_start, _eu_dst_end, `+02:00`)

comptime _us_dst_start = TzDT(3, 6, False, False, 2, TRef.STD)
"""United States/Canada: 2nd Sunday of March at 02:00 STD. [Source](
https://en.wikipedia.org/wiki/Daylight_saving_time_in_the_United_States
)."""
comptime _us_dst_end = TzDT(11, 6, False, True, 2, TRef.DST)
"""United States/Canada: 1st Sunday of November at 02:00 DST. [Source](
https://en.wikipedia.org/wiki/Daylight_saving_time_in_the_United_States
)."""
comptime _zone_us_3 = ZoneInfo(_us_dst_start, _us_dst_end, `-03:00`)
"""Miquelon uses North American DST rules with UTC-3. [Source](
https://en.wikipedia.org/wiki/Time_in_France#Overseas_territories
)."""
comptime _zone_us_3_30 = ZoneInfo(_us_dst_start, _us_dst_end, `-03:30`)
comptime _zone_us_4 = ZoneInfo(_us_dst_start, _us_dst_end, `-04:00`)
comptime _zone_us_5 = ZoneInfo(_us_dst_start, _us_dst_end, `-05:00`)
comptime _zone_us_6 = ZoneInfo(_us_dst_start, _us_dst_end, `-06:00`)
comptime _zone_us_7 = ZoneInfo(_us_dst_start, _us_dst_end, `-07:00`)
comptime _zone_us_8 = ZoneInfo(_us_dst_start, _us_dst_end, `-08:00`)
comptime _zone_us_9 = ZoneInfo(_us_dst_start, _us_dst_end, `-09:00`)
comptime _zone_us_10 = ZoneInfo(_us_dst_start, _us_dst_end, `-10:00`)

comptime _au_dst_start = TzDT(10, 6, False, True, 2, TRef.STD)
"""Australia: 1st Sunday of October at 02:00 STD. [Source](
https://en.wikipedia.org/wiki/Daylight_saving_time_in_Australia
)."""
comptime _au_dst_end = TzDT(4, 6, False, True, 3, TRef.DST)
"""Australia: 1st Sunday of April at 03:00 DST. [Source](
https://en.wikipedia.org/wiki/Daylight_saving_time_in_Australia
)."""
comptime _zone_au_9_30 = ZoneInfo(_au_dst_start, _au_dst_end, `+09:30`)
comptime _zone_au_10 = ZoneInfo(_au_dst_start, _au_dst_end, `+10:00`)
comptime _zone_au_11 = ZoneInfo(_au_dst_start, _au_dst_end, `+11:00`)

comptime _nz_dst_start = TzDT(9, 6, True, True, 2, TRef.STD)
"""New Zealand: Last Sunday of September at 02:00 STD. [Source](
https://en.wikipedia.org/wiki/Time_in_New_Zealand
)."""
comptime _nz_dst_end = TzDT(4, 6, False, True, 3, TRef.DST)
"""New Zealand: 1st Sunday of April at 03:00 DST. [Source](
https://en.wikipedia.org/wiki/Time_in_New_Zealand
)."""
comptime _zone_nz_12 = ZoneInfo(_nz_dst_start, _nz_dst_end, `+12:00`)
comptime _zone_nz_12_45 = ZoneInfo(_nz_dst_start, _nz_dst_end, `+12:45`)

comptime _egypt_dst_start = TzDT(4, 4, True, True, 0, TRef.STD)
comptime _egypt_dst_end = TzDT(10, 3, True, True, 21, TRef.UTC)
comptime _zone_egypt = ZoneInfo(_egypt_dst_start, _egypt_dst_end, `+02:00`)
"""Start: Last Friday of April 00:00 STD.
End: Last Thursday of October 24:00 DST (21:00 UTC).
[Source](https://en.wikipedia.org/wiki/Daylight_saving_time_in_Egypt)."""

comptime _cuba_dst_start = TzDT(3, 6, False, False, 0, TRef.STD)
comptime _cuba_dst_end = TzDT(11, 6, False, True, 1, TRef.DST)
comptime _zone_cuba = ZoneInfo(_cuba_dst_start, _cuba_dst_end, `-05:00`)
"""Start: 2nd Sunday of March at 00:00 STD.
End: 1st Sunday of November at 01:00 DST.
[Source](https://en.wikipedia.org/wiki/Time_in_Cuba)."""

comptime _chile_dst_start = TzDT(9, 6, False, True, 0, TRef.STD)
comptime _chile_dst_end = TzDT(4, 6, False, True, 0, TRef.STD)
comptime _zone_chile = ZoneInfo(_chile_dst_start, _chile_dst_end, `-04:00`)
"""Start: 1st Sunday of September at 24:00 STD (Sunday 00:00).
End: 1st Sunday of April at 24:00 DST (Sunday 00:00).
[Source](https://en.wikipedia.org/wiki/Time_in_Chile)."""

comptime _easter_dst_start = TzDT(9, 6, False, True, 22, TRef.STD)
comptime _easter_dst_end = TzDT(4, 6, False, True, 22, TRef.STD)
comptime _zone_easter = ZoneInfo(_easter_dst_start, _easter_dst_end, `-06:00`)
"""Start: 1st Saturday of April at 22:00 DST.
End: 1st Saturday of April at 22:00 DST.
[Source](https://en.wikipedia.org/wiki/Time_in_Chile)."""

comptime _lebanon_dst_start = TzDT(3, 6, True, True, 0, TRef.STD)
comptime _lebanon_dst_end = TzDT(10, 6, True, True, 0, TRef.STD)
comptime _zone_lebanon = ZoneInfo(
    _lebanon_dst_start, _lebanon_dst_end, `+02:00`
)
"""Start: Last Sunday of March at 00:00 STD.
End: Last Sunday of October at 00:00 STD.
[Source](https://en.wikipedia.org/wiki/Time_in_Lebanon)."""

comptime _zone_lord_howe = ZoneInfo(
    _au_dst_start, _au_dst_end, `+10:30`, `+11:00`
)
"""Lord Howe island uses Australian DST rules but uniquely jumps forward 30
minutes. [Source](https://en.wikipedia.org/wiki/Lord_Howe_Island)."""

comptime _zone_troll = ZoneInfo(_eu_dst_start, _eu_dst_end, `+00:00`, `+02:00`)
"""Troll Research Station in Antarctica aligns with Europe, jumping 2 hours
forward for DST. [Source](
https://en.wikipedia.org/wiki/Troll_(research_station))."""

# ===----------------------------------------------------------------------=== #
# timezone strings and zone info
# ===----------------------------------------------------------------------=== #

# fmt: off
comptime gregorian_zoneinfo: Dict[String, ZoneInfo] = {
    # Africa
    "Africa/Abidjan": {`+00:00`},
    "Africa/Algiers": {`+01:00`},
    "Africa/Bissau": {`+00:00`},
    "Africa/Cairo": _zone_egypt, 
    "Africa/Ceuta": _zone_eu_1,
    "Africa/El_Aaiun": {`+01:00`},
    "Africa/Johannesburg": {`+02:00`},
    "Africa/Juba": {`+02:00`},
    "Africa/Khartoum": {`+02:00`},
    "Africa/Lagos": {`+01:00`},
    "Africa/Maputo": {`+02:00`},
    "Africa/Monrovia": {`+00:00`},
    "Africa/Nairobi": {`+03:00`},
    "Africa/Ndjamena": {`+01:00`},
    "Africa/Sao_Tome": {`+00:00`},
    "Africa/Tripoli": {`+02:00`},
    "Africa/Tunis": {`+01:00`},
    "Africa/Windhoek": {`+02:00`},

    # America
    "America/Adak": _zone_us_10,
    "America/Anchorage": _zone_us_9,
    "America/Araguaina": {`-03:00`},
    "America/Argentina/Buenos_Aires": {`-03:00`},
    "America/Argentina/Catamarca": {`-03:00`},
    "America/Argentina/Cordoba": {`-03:00`},
    "America/Argentina/Jujuy": {`-03:00`},
    "America/Argentina/La_Rioja": {`-03:00`},
    "America/Argentina/Mendoza": {`-03:00`},
    "America/Argentina/Rio_Gallegos": {`-03:00`},
    "America/Argentina/Salta": {`-03:00`},
    "America/Argentina/San_Juan": {`-03:00`},
    "America/Argentina/San_Luis": {`-03:00`},
    "America/Argentina/Tucuman": {`-03:00`},
    "America/Argentina/Ushuaia": {`-03:00`},
    "America/Asuncion": {`-03:00`}, 
    "America/Bahia": {`-03:00`},
    "America/Bahia_Banderas": {`-06:00`},
    "America/Barbados": {`-04:00`},
    "America/Belem": {`-03:00`},
    "America/Belize": {`-06:00`},
    "America/Boa_Vista": {`-04:00`},
    "America/Bogota": {`-05:00`},
    "America/Boise": _zone_us_7,
    "America/Cambridge_Bay": _zone_us_7,
    "America/Campo_Grande": {`-04:00`},
    "America/Cancun": {`-05:00`},
    "America/Caracas": {`-04:00`},
    "America/Cayenne": {`-03:00`},
    "America/Chicago": _zone_us_6,
    "America/Chihuahua": {`-06:00`},
    "America/Ciudad_Juarez": _zone_us_7,
    "America/Costa_Rica": {`-06:00`},
    "America/Cuiaba": {`-04:00`},
    "America/Danmarkshavn": {`+00:00`},
    "America/Dawson": {`-07:00`},
    "America/Dawson_Creek": {`-07:00`},
    "America/Denver": _zone_us_7,
    "America/Detroit": _zone_us_5,
    "America/Edmonton": _zone_us_7,
    "America/Eirunepe": {`-05:00`},
    "America/El_Salvador": {`-06:00`},
    "America/Fort_Nelson": {`-07:00`},
    "America/Fortaleza": {`-03:00`},
    "America/Glace_Bay": _zone_us_4,
    "America/Goose_Bay": _zone_us_4,
    "America/Grand_Turk": _zone_us_5,
    "America/Guatemala": {`-06:00`},
    "America/Guayaquil": {`-05:00`},
    "America/Guyana": {`-04:00`},
    "America/Halifax": _zone_us_4,
    "America/Havana": _zone_cuba,
    "America/Hermosillo": {`-07:00`},
    "America/Indiana/Indianapolis": _zone_us_5,
    "America/Indiana/Knox": _zone_us_6,
    "America/Indiana/Marengo": _zone_us_5,
    "America/Indiana/Petersburg": _zone_us_5,
    "America/Indiana/Tell_City": _zone_us_6,
    "America/Indiana/Vevay": _zone_us_5,
    "America/Indiana/Vincennes": _zone_us_5,
    "America/Indiana/Winamac": _zone_us_5,
    "America/Inuvik": _zone_us_7,
    "America/Iqaluit": _zone_us_5,
    "America/Jamaica": {`-05:00`},
    "America/Juneau": _zone_us_9,
    "America/Kentucky/Louisville": _zone_us_5,
    "America/Kentucky/Monticello": _zone_us_5,
    "America/La_Paz": {`-04:00`},
    "America/Lima": {`-05:00`},
    "America/Los_Angeles": _zone_us_8,
    "America/Maceio": {`-03:00`},
    "America/Managua": {`-06:00`},
    "America/Manaus": {`-04:00`},
    "America/Martinique": {`-04:00`},
    "America/Matamoros": _zone_us_6,
    "America/Mazatlan": {`-07:00`},
    "America/Menominee": _zone_us_6,
    "America/Merida": {`-06:00`},
    "America/Metlakatla": {`-09:00`},
    "America/Mexico_City": {`-06:00`},
    "America/Miquelon": _zone_us_3,
    "America/Moncton": _zone_us_4,
    "America/Monterrey": {`-06:00`},
    "America/Montevideo": {`-03:00`},
    "America/New_York": _zone_us_5,
    "America/Nome": _zone_us_9,
    "America/Noronha": {`-02:00`},
    "America/North_Dakota/Beulah": _zone_us_6,
    "America/North_Dakota/Center": _zone_us_6,
    "America/North_Dakota/New_Salem": _zone_us_6,
    "America/Nuuk": _zone_eu_minus_2,
    "America/Ojinaga": _zone_us_6,
    "America/Panama": {`-05:00`},
    "America/Paramaribo": {`-03:00`},
    "America/Phoenix": {`-07:00`},
    "America/Port-au-Prince": _zone_us_5,
    "America/Porto_Velho": {`-04:00`},
    "America/Puerto_Rico": {`-04:00`},
    "America/Punta_Arenas": {`-03:00`}, 
    "America/Rankin_Inlet": _zone_us_6,
    "America/Recife": {`-03:00`},
    "America/Regina": {`-06:00`},
    "America/Resolute": _zone_us_6,
    "America/Rio_Branco": {`-05:00`},
    "America/Santarem": {`-03:00`},
    "America/Santiago": _zone_chile,
    "America/Santo_Domingo": {`-04:00`},
    "America/Sao_Paulo": {`-03:00`},
    "America/Scoresbysund": _zone_eu_minus_1,
    "America/Sitka": _zone_us_9,
    "America/St_Johns": _zone_us_3_30,
    "America/Swift_Current": {`-06:00`},
    "America/Tegucigalpa": {`-06:00`},
    "America/Thule": _zone_us_4,
    "America/Tijuana": _zone_us_8,
    "America/Toronto": _zone_us_5,
    "America/Vancouver": _zone_us_8,
    "America/Whitehorse": {`-07:00`},
    "America/Winnipeg": _zone_us_6,
    "America/Yakutat": _zone_us_9,

    # Antarctica
    "Antarctica/Casey": {`+08:00`},
    "Antarctica/Davis": {`+07:00`},
    "Antarctica/Macquarie": {`+11:00`},
    "Antarctica/Mawson": {`+05:00`},
    "Antarctica/Palmer": _zone_chile,
    "Antarctica/Rothera": {`-03:00`},
    "Antarctica/Troll": _zone_troll,

    # Asia
    "Asia/Almaty": {`+05:00`},
    "Asia/Amman": {`+03:00`},
    "Asia/Anadyr": {`+12:00`},
    "Asia/Aqtau": {`+05:00`},
    "Asia/Aqtobe": {`+05:00`},
    "Asia/Ashgabat": {`+05:00`},
    "Asia/Atyrau": {`+05:00`},
    "Asia/Baghdad": {`+03:00`},
    "Asia/Baku": {`+04:00`},
    "Asia/Bangkok": {`+07:00`},
    "Asia/Barnaul": {`+07:00`},
    "Asia/Beirut": _zone_lebanon,
    "Asia/Bishkek": {`+06:00`},
    "Asia/Chita": {`+09:00`},
    "Asia/Choibalsan": {`+08:00`},
    "Asia/Colombo": {`+05:30`},
    "Asia/Damascus": {`+03:00`},
    "Asia/Dhaka": {`+06:00`},
    "Asia/Dili": {`+09:00`},
    "Asia/Dubai": {`+04:00`},
    "Asia/Dushanbe": {`+05:00`},
    "Asia/Famagusta": _zone_eu_2,
    "Asia/Ho_Chi_Minh": {`+07:00`},
    "Asia/Hong_Kong": {`+08:00`},
    "Asia/Hovd": {`+07:00`},
    "Asia/Irkutsk": {`+08:00`},
    "Asia/Jakarta": {`+07:00`},
    "Asia/Jayapura": {`+09:00`},
    "Asia/Kabul": {`+04:30`},
    "Asia/Kamchatka": {`+12:00`},
    "Asia/Karachi": {`+05:00`},
    "Asia/Kathmandu": {`+05:45`},
    "Asia/Khandyga": {`+09:00`},
    "Asia/Kolkata": {`+05:30`},
    "Asia/Krasnoyarsk": {`+07:00`},
    "Asia/Kuching": {`+08:00`},
    "Asia/Macau": {`+08:00`},
    "Asia/Magadan": {`+11:00`},
    "Asia/Makassar": {`+08:00`},
    "Asia/Manila": {`+08:00`},
    "Asia/Nicosia": _zone_eu_2,
    "Asia/Novokuznetsk": {`+07:00`},
    "Asia/Novosibirsk": {`+07:00`},
    "Asia/Omsk": {`+06:00`},
    "Asia/Oral": {`+05:00`},
    "Asia/Pontianak": {`+07:00`},
    "Asia/Pyongyang": {`+09:00`},
    "Asia/Qatar": {`+03:00`},
    "Asia/Qostanay": {`+05:00`},
    "Asia/Qyzylorda": {`+05:00`},
    "Asia/Riyadh": {`+03:00`},
    "Asia/Sakhalin": {`+11:00`},
    "Asia/Samarkand": {`+05:00`},
    "Asia/Seoul": {`+09:00`},
    "Asia/Shanghai": {`+08:00`},
    "Asia/Singapore": {`+08:00`},
    "Asia/Srednekolymsk": {`+11:00`},
    "Asia/Taipei": {`+08:00`},
    "Asia/Tashkent": {`+05:00`},
    "Asia/Tbilisi": {`+04:00`},
    "Asia/Tehran": {`+03:30`},
    "Asia/Thimphu": {`+06:00`},
    "Asia/Tokyo": {`+09:00`},
    "Asia/Tomsk": {`+07:00`},
    "Asia/Ulaanbaatar": {`+08:00`},
    "Asia/Urumqi": {`+06:00`},
    "Asia/Ust-Nera": {`+10:00`},
    "Asia/Vladivostok": {`+10:00`},
    "Asia/Yakutsk": {`+09:00`},
    "Asia/Yangon": {`+06:30`},
    "Asia/Yekaterinburg": {`+05:00`},
    "Asia/Yerevan": {`+04:00`},

    # Atlantic
    "Atlantic/Azores": _zone_eu_minus_1,
    "Atlantic/Bermuda": _zone_us_4,
    "Atlantic/Canary": _zone_eu_0,
    "Atlantic/Cape_Verde": {`-01:00`},
    "Atlantic/Faroe": _zone_eu_0,
    "Atlantic/Madeira": _zone_eu_0,
    "Atlantic/South_Georgia": {`-02:00`},
    "Atlantic/Stanley": {`-03:00`},

    # Australia
    "Australia/Adelaide": _zone_au_9_30,
    "Australia/Brisbane": {`+10:00`},
    "Australia/Broken_Hill": _zone_au_9_30,
    "Australia/Darwin": {`+09:30`},
    "Australia/Eucla": {`+08:45`},
    "Australia/Hobart": _zone_au_10,
    "Australia/Lindeman": {`+10:00`},
    "Australia/Lord_Howe": _zone_lord_howe,
    "Australia/Melbourne": _zone_au_10,
    "Australia/Perth": {`+08:00`},
    "Australia/Sydney": _zone_au_10,

    # Standard / Etc Zones
    "CET": _zone_eu_1,
    "CST6CDT": _zone_us_6,
    "EET": _zone_eu_2,
    "EST": {`-05:00`},
    "EST5EDT": _zone_us_5,
    "Etc/UTC": {`+00:00`},
    "Etc/UTC-1": {`-01:00`}, "Etc/UTC-2": {`-02:00`}, "Etc/UTC-3": {`-03:00`},
    "Etc/UTC-4": {`-04:00`}, "Etc/UTC-5": {`-05:00`}, "Etc/UTC-6": {`-06:00`},
    "Etc/UTC-7": {`-07:00`}, "Etc/UTC-8": {`-08:00`}, "Etc/UTC-9": {`-09:00`},
    "Etc/UTC-10": {`-10:00`}, "Etc/UTC-11": {`-11:00`}, "Etc/UTC-12": {`-12:00`},

    "Etc/UTC+1": {`+01:00`}, "Etc/UTC+2": {`+02:00`}, "Etc/UTC+3": {`+03:00`},
    "Etc/UTC+4": {`+04:00`}, "Etc/UTC+5": {`+05:00`}, "Etc/UTC+6": {`+06:00`},
    "Etc/UTC+7": {`+07:00`}, "Etc/UTC+8": {`+08:00`}, "Etc/UTC+9": {`+09:00`},
    "Etc/UTC+10": {`+10:00`}, "Etc/UTC+11": {`+11:00`}, "Etc/UTC+12": {`+12:00`},
    "Etc/UTC+13": {`+13:00`}, "Etc/UTC+14": {`+14:00`},
    
    # NOTE: POSIX Signs are strictly inverted
    "Etc/GMT": {`+00:00`},
    "Etc/GMT+1": {`-01:00`}, "Etc/GMT+2": {`-02:00`}, "Etc/GMT+3": {`-03:00`},
    "Etc/GMT+4": {`-04:00`}, "Etc/GMT+5": {`-05:00`}, "Etc/GMT+6": {`-06:00`},
    "Etc/GMT+7": {`-07:00`}, "Etc/GMT+8": {`-08:00`}, "Etc/GMT+9": {`-09:00`},
    "Etc/GMT+10": {`-10:00`}, "Etc/GMT+11": {`-11:00`}, "Etc/GMT+12": {`-12:00`},

    "Etc/GMT-1": {`+01:00`}, "Etc/GMT-2": {`+02:00`}, "Etc/GMT-3": {`+03:00`},
    "Etc/GMT-4": {`+04:00`}, "Etc/GMT-5": {`+05:00`}, "Etc/GMT-6": {`+06:00`},
    "Etc/GMT-7": {`+07:00`}, "Etc/GMT-8": {`+08:00`}, "Etc/GMT-9": {`+09:00`},
    "Etc/GMT-10": {`+10:00`}, "Etc/GMT-11": {`+11:00`}, "Etc/GMT-12": {`+12:00`},
    "Etc/GMT-13": {`+13:00`}, "Etc/GMT-14": {`+14:00`},

    # Europe
    "Europe/Andorra": _zone_eu_1,
    "Europe/Astrakhan": {`+04:00`},
    "Europe/Athens": _zone_eu_2,
    "Europe/Belgrade": _zone_eu_1,
    "Europe/Berlin": _zone_eu_1,
    "Europe/Brussels": _zone_eu_1,
    "Europe/Bucharest": _zone_eu_2,
    "Europe/Budapest": _zone_eu_1,
    "Europe/Chisinau": _zone_eu_2,
    "Europe/Dublin": _zone_eu_0,
    "Europe/Gibraltar": _zone_eu_1,
    "Europe/Helsinki": _zone_eu_2,
    "Europe/Istanbul": {`+03:00`},
    "Europe/Kaliningrad": {`+02:00`},
    "Europe/Kirov": {`+03:00`},
    "Europe/Kyiv": _zone_eu_2,
    "Europe/Lisbon": _zone_eu_0,
    "Europe/London": _zone_eu_0,
    "Europe/Madrid": _zone_eu_1,
    "Europe/Malta": _zone_eu_1,
    "Europe/Minsk": {`+03:00`},
    "Europe/Moscow": {`+03:00`},
    "Europe/Paris": _zone_eu_1,
    "Europe/Prague": _zone_eu_1,
    "Europe/Riga": _zone_eu_2,
    "Europe/Rome": _zone_eu_1,
    "Europe/Samara": {`+04:00`},
    "Europe/Saratov": {`+04:00`},
    "Europe/Simferopol": {`+03:00`},
    "Europe/Sofia": _zone_eu_2,
    "Europe/Tallinn": _zone_eu_2,
    "Europe/Tirane": _zone_eu_1,
    "Europe/Ulyanovsk": {`+04:00`},
    "Europe/Vienna": _zone_eu_1,
    "Europe/Vilnius": _zone_eu_2,
    "Europe/Volgograd": {`+03:00`},
    "Europe/Warsaw": _zone_eu_1,
    "Europe/Zurich": _zone_eu_1,

    # Misc Codes
    "HST": {`-10:00`},
    "Indian/Chagos": {`+06:00`},
    "Indian/Maldives": {`+05:00`},
    "Indian/Mauritius": {`+04:00`},
    "MET": _zone_eu_1,
    "MST": {`-07:00`},
    "MST7MDT": _zone_us_7,
    "PST8PDT": _zone_us_8,

    # Pacific
    "Pacific/Apia": {`+13:00`},
    "Pacific/Auckland": _zone_nz_12,
    "Pacific/Bougainville": {`+11:00`},
    "Pacific/Chatham": _zone_nz_12_45,
    "Pacific/Easter": _zone_easter,
    "Pacific/Efate": {`+11:00`},
    "Pacific/Fakaofo": {`+13:00`},
    "Pacific/Fiji": {`+12:00`},
    "Pacific/Galapagos": {`-06:00`},
    "Pacific/Gambier": {`-09:00`},
    "Pacific/Guadalcanal": {`+11:00`},
    "Pacific/Guam": {`+10:00`},
    "Pacific/Honolulu": {`-10:00`},
    "Pacific/Kanton": {`+13:00`},
    "Pacific/Kiritimati": {`+14:00`},
    "Pacific/Kosrae": {`+11:00`},
    "Pacific/Kwajalein": {`+12:00`},
    "Pacific/Marquesas": {`-09:30`},
    "Pacific/Nauru": {`+12:00`},
    "Pacific/Niue": {`-11:00`},
    "Pacific/Norfolk": _zone_au_11,
    "Pacific/Noumea": {`+11:00`},
    "Pacific/Pago_Pago": {`-11:00`},
    "Pacific/Palau": {`+09:00`},
    "Pacific/Pitcairn": {`-08:00`},
    "Pacific/Port_Moresby": {`+10:00`},
    "Pacific/Rarotonga": {`-10:00`},
    "Pacific/Tahiti": {`-10:00`},
    "Pacific/Tarawa": {`+12:00`},
    "Pacific/Tongatapu": {`+13:00`},
    "WET": _zone_eu_0,
}
"""A dictionary with many of the easily defined time zones, whose DST and STD
transition rules (if applicable) can be expressed in terms of a gregorian
calendar."""
# fmt: on
