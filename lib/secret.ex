defmodule Secret do
  use GenServer

  def secret_key_base() do
    case GenServer.call( __MODULE__, { :secret_key_base } ) do
      { :ok, response } -> response
    end
  end
  
  ###
  # GenServer API
  ###

  def start_link(_) do
    GenServer.start_link( __MODULE__, [%{secret_key_base: nil}], name: __MODULE__ )
  end

  def init(_) do
    {:ok, %{secret_key_base: Application.get_env(:proxy, :secret_key_base) || SecureRandom.urlsafe_base64(128)}}
  end

  def handle_call({:secret_key_base}, _from, state) do
    { :reply, { :ok, state.secret_key_base }, state }
  end
  
end
