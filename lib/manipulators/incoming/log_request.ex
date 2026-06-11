defmodule Manipulators.Incoming.LogRequest do
  @behaviour ProxyManipulator

  @impl true
  def headers(headers, {frontend_connection, backend_connection}) do
    if Application.get_env(:mu_identifier, :log_incoming_headers) do
      IO.inspect( headers, label: "Incoming headers" )
    end

    if Application.get_env(:mu_identifier, :log_incoming_headers_connections) do
      IO.inspect( frontend_connection, label: "frontend connection for incoming headers" )
      IO.inspect( backend_connection, label: "backend connection for incoming headers" )
    end

    { headers, { frontend_connection, backend_connection } }
  end
  
  @impl true
  def chunk(chunk, {frontend_connection,backend_connection}) do
    if Application.get_env(:mu_identifier, :log_incoming_chunk) do
      IO.inspect( chunk, label: "Incoming chunk" )
    end

    if Application.get_env(:mu_identifier, :log_incoming_chunk_connections) do
      IO.inspect( frontend_connection, label: "frontend connection for incoming chunk" )
      IO.inspect( backend_connection, label: "backend connection for incoming chunk" )
    end

    :skip
  end

  @impl true
  def finish(bool, {frontend_connection,backend_connection}) do
    if Application.get_env(:mu_identifier, :log_incoming_finish) do
      IO.inspect( bool, label: "Finish boolean" )
    end

    if Application.get_env(:mu_identifier, :log_incoming_finish_connections) do
      IO.inspect( frontend_connection, label: "frontend connection for incoming finish" )
      IO.inspect( backend_connection, label: "backend connection for incoming finish" )
    end

    :skip
  end
end
