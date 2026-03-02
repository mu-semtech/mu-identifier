defmodule SessionRevocation do
  @moduledoc """
  Revokes mu-auth-allowed-groups or mu-session-id

  Both mu-auth-allowed-groups and mu-session-id are currently revoked based on their string value.

  Revocation entries persist until their individual expiry, set at revocation time.  When no
  explicit duration is supplied, entries persist for 2x DEFAULT_SESSION_MAX_AGE_SECONDS.  When
  DEFAULT_SESSION_MAX_AGE_SECONDS is not configured either, entries are never purged.

  Note that a backend may have set a session lifetime longer than DEFAULT_SESSION_MAX_AGE_SECONDS.
  In that case, supply an explicit duration when revoking to ensure the entry outlives the session.
  """

  use GenServer

  @session_id_string_table :revoked_session_id_strings
  @allowed_groups_string_table :revoked_allowed_groups_strings

  def revoke_mu_session_id(mu_session_id, strategy, persist_seconds \\ nil) do
    GenServer.call(__MODULE__, {:revoke_mu_session_id, mu_session_id, strategy, persist_seconds})
  end

  def revoke_mu_auth_allowed_groups_string(allowed_groups_string, strategy, persist_seconds \\ nil) do
    GenServer.call(__MODULE__, {:revoke_mu_auth_allowed_groups_string, allowed_groups_string, strategy, persist_seconds})
  end

  @doc "Returns nil when the session URI has no pending revocation, or the strategy atom when it does."
  def mu_session_id_revoked?(mu_session_id) do
    case :ets.lookup(@session_id_string_table, mu_session_id) do
      [{^mu_session_id, _revoked_at, strategy, _persist_until}] -> strategy
      [] -> nil
    end
  end

  @doc "Returns nil when the groups string has no pending revocation, or {revoked_at, strategy} when it does."
  def allowed_groups_string_revoked?(allowed_groups_string) do
    case :ets.lookup(@allowed_groups_string_table, allowed_groups_string) do
      [{^allowed_groups_string, revoked_at, strategy, _persist_until}] -> {revoked_at, strategy}
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
  def handle_call({:revoke_mu_session_id, mu_session_id, strategy, persist_seconds}, _from, state) do
    now = System.os_time(:second)
    :ets.insert(@session_id_string_table, {mu_session_id, now, strategy, persist_until(now, persist_seconds)})
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:revoke_mu_auth_allowed_groups_string, allowed_groups_string, strategy, persist_seconds}, _from, state) do
    now = System.os_time(:second)
    :ets.insert(@allowed_groups_string_table, {allowed_groups_string, now, strategy, persist_until(now, persist_seconds)})
    {:reply, :ok, state}
  end

  @impl true
  def handle_info(:cleanup, state) do
    now = System.os_time(:second)

    :ets.select_delete(@session_id_string_table, [{{:_, :_, :_, :"$1"}, [{:<, :"$1", now}], [true]}])
    :ets.select_delete(@allowed_groups_string_table, [{{:_, :_, :_, :"$1"}, [{:<, :"$1", now}], [true]}])

    schedule_cleanup()
    {:noreply, state}
  end

  defp persist_until(now, nil) do
    case Application.get_env(:mu_identifier, :default_session_max_age_seconds) do
      nil -> :infinity
      seconds -> now + seconds * 2
    end
  end
  defp persist_until(now, persist_seconds), do: now + persist_seconds

  defp schedule_cleanup do
    case Application.get_env(:mu_identifier, :default_session_max_age_seconds) do
      nil -> :ok
      ttl -> Process.send_after(self(), :cleanup, ttl * 1000)
    end
  end
end
