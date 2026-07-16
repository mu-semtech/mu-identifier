#!/bin/sh
set -e

# Runs in semtech/mu-scripts:1.0.0 container.
# wo is invoked from mu/tests/, so:
#   - /mu-project (mounts.app) = mu/tests/
#   - host commands run from mu/tests/, so plain `docker compose` works

# The host command (docker-client-script.sh from mu-cli) needs bash and /bin/env.
# semtech/mu-scripts:1.0.0 is Alpine-based: env lives at /usr/bin/env, bash is absent.
apk add --no-cache bash >/dev/null 2>&1 || true
ln -sf /usr/bin/env /bin/env 2>/dev/null || true

APP=/mu-project
FAIL=0
GROUPS='[{"name":"admin","variables":[]}]'
SPEC_ARG="${1:-}"  # optional: run a single spec, e.g. "04-cors" or "04-cors.js"

# Write cases/XX.env to .test-identifier-env so identifier picks it up via env_file.
# Always creates the file (empty if no per-spec override exists).
write_test_env() {
  if [ -f "$1" ]; then
    cp "$1" "$APP/.test-identifier-env"
  else
    : > "$APP/.test-identifier-env"
  fi
}

# Copy per-spec custom session reader/writer files into custom-config/ so the
# identifier startup script picks them up.  Always clears first so tests that
# don't need custom session handling start with no custom files mounted.
write_custom_config() {
  SPEC_BASE="$1"
  rm -f "$APP/custom-config/custom_session_reader.ex" "$APP/custom-config/custom_session_writer.ex"
  if [ -f "$APP/cases/${SPEC_BASE}-reader.ex" ]; then
    cp "$APP/cases/${SPEC_BASE}-reader.ex" "$APP/custom-config/custom_session_reader.ex"
  fi
  if [ -f "$APP/cases/${SPEC_BASE}-writer.ex" ]; then
    cp "$APP/cases/${SPEC_BASE}-writer.ex" "$APP/custom-config/custom_session_writer.ex"
  fi
}

# Helper: capture cookie + session ID from a fresh session; prints cookie on line 1, session ID on line 2
capture_session() {
  host docker compose run --rm --use-aliases --no-deps \
    -e GROUPS="$GROUPS" \
    mocha node /tests/capture-session.js
}

# Run an identifier script via the first available mu-cli command (works, wo, or mu)
mu_identifier_script() {
  host works script identifier "$@" 2>/dev/null \
    || host wo script identifier "$@" 2>/dev/null \
    || host mu script identifier "$@"
}

# Helper: revoke a session URI via the mu-cli script (same command end-users run)
revoke_session() {
  SESSION_URI="$1"
  STRATEGY="${2:-clear_mu_auth_allowed_groups}"
  mu_identifier_script revoke-session "$SESSION_URI" "$STRATEGY"
}

# Helper: revoke all sessions holding the cached groups string via the mu-cli script
revoke_groups_string() {
  STRATEGY="${1:-clear_mu_auth_allowed_groups}"
  mu_identifier_script revoke-allowed-groups-string "$GROUPS" "$STRATEGY"
}

record_result() {
  shift
  "$@" || { FAIL=1; printf "\n--- mu-identifier logs ---\n"; host docker logs tests-identifier-1; printf "--- end mu-identifier logs ---\n"; }
}

run_spec_09() {
  write_test_env ""
  write_custom_config ""
  host docker compose up -d identifier --force-recreate

  OUTPUT=$(capture_session)
  CLEAR_GROUPS_COOKIE=$(printf '%s\n' "$OUTPUT" | sed -n '1p')
  CLEAR_GROUPS_SESSION_ID=$(printf '%s\n' "$OUTPUT" | sed -n '2p')
  revoke_session "$CLEAR_GROUPS_SESSION_ID" clear_mu_auth_allowed_groups

  OUTPUT=$(capture_session)
  CLEAR_SESSION_COOKIE=$(printf '%s\n' "$OUTPUT" | sed -n '1p')
  CLEAR_SESSION_ID=$(printf '%s\n' "$OUTPUT" | sed -n '2p')
  revoke_session "$CLEAR_SESSION_ID" clear_mu_session_id

  OUTPUT=$(capture_session)
  REVOKED_GROUPS_COOKIE=$(printf '%s\n' "$OUTPUT" | sed -n '1p')
  revoke_groups_string clear_mu_auth_allowed_groups

  record_result 09-session-revocation.js \
    host docker compose run --rm --use-aliases \
    -e TEST_SPEC=cases/09-session-revocation.js \
    -e CLEAR_GROUPS_COOKIE="$CLEAR_GROUPS_COOKIE" \
    -e CLEAR_SESSION_COOKIE="$CLEAR_SESSION_COOKIE" \
    -e CLEAR_SESSION_ID="$CLEAR_SESSION_ID" \
    -e REVOKED_GROUPS_COOKIE="$REVOKED_GROUPS_COOKIE" \
    mocha
}

print_summary() {
  host docker compose run --rm --no-deps mocha node /tests/summarize.js
}

run_spec_17() {
  printf "\n=== 17-invalid-config.js ===\n"
  write_test_env "$APP/cases/17-invalid-config.env"
  write_custom_config "17-invalid-config"
  host docker compose up -d identifier --force-recreate
  record_result 17-invalid-config.js \
    host docker compose run --rm --use-aliases \
    -e TEST_SPEC=cases/17-invalid-config.js \
    -e SKIP_IDENTIFIER_WAIT=1 \
    mocha
}

run_spec() {
  SPEC="$1"
  printf "\n=== %s ===\n" "$SPEC"
  write_test_env "$APP/cases/${SPEC%.js}.env"
  write_custom_config "${SPEC%.js}"
  host docker compose up -d identifier --force-recreate
  record_result "$SPEC" \
    host docker compose run --rm --use-aliases \
    -e TEST_SPEC="cases/$SPEC" mocha
}

mkdir -p "$APP/.tmp/results"
rm -f "$APP/.tmp/results"/*.json

host docker compose build

if [ -n "$SPEC_ARG" ]; then
  SPEC="${SPEC_ARG%.js}"
  case "$SPEC" in
    09-*) printf "\n=== 09-session-revocation.js ===\n"; run_spec_09 ;;
    17-*) run_spec_17 ;;
    *) run_spec "${SPEC}.js" ;;
  esac
  : > "$APP/.test-identifier-env"
else
  for SPEC_JS in $APP/cases/0[1-8]-*.js; do
    run_spec "$(basename "$SPEC_JS")"
  done

  : > "$APP/.test-identifier-env"

  printf "\n=== 09-session-revocation.js ===\n"
  run_spec_09

  for SPEC_JS in $APP/cases/1[0-9]-*.js; do
    SPEC="$(basename "$SPEC_JS")"
    case "$SPEC" in
      17-*) run_spec_17 ;;
      *) run_spec "$SPEC" ;;
    esac
  done
fi

: > "$APP/.test-identifier-env"
rm -f "$APP/custom-config/custom_session_reader.ex" "$APP/custom-config/custom_session_writer.ex"

print_summary
host docker compose down
exit $FAIL
