#!/usr/bin/env bash
set -euo pipefail

# Usage: leave.sh <team> <agent_id>
#
# Removes an agent from a team. Removes the team if empty.

TEAM="${1:?Usage: leave.sh <team> <agent_id>}"
AGENT_ID="${2:?Missing agent_id}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/safety.sh"
TEAMS_DIR="$SCRIPT_DIR/../teams"
TEAM_CONFIG="$TEAMS_DIR/$TEAM/config.json"

agmsg_validate_name "team" "$TEAM"
agmsg_validate_name "agent" "$AGENT_ID"

if [ ! -f "$TEAM_CONFIG" ]; then
  echo "Team not found: $TEAM"
  exit 1
fi

CONFIG_SQL=$(agmsg_sql_literal "$(cat "$TEAM_CONFIG")")

# Check if agent exists
EXISTS=$(sqlite3 :memory: "SELECT json_extract($CONFIG_SQL, '$.agents.$AGENT_ID');")
if [ -z "$EXISTS" ] || [ "$EXISTS" = "null" ]; then
  echo "Agent $AGENT_ID not in team $TEAM"
  exit 1
fi

# Remove agent
UPDATED=$(sqlite3 :memory: "SELECT json_remove($CONFIG_SQL, '$.agents.$AGENT_ID');")

# Check if agents is now empty
AGENT_COUNT=$(sqlite3 :memory: \
  "SELECT count(*) FROM json_each(json_extract('$(echo "$UPDATED" | sed "s/'/''/g")', '$.agents'));")

if [ "$AGENT_COUNT" -eq 0 ]; then
  rm -f "$TEAM_CONFIG"
  rmdir "$TEAMS_DIR/$TEAM" 2>/dev/null || true
  echo "Left team $TEAM (team removed — no members left)"
else
  echo "$UPDATED" > "$TEAM_CONFIG"
  echo "Left team $TEAM"
fi
