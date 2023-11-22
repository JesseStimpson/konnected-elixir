require Logger
defmodule Konnected.Plug.Device do
  @behaviour Plug

  def init(kw) do
    config = Application.get_env(:konnected, Konnected, [])
    token = Keyword.get(kw, :token, config[:token])
    %{token: token, device_supervisor: Keyword.get(kw, :device_supervisor, Konnected.DeviceSupervisor)}
  end

  def call(conn=%Plug.Conn{
    method: "GET",
    req_headers: req_headers,
    path_info: path_info,
    query_params: %{"zone" => _zone}
    }, init_data) do
    # API docs are unclear on the expected response from the GET API. Might be bugs!
      device_id = get_device_id!(path_info)
      case check_authentication(conn, init_data) do
        true ->
          actuators = get_actuators!(device_id, init_data)
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.resp(200, Jason.encode!(actuators))
        false ->
          Logger.info("[Konnected] Denied GET from #{device_id} with headers #{inspect(req_headers)}")
          Plug.Conn.resp(conn, 401, "")
      end
  end
  def call(conn=%Plug.Conn{
    method: "GET",
    req_headers: req_headers,
    path_info: path_info
    }, init_data) do
      device_id = get_device_id!(path_info)
      case check_authentication(conn, init_data) do
        true ->
          actuators = get_actuators!(device_id, init_data)
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.resp(200, Jason.encode!(actuators))
        false ->
          Logger.info("[Konnected] Denied GET from #{device_id} with headers #{inspect(req_headers)}")
          Plug.Conn.resp(conn, 401, "")
      end
  end
  def call(conn=%Plug.Conn{
    method: "PUT",
    req_headers: req_headers,
    path_info: path_info,
    params: params
    }, init_data) do
      device_id = get_device_id!(path_info)
      case check_authentication(conn, init_data) do
        true ->
          params = Map.put(params, "id", device_id)
          sensor_state = Konnected.SensorState.new(params)
          update_sensor!(sensor_state, init_data)

          conn
          |> Plug.Conn.assign(:konnected, sensor_state)
          |> Plug.Conn.resp(200, "")
        false ->
          Logger.info("[Konnected] Denied PUT from #{device_id} with headers #{inspect(req_headers)}")
          Plug.Conn.resp(conn, 401, "")
      end
  end

  defp check_authentication(%Plug.Conn{req_headers: req_headers}, init_data), do: check_authentication(req_headers, init_data)
  defp check_authentication([], _), do: false
  defp check_authentication([{"authorization", "Bearer " <> test_token}|_], %{token: real_token}), do: test_token == real_token
  defp check_authentication([_h|t], init_data), do: check_authentication(t, init_data)

  # /.../device/:id/..." must be in path
  defp get_device_id!(["device", device_id|_]), do: device_id
  defp get_device_id!([_h|t]), do: get_device_id!(t)

  defp update_sensor!(_sensor_state, %{device_supervisor: nil}), do: :ok
  defp update_sensor!(sensor_state, %{device_supervisor: mod}) do
    Logger.info("[Konnected] Received new sensor state #{inspect(sensor_state)}")
    mod.update_sensor!(sensor_state)
  end

  defp get_actuators!(_device_id, %{device_supervisor: nil}), do: (for z <- [1,2,3,4,5,6], do: %{"zone" => "#{z}", "state" => 0})
  defp get_actuators!(device_id, %{device_supervisor: mod}), do: mod.get_actuators!(device_id)
end
