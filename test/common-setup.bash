#!/usr/bin/env bash

_common_setup() {
    bats_require_minimum_version 1.13.0

    PROJECT_ROOT="$( cd "$( dirname "$BATS_TEST_FILENAME" )/.." >/dev/null 2>&1 && pwd )"
    export BATS_LIB_PATH="${PROJECT_ROOT}/test/test_helper"

    bats_load_library bats-support
    bats_load_library bats-assert
    bats_load_library bats-mock/stub.bash

    PATH="$PROJECT_ROOT:$PATH"
    # shellcheck source=/dev/null
    source "$PROJECT_ROOT/mp-launch.sh"
}