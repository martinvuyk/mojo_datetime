#!/usr/bin/env bash
##===----------------------------------------------------------------------===##
# Copyright (c) 2024, Modular Inc. All rights reserved.
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

TEST_PATH="${REPO_ROOT}/src/tests"
TEST_PATH=$( realpath ${TEST_PATH} )

cp ${BUILD_DIR}/mojo_datetime.mojopkg ${TEST_PATH}

if [[ $# -gt 0 ]]; then
  # If an argument is provided, use it as the specific test file or directory
  TEST_PATH=$1
fi
TEST_PATH=$( realpath ${TEST_PATH} )

echo "Running the tests"
for f in $( find $TEST_PATH -name '*.mojo' ); do
  mojo run -D ASSERT=all $f &
done
wait
