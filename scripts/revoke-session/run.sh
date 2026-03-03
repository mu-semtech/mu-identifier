#!/bin/sh
SESSION_URI=$1
STRATEGY=${2:-clear_allowed_groups}
DURATION=$3

IDENTIFIER_IP=$(nslookup identifier | grep -oP '\d+\.\d+\.\d+\.\d+' | tail -1)

if [ -n "$DURATION" ]; then
  CALL="SessionRevocation.revoke_mu_session_id(\"$SESSION_URI\", :$STRATEGY, $DURATION)"
else
  CALL="SessionRevocation.revoke_mu_session_id(\"$SESSION_URI\", :$STRATEGY)"
fi

elixir --name "rpc@$(hostname -i)" --cookie mu-identifier \
  --rpc-eval "mu_identifier@$IDENTIFIER_IP" \
  "$CALL"

echo "Use 'mu script identifier list-revocations' to inspect the current state of revocations."
