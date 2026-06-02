#!/usr/bin/env bash
set -euo pipefail

# Usage: join.sh <team> <agent_id> <type> <project_path>
#
# Adds an agent to a team. Creates the team if it doesn't exist.

TEAM="${1:?Usage: join.sh <team> <agent_id> <type> <project_path>}"
AGENT_ID="${2:?Missing agent_id}"
AGENT_TYPE="${3:?Missing type (claude-code | codex)}"
PROJECT_PATH="${4:?Missing project_path}"

# Reject unknown agent types — the rest of agmsg (delivery.sh,
# session-start.sh, identities.sh lookups) only supports the values listed
# here. Allowing arbitrary strings silently mis-registers an agent and
# makes monitor mode fail with a confusing "no joined teams" message.
case "$AGENT_TYPE" in
  claude-code|codex|gemini|antigravity) ;;
  *) echo "Unknown agent type: '$AGENT_TYPE' (supported: claude-code, codex, gemini, antigravity)" >&2; exit 1 ;;
esac

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/safety.sh"
TEAMS_DIR="$SCRIPT_DIR/../teams"
TEAM_CONFIG="$TEAMS_DIR/$TEAM/config.json"

agmsg_validate_name "team" "$TEAM"
agmsg_validate_name "agent" "$AGENT_ID"
agmsg_validate_type "$AGENT_TYPE"

# --- Ensure team config exists ---
mkdir -p "$TEAMS_DIR/$TEAM"
if [ ! -f "$TEAM_CONFIG" ]; then
  cat > "$TEAM_CONFIG" <<EOF
{
  "name": $(agmsg_json_string "$TEAM"),
  "agents": {},
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
  echo "Created team: $TEAM"
fi

# --- Add or extend agent registrations ---
CONFIG_SQL=$(agmsg_sql_literal "$(cat "$TEAM_CONFIG")")
REGISTRATION="{\"type\":$(agmsg_json_string "$AGENT_TYPE"),\"project\":$(agmsg_json_string "$PROJECT_PATH")}"
REGISTRATION_ESCAPED=$(printf '%s' "$REGISTRATION" | sed "s/'/''/g")
AGENT_TYPE_SQL=$(agmsg_sql_literal "$AGENT_TYPE")
PROJECT_PATH_SQL=$(agmsg_sql_literal "$PROJECT_PATH")

EXISTING=$(sqlite3 :memory: "SELECT json_extract($CONFIG_SQL, '$.agents.$AGENT_ID');")

if [ -z "$EXISTING" ] || [ "$EXISTING" = "null" ]; then
  AGENT_OBJ="{\"registrations\":[${REGISTRATION}]}"
else
  EXISTING_ESCAPED=$(printf '%s' "$EXISTING" | sed "s/'/''/g")
  NORMALIZED=$(sqlite3 :memory: "
    WITH agent(a) AS (SELECT '$EXISTING_ESCAPED')
    SELECT CASE
      WHEN json_type(json_extract(a, '\$.registrations')) = 'array' THEN a
      ELSE json_object(
        'registrations',
        json_array(json_object(
          'type', json_extract(a, '\$.type'),
          'project', json_extract(a, '\$.project')
        ))
      )
    END
    FROM agent;
  ")
  NORMALIZED_ESCAPED=$(printf '%s' "$NORMALIZED" | sed "s/'/''/g")

  HAS_REGISTRATION=$(sqlite3 :memory: "
    SELECT EXISTS(
      SELECT 1
      FROM json_each(json_extract('$NORMALIZED_ESCAPED', '\$.registrations'))
      WHERE json_extract(value, '\$.type') = $AGENT_TYPE_SQL
        AND json_extract(value, '\$.project') = $PROJECT_PATH_SQL
    );
  ")

  if [ "$HAS_REGISTRATION" = "1" ]; then
    AGENT_OBJ="$NORMALIZED"
  else
    AGENT_OBJ=$(sqlite3 :memory: "
      SELECT json_set(
        '$NORMALIZED_ESCAPED',
        '\$.registrations[' || json_array_length(json_extract('$NORMALIZED_ESCAPED', '\$.registrations')) || ']',
        json('$REGISTRATION_ESCAPED')
      );
    ")
  fi
fi

UPDATED=$(sqlite3 :memory: "SELECT json_set($CONFIG_SQL, '$.agents.$AGENT_ID', json('$(printf '%s' "$AGENT_OBJ" | sed "s/'/''/g")'));")
echo "$UPDATED" > "$TEAM_CONFIG"

echo "Joined team $TEAM as $AGENT_ID"
