#!/usr/bin/env bash
set -euo pipefail

# Usage: send.sh <team> <from> <to> <message>

TEAM="${1:?Usage: send.sh <team> <from> <to> <message>}"
FROM="${2:?Missing from agent}"
TO="${3:?Missing to agent}"
BODY="${4:?Missing message body}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/storage.sh"
source "$SCRIPT_DIR/lib/safety.sh"
DB="$(agmsg_db_path)"

agmsg_validate_name "team" "$TEAM"
agmsg_validate_name "from agent" "$FROM"
agmsg_validate_name "to agent" "$TO"

if [ ! -f "$DB" ]; then
  bash "$SCRIPT_DIR/init-db.sh"
fi

sqlite3 "$DB" "INSERT INTO messages (team, from_agent, to_agent, body) VALUES ($(agmsg_sql_literal "$TEAM"), $(agmsg_sql_literal "$FROM"), $(agmsg_sql_literal "$TO"), $(agmsg_sql_literal "$BODY"));"

echo "Sent to $TO in team $TEAM"
