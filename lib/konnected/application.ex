require Logger
defmodule Konnected.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Starts a worker by calling: Konnected.Worker.start_link(arg)
      # {Konnected.Worker, arg}
      Konnected.DeviceSupervisor,
      %{
        id: Konnected.StartConfig,
        start: {__MODULE__, :start_config, []}
      }
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Konnected.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def start_config() do
    config = Application.fetch_env!(:konnected, Konnected)
    devices = Keyword.get(config, :devices, [])
    for device <- devices, do: Konnected.DeviceSupervisor.start_child(device ++ [token: config[:token]])
    :ignore
  end
end
