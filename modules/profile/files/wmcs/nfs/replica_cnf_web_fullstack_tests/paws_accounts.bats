#!/usr/bin/env bats
# SPDX-License-Identifier: Apache-2.0
load helpers

setup() {
    make_test_dir "${PAWS_BASE_PATH}/${USER_ID}"
}


@test "paws: dry_run read replica cnf" {
    data='{
            "account_id": "'$USER_ID'",
            "account_type": "paws",
            "mysql_user": "dummy_mysql_user",
            "dry_run": true
    }'

    run do_curl read-replica-cnf "$data"

    [[ "$status" == "0" ]]
    json_has_equal "result" "ok" "$output"
    json_has_match "detail.password" "..*" "$output"
    json_has_equal "detail.user" "dry.run.username" "$output"
}


@test "paws: dry_run write replica cnf" {
    data='{
            "account_id": "'$USER_ID'",
            "account_type": "paws",
            "uid": "'$USER_ID'",
            "mysql_username": "dummy_mysql_user",
            "password": "dummypass",
            "dry_run": true
    }'

    run do_curl write-replica-cnf "$data"

    is_equal "$status" "0"
    json_has_equal "result" "ok" "$output"
    json_has_equal "detail.replica_path" "${PAWS_BASE_PATH}/${USER_ID}/.my.cnf" "$output"
}


@test "paws: dry_run delete replica cnf" {
    data='{
            "account_id": "'$USER_ID'",
            "account_type": "paws",
            "dry_run": true
    }'

    run do_curl delete-replica-cnf "$data"

    is_equal "$status" "0"
    json_has_equal "result" "ok" "$output"
    json_has_equal "detail.replica_path" "${PAWS_BASE_PATH}/${USER_ID}/.my.cnf" "$output"
}



@test "paws: write replica cnf works if it's new" {
    data='{
            "account_id": "'$USER_ID'",
            "account_type": "paws",
            "uid": "'$USER_ID'",
            "mysql_username": "dummy_mysql_user",
            "password": "dummypass",
            "dry_run": false
    }'
    cnf_path="${PAWS_BASE_PATH}/${USER_ID}/.my.cnf" 
    [[ -e  "$cnf_path" ]] \
    && {
        sudo chattr -i "$cnf_path"
        sudo rm -f "$cnf_path"
    } || :
    expected_contents='[client]
user = dummy_mysql_user
password = dummypass'

    run do_curl write-replica-cnf "$data"

    is_equal "$status" "0"
    json_has_equal "result" "ok" "$output"
    json_has_equal "detail.replica_path" "$cnf_path" "$output"
    exists "$cnf_path"
    is_equal "$(sudo cat "$cnf_path")" "$expected_contents"

    USER=$USER_ID
    if (id -nu "$USER_ID" &> /dev/null);then
        USER="$TOOL_NAME"
    fi
    run sudo ls -la "$cnf_path"
    match_regex "^-r--r----- 1 ${USER} ${USER} .*" "$output"

    run sudo lsattr "$cnf_path"
    match_regex "^----i---------e----.* " "$output"
}


@test "paws: write replica cnf does not overwrite if it exists already" {
    data='{
            "account_id": "'$USER_ID'",
            "account_type": "paws",
            "uid": "'$USER_ID'",
            "mysql_username": "new_dummyuser",
            "password": "new_dummypass",
            "dry_run": false
    }'
    cnf_path="${PAWS_BASE_PATH}/${USER_ID}/.my.cnf" 
    exists "$cnf_path"

    run do_curl write-replica-cnf "$data"

    is_equal "$status" "0"
    json_has_equal "result" "skip" "$output"
    json_has_equal "detail.replica_path" "$cnf_path" "$output"
}


@test "paws: read replica cnf matches the one we created" {
    data='{
            "account_id": "'$USER_ID'",
            "account_type": "paws",
            "mysql_user": "dummy_mysql_user",
            "dry_run": false
    }'
    cnf_path="${PAWS_BASE_PATH}/${USER_ID}/.my.cnf" 

    run do_curl read-replica-cnf "$data"

    is_equal "$status" "0"
    json_has_equal "result" "ok" "$output"
    json_has_match "detail.password" ".*" "$output"
    json_has_equal "detail.user" "dummy_mysql_user" "$output"
}

@test "paws: delete replica cnf deletes it from the filesystem" {
    data='{
            "account_id": "'$USER_ID'",
            "account_type": "paws",
            "dry_run": false
    }'
    cnf_path="${PAWS_BASE_PATH}/${USER_ID}/.my.cnf" 

    run do_curl delete-replica-cnf "$data"

    is_equal "$status" "0"
    json_has_equal "result" "ok" "$output"
    json_has_equal "detail.replica_path" "$cnf_path" "$output"

    ! exists "$cnf_path"
}

# TODO: replace test with teardown_file once we have bats >0.4
# IT IMPORTANT THAT THIS TEST BE THE LAST TEST IN THIS FILE!
@test "custom teardown_file function" {
  delete_test_replica_cnf "${PAWS_BASE_PATH}/${USER_ID}"
  skip
} 

