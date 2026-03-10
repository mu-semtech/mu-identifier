#!/bin/sh
set -e

# Runs in semtech/mu-scripts:1.0.0 container.
# wo is invoked from mu/tests/, so:
#   - /mu-project (mounts.app) = mu/tests/
#   - host commands run from mu/tests/, so plain `docker compose` works
#   - override files are at cases/*.yml relative to mu/tests/

# The host command (docker-client-script.sh from mu-cli) needs bash and /bin/env.
# semtech/mu-scripts:1.0.0 is Alpine-based: env lives at /usr/bin/env, bash is absent.
apk add --no-cache bash >/dev/null 2>&1 || true
ln -sf /usr/bin/env /bin/env 2>/dev/null || true

APP=/mu-project
FAIL=0
GROUPS='[{"name":"admin","variables":[]}]'

mkdir -p $APP/.tmp
printf '%s' "$GROUPS" > $APP/.tmp/groups.txt

# Helper: wait for a URL to return 200.
# The project-scripts container is on the compose default network (same docker-compose.yml),
# so wget can reach dispatcher/identifier directly without going through `host`.
wait_for() {
  URL="$1"
  TRIES=0
  while [ $TRIES -lt 60 ]; do
    wget -qO /dev/null "$URL" 2>/dev/null && return 0
    TRIES=$((TRIES + 1))
    sleep 1
  done
  printf "Timed out waiting for %s\n" "$URL" >&2
  return 1
}

# Helper: capture cookie + session ID from a fresh session into .tmp/output.txt
capture_session() {
  host docker compose run --rm --no-deps \
    -e GROUPS_FILE=/tests/.tmp/groups.txt \
    -e OUTPUT_FILE=/tests/.tmp/output.txt \
    tests node /tests/capture-session.js
}

# Helper: revoke a session URI by running the revoke script in a fresh identifier container
revoke_session() {
  SESSION_URI="$1"
  STRATEGY="${2:-clear_allowed_groups}"
  host docker compose run --rm \
    --entrypoint /app/scripts/revoke-session/run.sh \
    identifier "$SESSION_URI" "$STRATEGY"
}

# Helper: revoke all sessions holding the cached groups string
revoke_groups_string() {
  STRATEGY="${1:-clear_allowed_groups}"
  host docker compose run --rm \
    --entrypoint /app/scripts/revoke-allowed-groups-string/run.sh \
    identifier "$GROUPS" "$STRATEGY"
}

host docker compose build
host docker compose up -d dispatcher
wait_for http://dispatcher/

for SPEC_JS in $APP/cases/0[1-8]-*.js; do
  SPEC="$(basename "$SPEC_JS")"
  OVERRIDE="cases/${SPEC%.js}.yml"

  printf "\n=== %s ===\n" "$SPEC"

  if [ -f "$APP/$OVERRIDE" ]; then
    host docker compose -f docker-compose.yml -f "$OVERRIDE" up -d identifier --force-recreate
    wait_for http://identifier/
    host docker compose -f docker-compose.yml -f "$OVERRIDE" run --rm \
      -e TEST_SPEC="cases/$SPEC" tests || FAIL=1
  else
    host docker compose up -d identifier --force-recreate
    wait_for http://identifier/
    host docker compose run --rm \
      -e TEST_SPEC="cases/$SPEC" tests || FAIL=1
  fi
done

# Revocation tests: set up session state, revoke, then assert
printf "\n=== 09-session-revocation.js ===\n"
host docker compose up -d identifier --force-recreate
wait_for http://identifier/

capture_session
CLEAR_GROUPS_COOKIE=$(sed -n '1p' $APP/.tmp/output.txt)
CLEAR_GROUPS_SESSION_ID=$(sed -n '2p' $APP/.tmp/output.txt)
revoke_session "$CLEAR_GROUPS_SESSION_ID" clear_allowed_groups

capture_session
CLEAR_SESSION_COOKIE=$(sed -n '1p' $APP/.tmp/output.txt)
CLEAR_SESSION_ID=$(sed -n '2p' $APP/.tmp/output.txt)
revoke_session "$CLEAR_SESSION_ID" clear_session

capture_session
REVOKED_GROUPS_COOKIE=$(sed -n '1p' $APP/.tmp/output.txt)
revoke_groups_string clear_allowed_groups

host docker compose run --rm \
  -e TEST_SPEC=cases/09-session-revocation.js \
  -e CLEAR_GROUPS_COOKIE="$CLEAR_GROUPS_COOKIE" \
  -e CLEAR_SESSION_COOKIE="$CLEAR_SESSION_COOKIE" \
  -e CLEAR_SESSION_ID="$CLEAR_SESSION_ID" \
  -e REVOKED_GROUPS_COOKIE="$REVOKED_GROUPS_COOKIE" \
  tests || FAIL=1

rm -rf $APP/.tmp
host docker compose down
exit $FAIL
