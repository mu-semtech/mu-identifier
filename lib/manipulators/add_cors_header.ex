defmodule Manipulators.AddCorsHeader do
  @behaviour ProxyManipulator

  @impl true
  def headers(headers, connection) do
    # Adds the CORS header to the list of headers
    default_cors_header = Application.get_env(:mu_identifier, :default_access_control_allow_origin_header)

    headers =
      if default_cors_header do
        put_new_key(headers, "Access-Control-Allow-Origin", default_cors_header)
      else
        headers
      end

    { headers, connection }
  end

  @impl true
  def chunk(_,_), do: :skip

  @impl true
  def finish(_,_), do: :skip

  defp put_new_key(list, key, value) do
    # Adds the key/value tuple to the list, unless it is already there

    if List.keymember?(list, key, 0) do
      list
    else
      [{key, value} | list]
    end
  end
end
