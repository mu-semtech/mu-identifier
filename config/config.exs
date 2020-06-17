# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

# This configuration is loaded before any dependency and is restricted
# to this project. If another project depends on this project, this
# file won't be loaded nor affect the parent project. For this reason,
# if you want to provide default values for your application for third-
# party users, it should be done in your mix.exs file.

# Sample configuration:
#
#     config :logger, :console,
#       level: :info,
#       format: "$date $time [$level] $metadata$message\n",
#       metadata: [:user_id]

defmodule CH do
  def system_boolean(name, default \\ false) do
    case String.downcase(System.get_env(name) || "") do
      "true" -> true
      "yes" -> true
      "1" -> true
      "on" -> true
      _ -> default
    end
  end

  def calculate_same_site do
    calculate_same_site(
      System.get_env("DEFAULT_ACCESS_CONTROL_ALLOW_ORIGIN_HEADER"),
      System.get_env("SESSION_COOKIE_SAME_SITE")
    )
  end

  defp calculate_same_site(_, same_site) when is_binary(same_site), do: same_site
  defp calculate_same_site("*", nil), do: "None"
  defp calculate_same_site(nil, nil), do: "Lax"
end

config :mu_identifier,
  encryption_salt: System.get_env("MU_ENCRYPTION_SALT"),
  signing_salt: System.get_env("MU_SIGNING_SALT"),
  secret_key_base: System.get_env("MU_SECRET_KEY_BASE"),
  default_access_control_allow_origin_header: System.get_env("DEFAULT_ACCESS_CONTROL_ALLOW_ORIGIN_HEADER"),
  default_mu_auth_allowed_groups_header: System.get_env("DEFAULT_MU_AUTH_ALLOWED_GROUPS_HEADER"),
  session_cookie_secure: CH.system_boolean("SESSION_COOKIE_SECURE", true),
  session_cookie_http_only: CH.system_boolean("SESSION_COOKIE_HTTP_ONLY", true),
  session_cookie_same_site: CH.calculate_same_site(),
  log_allowed_groups: System.get_env("LOG_ALLOWED_GROUPS"),
  log_incoming_allowed_groups: System.get_env("LOG_INCOMING_ALLOWED_GROUPS"),
  log_outgoing_allowed_groups: System.get_env("LOG_OUTGOING_ALLOWED_GROUPS")

config :plug_mint_proxy,
  author: :"mu-semtech",
  log_backend_communication: CH.system_boolean("LOG_BACKEND_COMMUNICATION"),
  log_frontend_communication: CH.system_boolean("LOG_FRONTEND_COMMUNICATION"),
  log_request_processing: CH.system_boolean("LOG_FRONTEND_PROCESSING"),
  log_response_processing: CH.system_boolean("LOG_BACKEND_PROCESSING"),
  log_connection_setup: CH.system_boolean("LOG_CONNECTION_SETUP"),
  log_request_body: CH.system_boolean("LOG_REQUEST_BODY"),
  log_response_body: CH.system_boolean("LOG_RESPONSE_BODY")


# It is also possible to import configuration files, relative to this
# directory. For example, you can emulate configuration per environment
# by uncommenting the line below and defining dev.exs, test.exs and such.
# Configuration from the imported file will override the ones defined
# here (which is why it is important to import them last).
#
#     import_config "#{Mix.env}.exs"
