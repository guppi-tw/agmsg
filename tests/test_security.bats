#!/usr/bin/env bats

load test_helper

setup() {
  setup_test_env
}

teardown() {
  teardown_test_env
}

@test "names: rejects traversal in team name" {
  run bash "$SCRIPTS/join.sh" ../outside alice claude-code /tmp/project
  [ "$status" -ne 0 ]
  [[ "$output" =~ "contain slash" ]]
  [ ! -e "$TEST_SKILL_DIR/outside" ]
}

@test "names: rejects sqlite metacharacters in team name" {
  local poc="/tmp/agmsg-security-poc-$$"
  rm -f "$poc"

  run bash "$SCRIPTS/inbox.sh" "safe'; SELECT writefile('$poc','owned'); --" alice

  [ "$status" -ne 0 ]
  [ ! -e "$poc" ]
}

@test "send: treats message body as data" {
  local poc="/tmp/agmsg-security-body-poc-$$"
  rm -f "$poc"

  bash "$SCRIPTS/join.sh" testteam alice claude-code /tmp/project-a
  bash "$SCRIPTS/join.sh" testteam bob claude-code /tmp/project-b
  bash "$SCRIPTS/send.sh" testteam alice bob "hello'); SELECT writefile('$poc','owned'); --"
  run bash "$SCRIPTS/inbox.sh" testteam bob

  [ "$status" -eq 0 ]
  [[ "$output" =~ "writefile" ]]
  [ ! -e "$poc" ]
}

@test "join: stores quoted project paths as JSON data" {
  local project="/tmp/project with 'quote'"

  bash "$SCRIPTS/join.sh" testteam alice claude-code "$project"
  run bash "$SCRIPTS/identities.sh" "$project" claude-code

  [ "$status" -eq 0 ]
  [[ "$output" =~ $'testteam\talice' ]]
}
