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
"""`TimeZone` module."""

from std.builtin.globals import global_constant
from std.sys.intrinsics import _type_is_eq

from .zoneinfo import Offset, UTCZoneInfo, ZoneInfo, TzDT, gregorian_zoneinfo

comptime TZ_UTC = TimeZone()
"""A UTC `TimeZone`."""


@fieldwise_init
struct TimeZone[zone_info_type: UTCZoneInfo = ZoneInfo](
    Copyable, Defaultable, Equatable, Writable
):
    """`TimeZone` struct.

    Parameters:
        zone_info_type: The type that the zone information is stored in.
    """

    var tz_str: String
    """[`IANA TimeZone identifier`](
        https://en.wikipedia.org/wiki/List_of_tz_database_time_zones)."""
    var zone_info: Self.zone_info_type
    """The zone information for the `TimeZone`."""

    @always_inline
    def __init__(out self):
        """Construct a `TimeZone`."""
        self.tz_str = "Etc/UTC"
        self.zone_info = {}

    @implicit
    def __init__(out self: TimeZone[], tz_str: StringLiteral):
        """Construct a `TimeZone`.

        Args:
            tz_str: The [`IANA TimeZone identifier`](
                https://en.wikipedia.org/wiki/List_of_tz_database_time_zones).
        """

        comptime str_name = type_of(tz_str)()
        comptime res = gregorian_zoneinfo.get(str_name)
        comptime assert res, String(t"Time zone string not found: '{str_name}'")
        self.tz_str = tz_str
        self.zone_info = materialize[res.value()]()

    def __init__(out self: TimeZone[], tz_str: String) raises:
        """Construct a `TimeZone`.

        Args:
            tz_str: The [`IANA TimeZone identifier`](
                https://en.wikipedia.org/wiki/List_of_tz_database_time_zones).

        Raises:
            When a time zone string wasn't found in the default zone info dict.
        """

        var res = global_constant[gregorian_zoneinfo]().get(tz_str)
        if not res:
            raise Error(t"Time zone string not found: '{tz_str}'")
        self.tz_str = tz_str
        self.zone_info = res^.unsafe_value()

    @always_inline
    def write_to[W: Writer](self, mut writer: W):
        """Write the IANA `TimeZone` string to a writer.

        Parameters:
            W: The writer type.

        Args:
            writer: The writer to write to.
        """
        writer.write(self.tz_str)

    @always_inline
    def __eq__(self, other: Self) -> Bool:
        """Whether the zone_info from both TimeZones
        are the same.

        Args:
            other: Other.

        Returns:
            Bool.
        """
        return self.zone_info == other.zone_info

    @always_inline
    def __eq__(self, other: TimeZone) -> Bool:
        """Whether the zone_info from both TimeZones
        are the same.

        Args:
            other: Other.

        Returns:
            Bool.
        """
        comptime if _type_is_eq[self.zone_info_type, other.zone_info_type]():
            return self.zone_info == rebind[self.zone_info_type](
                other.zone_info
            )
        else:
            return False

    @always_inline
    def __ne__(self, other: TimeZone) -> Bool:
        """Whether the zone_info from both TimeZones
        are different.

        Args:
            other: Other.

        Returns:
            Bool.
        """
        return not self == other
