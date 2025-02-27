defmodule Bottin.Aggregator do
  use GenServer

  require Logger

  def start_link(args) do
    supervisor_name = Keyword.fetch!(args, :supervisor_name)
    name = Module.concat(supervisor_name, Aggregator)
    GenServer.start_link(__MODULE__, [supervisor_name: supervisor_name, name: name], name: name)
  end

  def init(args) do
    local_name = Keyword.fetch!(args, :name)
    supervisor_name = Keyword.fetch!(args, :supervisor_name)

    nodes = Bottin.Node.other_nodes()

    # :net_kernel.monitor_nodes(true)

    send(self(), {:register_outside, nodes})

    {:ok, %{supervisor_name: supervisor_name, local_name: local_name, registered: %{}}}
  end

  def register(local_name, source_node, source_pid) do
    GenServer.cast(local_name, {:register, source_node, source_pid, false})
  end

  def register_back(local_name, source_node, source_pid) do
    GenServer.cast(local_name, {:register, source_node, source_pid, true})
  end

  def handle_cast({:register, source_node, source_pid, registering_back?}, state) do
    Logger.info(
      "#{inspect(__MODULE__)}.register node=#{inspect(source_node)} pid=#{inspect(source_pid)}"
    )

    state = Map.update!(state, :registered, &Map.put(&1, source_node, source_pid))
    Node.monitor(source_node, true)

    if not registering_back? do
      :rpc.call(source_node, Bottin.Aggregator, :register_back, [
        state.local_name,
        Node.self(),
        self()
      ])
    end

    {:noreply, state}
  end

  def handle_info({:register_outside, nodes}, state) do
    Enum.each(nodes, &Node.monitor(&1, true))

    self_node = Node.self()
    self_pid = self()

    Enum.each(
      nodes,
      &:rpc.call(&1, Bottin.Aggregator, :register, [state.local_name, self_node, self_pid])
    )

    {:noreply, state}
  end

  def handle_info({:nodeup, node}, state) do
  end

  def handle_info({:nodedown, node}, state) do
    Logger.info("#{inspect(__MODULE__)}.nodedown node: #{node}")
    {:noreply, Map.update!(state, :registered, &Map.delete(&1, node))}
  end

  defp register_node(state, node) do
  end
end
