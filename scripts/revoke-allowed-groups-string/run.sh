#!/bin/sh
ALLOWED_GROUPS=$1
STRATEGY=${2:-clear_allowed_groups}
DURATION=$3

ESCAPED_GROUPS=$(printf '%s' "$ALLOWED_GROUPS" | sed 's/"/\\"/g')
IDENTIFIER_IP=$(nslookup identifier | grep -oP '\d+\.\d+\.\d+\.\d+' | tail -1)

if [ -n "$DURATION" ]; then
  CALL="SessionRevocation.revoke_mu_auth_allowed_groups_string(\"$ESCAPED_GROUPS\", :$STRATEGY, $DURATION)"
else
  CALL="SessionRevocation.revoke_mu_auth_allowed_groups_string(\"$ESCAPED_GROUPS\", :$STRATEGY)"
fi

elixir --name "rpc@$(hostname -i)" --cookie mu-identifier \
  --rpc-eval "mu_identifier@$IDENTIFIER_IP" \
  "$CALL"

echo "Use 'mu script identifier list-revocations' to inspect the current state of revocations."
