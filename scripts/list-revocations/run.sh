#!/bin/sh
IDENTIFIER_IP=$(getent hosts identifier | awk '{print $1}')

elixir --name "rpc@$(hostname -i)" --cookie mu-identifier \
  --rpc-eval "mu_identifier@$IDENTIFIER_IP" \
  'SessionRevocation.list_revocations() |> inspect(pretty: true) |> IO.puts()'
