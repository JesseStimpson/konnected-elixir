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
    endpoint_config = Keyword.get(config, :endpoint, [])
    devices = Keyword.get(config, :devices, [])
    for device <- devices, do: Konnected.DeviceSupervisor.start_child(device ++ [token: config[:token], endpoint: endpoint(endpoint_config)])
    :ignore
  end

  defp endpoint(endpoint_config) do
    host = case endpoint_config[:host] do
      :auto ->
        {:ok, addr} = get_addr_auto(100)
        addr
          |> Tuple.to_list()
          |> Enum.map(&Integer.to_string/1)
          |> Enum.join(".")
      h ->
        h
    end
    port = Keyword.get(endpoint_config, :port, 80)
    "http://#{host}:#{port}#{endpoint_config[:path]}"
  end

  defp get_addr_auto(sleep) when sleep > 20000 do
    {:error, :timeout}
  end
  defp get_addr_auto(sleep) do
    {:ok, ifs} = :inet.getif()
    case Enum.filter(ifs, fn {{192, 168, _, _}, _, _} -> true; _ -> false end) do
      [{addr, _, _}|_] ->
        {:ok, addr}
      [] ->
        Logger.info("Unable to find addr among #{inspect(ifs)}. Sleeping #{sleep}...")
        :timer.sleep(sleep)
        get_addr_auto(sleep*2)
    end
  end

end
