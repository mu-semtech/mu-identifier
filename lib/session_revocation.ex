defmodule SessionRevocation do
  @moduledoc """
  Revokes mu-auth-allowed-groups or mu-session-id

  Both mu-auth-allowed-groups and mu-session-id are currently revoked based on their string value.

  When DEFAULT_SESSION_TTL_SECONDS is set, entries are purged after 2x that value.  When no TTL is configured sessions
  live forever and entries are never purged.
  """

  use GenServer

  @session_id_string_table :revoked_session_id_strings
  @allowed_groups_string_table :revoked_allowed_groups_strings

  def revoke_mu_session_id(mu_session_id, strategy) do
    GenServer.call(__MODULE__, {:revoke_mu_session_id, mu_session_id, strategy})
  end

  def revoke_mu_auth_allowed_groups_string(allowed_groups_string, strategy) do
    GenServer.call(__MODULE__, {:revoke_mu_auth_allowed_groups_string, allowed_groups_string, strategy})
  end

  @doc "Returns nil when the session URI has no pending revocation, or the strategy atom when it does."
  def mu_session_id_revoked?(mu_session_id) do
    case :ets.lookup(@session_id_string_table, mu_session_id) do
      [{^mu_session_id, _revoked_at, strategy}] -> strategy
      [] -> nil
    end
  end

  @doc "Returns nil when the groups string has no pending revocation, or {revoked_at, strategy} when it does."
  def allowed_groups_string_revoked?(allowed_groups_string) do
    case :ets.lookup(@allowed_groups_string_table, allowed_groups_string) do
      [{^allowed_groups_string, revoked_at, strategy}] -> {revoked_at, strategy}
      [] -> nil
    end
  end

  ###
  # GenServer API
  ###

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    :ets.new(@session_id_string_table, [:named_table, :set, :protected, read_concurrency: true])
    :ets.new(@allowed_groups_string_table, [:named_table, :set, :protected, read_concurrency: true])

    schedule_cleanup()
    {:ok, %{}}
  end

  @impl true
  def handle_call({:revoke_mu_session_id, mu_session_id, strategy}, _from, state) do
    :ets.insert(@session_id_string_table, {mu_session_id, System.os_time(:second), strategy})
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:revoke_mu_auth_allowed_groups_string, allowed_groups_string, strategy}, _from, state) do
    :ets.insert(@allowed_groups_string_table, {allowed_groups_string, System.os_time(:second), strategy})
    {:reply, :ok, state}
  end

  @impl true
  def handle_info(:cleanup, state) do
    ttl = Application.get_env(:mu_identifier, :default_session_ttl_seconds)
    cutoff = System.os_time(:second) - ttl * 2

    :ets.select_delete(@session_id_string_table, [{{:_, :"$1", :_}, [{:<, :"$1", cutoff}], [true]}])
    :ets.select_delete(@allowed_groups_string_table, [{{:_, :"$1", :_}, [{:<, :"$1", cutoff}], [true]}])

    schedule_cleanup()
    {:noreply, state}
  end

  defp schedule_cleanup do
    case Application.get_env(:mu_identifier, :default_session_ttl_seconds) do
      nil -> :ok
      ttl -> Process.send_after(self(), :cleanup, ttl * 1000)
    end
  end
end
