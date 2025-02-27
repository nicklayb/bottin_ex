defmodule Bottin do
  use Supervisor

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: Keyword.fetch!(args, :name))
  end

  def init(args) do
    children = [
      {Bottin.Aggregator, supervisor_name: Keyword.fetch!(args, :name)}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
