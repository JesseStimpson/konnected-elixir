require Logger

defmodule Konnected.DeviceServer do
  use GenServer

  alias Konnected.Api
  alias Konnected.SensorState
  alias Konnected.ActuatorState

  def start_link(kw) do
    GenServer.start_link(Konnected.DeviceServer, kw)
  end

  def get_device_id(pid) do
    GenServer.call(pid, :get_device_id, :infinity)
  end

  def update_sensor(pid, sensor_state) do
    GenServer.cast(pid, {:update_sensor, sensor_state})
  end

  def actuate(pid, actuator_state) do
    GenServer.call(pid, {:actuate, actuator_state}, :infinity)
  end

  def get_sensors(pid) do
    GenServer.call(pid, :get_sensors, :infinity)
  end

  def get_actuators(pid) do
    GenServer.call(pid, :get_actuators, :infinity)
  end

  # Callbacks

  @impl true
  def init(kw) do
    api = Api.new(kw[:host], kw[:port])
    |> Api.with_secrets(kw[:token], kw[:pwd])
    |> Api.with_endpoint(kw[:endpoint])
    |> Api.with_sensors(kw[:sensors])
    |> Api.with_actuators(kw[:actuators])

    GenServer.cast(self(), :make_ready)

    {:ok, %{
      device_id: kw[:device_id],
      api: api,
      ready: false,
      sensors: %{},
      actuators: %{},
      notify: kw[:notify]
      }}
  end

  @impl true
  def handle_call(:get_device_id, _from, state=%{device_id: device_id}) do
    {:reply, device_id, state}
  end

  def handle_call(:get_sensors, _from, state=%{sensors: sensors}) do
    {:reply, Map.values(sensors), state}
  end

  def handle_call(:get_actuators, _from, state=%{actuators: actuators}) do
    {:reply, Map.values(actuators), state}
  end

  def handle_call({:actuate, actuator_state=%ActuatorState{id: id}}, _from, state=%{api: api, actuators: actuators}) do
    try do
      api = Api.put_actuator!(api, actuator_state)
      {:reply, :ok, %{state | api: api, actuators: Map.put(actuators, id, actuator_state)}}
    rescue
      err ->
          Logger.error(Exception.format(:error, err, __STACKTRACE__))
          {:reply, {:error, err}, state}
    end
  end

  @impl true
  def handle_cast(:make_ready, state=%{device_id: device_id, api: api, notify: notify}) do
    try do
      api = api
      |> maybe_put_unlock!()
      |> Api.post_settings!()
      |> maybe_put_lock!()
      |> Api.get_status!()
      |> Api.get_sensors!()

      %Api{sensors_map: sensors_map} = api

      sensor_states = for %{"zone" => zone, "state" => state} <- Api.map_to_zones(sensors_map), do: SensorState.new(device_id, zone, state)
      sensors = (for ss=%SensorState{id: id} <- sensor_states, do: {id, ss}) |> Enum.into(%{})
      notify.(sensor_states)
      {:noreply, %{state | api: api, ready: true, sensors: sensors}}
    rescue
      err ->
          Logger.error(Exception.format(:error, err, __STACKTRACE__))
          GenServer.cast(self(), :make_ready)
          {:noreply, state}
    end
  end
  def handle_cast({:update_sensor, sensor_state=%SensorState{id: id}}, state=%{sensors: sensors, notify: notify}) do
    notify.([sensor_state])
    sensors = Map.put(sensors, id, sensor_state)
    {:noreply, %{state | sensors: sensors}}
  end

  defp maybe_put_unlock!(api=%Api{pwd: nil}), do: api
  defp maybe_put_unlock!(api), do: Api.put_unlock!(api)

  defp maybe_put_lock!(api=%Api{pwd: nil}), do: api
  defp maybe_put_lock!(api), do: Api.put_lock!(api)
end
