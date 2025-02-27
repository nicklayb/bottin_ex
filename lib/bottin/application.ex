defmodule Bottin.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Cluster.Supervisor,
       [
         [
           example: [
             strategy: Cluster.Strategy.LocalEpmd
           ]
         ],
         [name: Bottin.ClusterSupervisor]
       ]},
      {Bottin, name: Bottin.MasterSupervisor}
    ]

    opts = [strategy: :one_for_one, name: Bottin.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
