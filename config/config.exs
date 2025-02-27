import Config

config :libcluster,
  topologies: [
    bottin: [
      strategy: Cluster.Strategy.LocalEpmd
    ]
  ]
