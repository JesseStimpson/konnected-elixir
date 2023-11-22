defmodule Konnected.Api do
  defstruct [
    :req,
    :ds18b20_sesnsors,
    :gw,
    :heap,
    :hw_version,
    :ip,
    :mac,
    :nm,
    :port,
    :rssi,
    :endpoint,
    :sw_version,
    :uptime,
    :sensors_map,
    :actuators_map,
    :dht_sensors,
    :lock,
    :token,
    :pwd
  ]
  alias Konnected.Api

  @try_req_attempts(10)
  @try_req_sleep_base(50)

  def new(host, port) do
    %Api{req: Req.new(base_url: "http://#{host}:#{port}")}
  end

  def with_endpoint(api, endpoint) do
    %Api{api | endpoint: endpoint}
  end

  def with_secrets(api, token, pwd) do
    %Api{api | token: token, pwd: pwd}
  end

  def with_sensors(api, zones) do
    sensors = for z <- zones, do: %{"zone" => "#{z}"}
    %Api{api | sensors_map: zones_to_map(sensors)}
  end

  def with_actuators(api, kw) do
    actuators = for {zone, trigger} <- kw, do: %{"zone" => "#{zone}", "trigger" => trigger}
    %Api{api | actuators_map: zones_to_map(actuators)}
  end

  def get_status!(api=%Api{req: req}) do
    %Req.Response{
      status: 200,
      body: %{
        "actuators" => actuators,
        "dht_sensors" => dht_sensors,
        "ds18b20_sensors" => ds18b20_sensors,
        "gw" => gw,
        "heap" => heap,
        "hwVersion" => hw_version,
        "ip" => ip,
        "mac" => mac,
        "nm" => nm,
        "port" => port,
        "rssi" => rssi,
        "sensors" => sensors,
        "settings" => %{"endpoint" => endpoint},
        "swVersion" => sw_version,
        "uptime" => uptime
    }
    } = Req.get!(req, url: "/status")
    %Api{api |
      dht_sensors: dht_sensors,
      ds18b20_sesnsors: ds18b20_sensors,
      gw: gw,
      heap: heap,
      hw_version: hw_version,
      ip: ip,
      mac: mac,
      nm: nm,
      port: port,
      rssi: rssi,
      endpoint: endpoint,
      sensors_map: zones_to_map(sensors),
      actuators_map: zones_to_map(actuators),
      sw_version: sw_version,
      uptime: uptime
    }
  end

  def post_settings!(api=%Api{token: token}) when not is_nil(token) do
    f = fn api=%Api{req: req, endpoint: endpoint, token: token, sensors_map: sensors_map, actuators_map: actuators_map} ->
      %Req.Response{status: 200} = Req.post!(req, url: "/settings", json: %{
      endpoint: endpoint,
      token: token,
      sensors: (for sensor <- map_to_zones(sensors_map), do: Map.take(sensor, ["zone"])),
      actuators: (for actuator <- map_to_zones(actuators_map), do: Map.take(actuator, ["zone", "trigger"]))
      })
      api
    end
    api = try_req!(api, f, @try_req_attempts, @try_req_sleep_base)

    # After posting settings, the device reboots. If we send reqs before the boot, we get bad data
    wait_for_boot!(api)
  end

  def wait_for_boot!(api) do
    :timer.sleep(5000)
    api
  end

  def get_lock!(api) do
    f = fn api=%Api{req: req} ->
      %Req.Response{status: 200, body: %{"state" => lock}} = Req.get!(req, url: "/lock")
      %Api{api | lock: lock}
    end
    try_req!(api, f, @try_req_attempts, @try_req_sleep_base)
  end

  def put_lock!(api) do
    case get_lock!(api) do
      api=%Api{lock: "locked"} ->
        api
      api=%Api{lock: "unlocked"} ->
        change_lock!(api, @try_req_attempts, @try_req_sleep_base)
    end
  end

  def put_unlock!(api) do
    case get_lock!(api) do
      api=%Api{lock: "unlocked"} ->
        api
      api=%Api{lock: "locked"} ->
        change_lock!(api, @try_req_attempts, @try_req_sleep_base)
    end
  end

  def get_sensors!(api) do
    f = fn api=%Api{req: req} ->
      %Req.Response{status: 200, body: sensors} = Req.get!(req, url: "/zone")
      %Api{ api | sensors_map: zones_to_map(sensors) }
    end
    try_req!(api, f, @try_req_attempts, @try_req_sleep_base)
  end

  def put_actuator!(api, actuator_state) do
    f = fn api=%Api{req: req} ->
      %Req.Response{status: 200} = Req.put!(req, url: "/zone", json: Konnected.ActuatorState.json(actuator_state))
      api
    end
    try_req!(api, f, @try_req_attempts, @try_req_sleep_base)
  end

  defp change_lock!(api=%Api{pwd: pwd}, attempts, sleep) when not is_nil(pwd) do
    f = fn api=%Api{req: req, pwd: pwd} ->
        %Req.Response{status: 200, body: %{"state" => lock}} = Req.put!(req, url: "/lock", json: %{pwd: pwd})
        %Api{api | lock: lock}
    end
    try_req!(api, f, attempts, sleep)
  end

  defp try_req!(api, f, attempts, sleep) do
      try do
        f.(api)
      rescue
        t in Mint.TransportError ->
          # There is a bug on my Konnected platform which caueses the API to close the HTTP connection early
          # on an attempt to unlock. Providing an exponential backoff sleep and retry seems to workaround the
          # issue.
          if attempts == 0, do: reraise(t, __STACKTRACE__)
          :timer.sleep(sleep)
          try_req!(api, f, attempts-1, sleep*2)
      end
  end

  def zones_to_map(sensors) do
    (for sensor=%{"zone" => zone} <- sensors, do: {zone, sensor})
    |> Enum.into(%{})
  end

  def map_to_zones(map) do
    Map.values(map)
  end
end
