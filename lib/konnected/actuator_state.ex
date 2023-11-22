defmodule Konnected.ActuatorState do
  defstruct id: nil, device_id: nil, zone: nil, state: 0, times: -1, momentary: 500, pause: 1000
  def new(device_id, zone) do
    %Konnected.ActuatorState{id: "#{device_id}-#{zone}", device_id: device_id, zone: zone}
  end

  def json(%Konnected.ActuatorState{zone: zone, state: state, times: times, momentary: momentary, pause: pause}) do
    %{
      zone: "#{zone}",
      state: state,
      times: times,
      momentary: momentary,
      pause: pause
    }
  end
end
