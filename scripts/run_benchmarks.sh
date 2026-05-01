#!/usr/bin/env bash
##===----------------------------------------------------------------------===##
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
##===----------------------------------------------------------------------===##

set -euo pipefail

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
REPO_ROOT="${SCRIPT_DIR}"/..
BUILD_DIR="${REPO_ROOT}"/build

BENCH_PATH="${REPO_ROOT}/src/benchmarks"
BENCH_PATH=$( realpath ${BENCH_PATH} )

cp ${BUILD_DIR}/mojo_datetime.mojopkg ${BENCH_PATH}

if [[ $# -gt 0 ]]; then
  BENCH_PATH=$1
fi
BENCH_PATH=$( realpath ${BENCH_PATH} )

echo "Running the benchmarks"
for f in $( find $BENCH_PATH -name 'bench_*.mojo' ); do
  echo "==> $f"
  mojo run -O3 $f
done
