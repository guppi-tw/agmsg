#!/usr/bin/env bash
# safety.sh - input validation and SQL/JSON quoting helpers.

agmsg_die() {
  printf '%s\n' "$*" >&2
  exit 1
}

agmsg_validate_name() {
  local label="$1" value="$2"
  case "$value" in
    '') agmsg_die "$label must not be empty" ;;
    *[!/A-Za-z0-9_-]*)
      agmsg_die "$label may only contain letters, numbers, underscore, and dash"
      ;;
  esac
  case "$value" in
    -*|*/*)
      agmsg_die "$label must not start with dash or contain slash"
      ;;
  esac
  if [ "${#value}" -gt 128 ]; then
    agmsg_die "$label is too long (max 128 characters)"
  fi
}

agmsg_validate_type() {
  case "$1" in
    claude-code|codex|gemini|antigravity) ;;
    *) agmsg_die "Unknown agent type: '$1' (supported: claude-code, codex, gemini, antigravity)" ;;
  esac
}

agmsg_validate_limit() {
  local value="$1"
  case "$value" in
    ''|*[!0-9]*) agmsg_die "Limit must be a positive integer" ;;
  esac
  if [ "$value" -lt 1 ] || [ "$value" -gt 1000 ]; then
    agmsg_die "Limit must be between 1 and 1000"
  fi
}

agmsg_sql_literal() {
  printf "'%s'" "$(printf '%s' "$1" | sed "s/'/''/g")"
}

agmsg_json_string() {
  sqlite3 :memory: "SELECT json_quote($(agmsg_sql_literal "$1"));"
}

agmsg_shell_quote() {
  printf "'"
  printf '%s' "$1" | sed "s/'/'\\\\''/g"
  printf "'"
}
