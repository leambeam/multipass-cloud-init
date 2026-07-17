setup() {
    load 'common-setup'
    _common_setup
}

@test "print project root" {
    echo "$PROJECT_ROOT" >&3
    [ -f "$PROJECT_ROOT/mp-launch.sh" ]
}