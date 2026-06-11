defmodule Manipulators.Outgoing.LogRequest do
  @behaviour ProxyManipulator

  @impl true
  def headers(headers, {frontend_connection, backend_connection}) do
    if Application.get_env(:mu_identifier, :log_outgoing_headers) do
      IO.inspect( headers, label: "Outgoing headers" )
    end

    if Application.get_env(:mu_identifier, :log_outgoing_headers_connections) do
      IO.inspect( frontend_connection, label: "frontend connection for outgoing headers" )
      IO.inspect( backend_connection, label: "backend connection for outgoing headers" )
    end

    { headers, { frontend_connection, backend_connection } }
  end
  
  @impl true
  def chunk(chunk, {frontend_connection,backend_connection}) do
    if Application.get_env(:mu_identifier, :log_outgoing_chunk) do
      IO.inspect( chunk, label: "Outgoing chunk" )
    end

    if Application.get_env(:mu_identifier, :log_outgoing_chunk_connections) do
      IO.inspect( frontend_connection, label: "frontend connection for outgoing chunk" )
      IO.inspect( backend_connection, label: "backend connection for outgoing chunk" )
    end

    :skip
  end

  @impl true
  def finish(bool, {frontend_connection,backend_connection}) do
    if Application.get_env(:mu_identifier, :log_outgoing_finish) do
      IO.inspect( bool, label: "Finish boolean" )
    end

    if Application.get_env(:mu_identifier, :log_outgoing_finish_connections) do
      IO.inspect( frontend_connection, label: "frontend connection for outgoing finish" )
      IO.inspect( backend_connection, label: "backend connection for outgoing finish" )
    end

    :skip
  end
end
