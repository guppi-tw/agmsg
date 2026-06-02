#!/usr/bin/env bash
set -euo pipefail

# Usage: rename.sh <team> <old_name> <new_name>
#
# Renames an agent in team config and updates all messages in DB.

TEAM="${1:?Usage: rename.sh <team> <old_name> <new_name>}"
OLD_NAME="${2:?Missing old agent name}"
NEW_NAME="${3:?Missing new agent name}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/storage.sh"
source "$SCRIPT_DIR/lib/safety.sh"
TEAMS_DIR="$SCRIPT_DIR/../teams"
DB="$(agmsg_db_path)"
TEAM_CONFIG="$TEAMS_DIR/$TEAM/config.json"

agmsg_validate_name "team" "$TEAM"
agmsg_validate_name "old agent" "$OLD_NAME"
agmsg_validate_name "new agent" "$NEW_NAME"

if [ ! -f "$TEAM_CONFIG" ]; then
  echo "Team not found: $TEAM"
  exit 1
fi

# --- Update team config ---
CONFIG_SQL=$(agmsg_sql_literal "$(cat "$TEAM_CONFIG")")

# Check old exists
OLD_VAL=$(sqlite3 :memory: "SELECT json_extract($CONFIG_SQL, '$.agents.$OLD_NAME');")
if [ -z "$OLD_VAL" ] || [ "$OLD_VAL" = "null" ]; then
  echo "Agent $OLD_NAME not in team $TEAM"
  exit 1
fi

# Check new doesn't exist
NEW_VAL=$(sqlite3 :memory: "SELECT json_extract($CONFIG_SQL, '$.agents.$NEW_NAME');")
if [ -n "$NEW_VAL" ] && [ "$NEW_VAL" != "null" ]; then
  echo "Agent $NEW_NAME already exists in team $TEAM"
  exit 1
fi

# Rename: set new key with old value, remove old key
UPDATED=$(sqlite3 :memory: "SELECT json_remove(json_set($CONFIG_SQL, '$.agents.$NEW_NAME', json_extract($CONFIG_SQL, '$.agents.$OLD_NAME')), '$.agents.$OLD_NAME');")
echo "$UPDATED" > "$TEAM_CONFIG"

# --- Update messages in DB ---
if [ -f "$DB" ]; then
  sqlite3 "$DB" "UPDATE messages SET from_agent=$(agmsg_sql_literal "$NEW_NAME") WHERE team=$(agmsg_sql_literal "$TEAM") AND from_agent=$(agmsg_sql_literal "$OLD_NAME");"
  sqlite3 "$DB" "UPDATE messages SET to_agent=$(agmsg_sql_literal "$NEW_NAME") WHERE team=$(agmsg_sql_literal "$TEAM") AND to_agent=$(agmsg_sql_literal "$OLD_NAME");"
fi

echo "Renamed $OLD_NAME → $NEW_NAME in team $TEAM"
