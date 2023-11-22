defmodule Konnected.SensorState do
  defstruct [:id, :device_id, :zone, :state]
  def new(device_id, zone, state) do
    %Konnected.SensorState{id: "#{device_id}-#{zone}", device_id: device_id, zone: zone, state: state}
  end

  def new(%{"id" => device_id, "zone" => zone, "state" => state}) do
    new(device_id, zone, state)
  end
end
