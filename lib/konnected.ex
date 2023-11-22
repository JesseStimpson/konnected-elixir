defmodule Konnected do
  @moduledoc """
  Documentation for `Konnected`.
  """

  @doc """
  Hello world.

  ## Examples

      iex> Konnected.hello()
      :world

  """
  def hello do
    :world
  end

  def sensors() do
    Konnected.DeviceSupervisor.get_all_sensors()
  end
end
