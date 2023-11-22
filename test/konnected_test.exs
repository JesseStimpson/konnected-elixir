defmodule KonnectedTest do
  use ExUnit.Case, async: true
  use Plug.Test

  @token("testtoken")

  doctest Konnected

  test "greets the world" do
    assert Konnected.hello() == :world
  end

  test "Konnected.Plug.Device PUT" do
    device_state_body = %{"zone" => "1", "state" => 0}
    device_plug = Konnected.Plug.Device.init(token: @token, device_supervisor: nil)
    parser = Plug.Parsers.init(parsers: [:json], json_decoder: Jason)

    conn = conn(:put, "/device/deviceId", Jason.encode!(device_state_body))
           |> put_req_header("authorization", "Bearer #{@token}")
           |> put_req_header("content-type", "application/json")
           |> Plug.Parsers.call(parser)
           |> Konnected.Plug.Device.call(device_plug)

    assert %Konnected.SensorState{id: "deviceId-1", device_id: "deviceId", zone: "1", state: 0}
              = conn.assigns[:konnected]
  end

  test "Konnected.Plug.Device GET DENY" do
    device_plug = Konnected.Plug.Device.init(token: @token)
    conn = conn(:get, "/device/deviceId")
           |> put_req_header("authorization", "Bearer wrongtoken")
           |> put_req_header("accept", "application/json")
           |> Konnected.Plug.Device.call(device_plug)
    assert %Plug.Conn{status: 401} = conn
  end

  test "Konnected.Plug.Device GET" do
    device_plug = Konnected.Plug.Device.init(token: @token, device_supervisor: nil)
    conn = conn(:get, "/device/deviceId")
           |> put_req_header("authorization", "Bearer #{@token}")
           |> put_req_header("accept", "application/json")
           |> Konnected.Plug.Device.call(device_plug)
    assert %Plug.Conn{status: 200} = conn
    %Plug.Conn{resp_body: resp_body} = conn
    assert [
      %{"zone" => "1", "state" => 0},
      %{"zone" => "2", "state" => 0},
      %{"zone" => "3", "state" => 0},
      %{"zone" => "4", "state" => 0},
      %{"zone" => "5", "state" => 0},
      %{"zone" => "6", "state" => 0}] = Jason.decode!(resp_body)
  end
end
