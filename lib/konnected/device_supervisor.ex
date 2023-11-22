require Logger
defmodule Konnected.DeviceSupervisor do
  # Automatically defines child_spec/1
  use DynamicSupervisor

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def update_sensor!(sensor_state=%Konnected.SensorState{device_id: device_id}) do
    Konnected.DeviceServer.update_sensor(get_child!(device_id), sensor_state)
  end

  def actuate!(actuator_state=%Konnected.ActuatorState{device_id: device_id}) do
    Konnected.DeviceServer.actuate(get_child!(device_id), actuator_state)
  end

  def get_sensors!(device_id) do
    Konnected.DeviceServer.get_sensors(get_child!(device_id))
  end

  def get_actuators!(device_id) do
    Konnected.DeviceServer.get_actuators(get_child!(device_id))
  end

  def get_all_sensors() do
    ll = (for {_, pid, _, _} <- DynamicSupervisor.which_children(__MODULE__) do
      Konnected.DeviceServer.get_sensors(pid)
      end)
    List.flatten(ll)
  end

  def get_child!(device_id) do
    case get_child(DynamicSupervisor.which_children(__MODULE__), device_id) do
      pid when is_pid(pid) ->
        pid
    end
  end

  defp get_child([], _device_id), do: nil
  defp get_child([{_, pid, _, _}|t], device_id) do
    case Konnected.DeviceServer.get_device_id(pid) do
      ^device_id ->
        pid
      _ ->
        get_child(t, device_id)
    end
  end

  def start_child(kw) do
    DynamicSupervisor.start_child(__MODULE__, {Konnected.DeviceServer, kw})
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
