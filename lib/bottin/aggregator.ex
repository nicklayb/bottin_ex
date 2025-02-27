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

    send(self(), {:attach_outside, nodes})

    {:ok, %{supervisor_name: supervisor_name, local_name: local_name, nodes: %{}, store: %{}}}
  end

  def attach(local_name, source_node, source_pid) do
    GenServer.cast(local_name, {:attach, source_node, source_pid, false})
  end

  def attach_back(local_name, source_node, source_pid) do
    GenServer.cast(local_name, {:attach, source_node, source_pid, true})
  end

  def register(aggregator_name, name, pid) do
    GenServer.call(aggregator_name, {:register, name, Node.self(), pid})
  end

  def sync(aggregator_name, store) do
    GenServer.cast(aggregator_name, {:sync, store})
  end

  def append_name(aggregator_name, name, node, pid) do
    GenServer.cast(aggregator_name, {:append_name, name, node, pid})
  end

  def remove_name(aggregator_name, pid) do
    GenServer.cast(aggregator_name, {:remove_name, pid})
  end

  def store(aggregator_name) do
    GenServer.call(aggregator_name, :store)
  end

  def handle_call(:store, _, %{store: store} = state) do
    {:reply, store, state}
  end

  def handle_call({:register, name, node, pid}, _, state) do
    if Map.get(state.store, name) do
      {:reply, {:error, :already_registered}, state}
    else
      state = map_store(state, &Map.put(&1, name, {node, pid}))
      Process.monitor(pid)

      call_nodes(state, Bottin.Aggregator, :append_name, [state.local_name, name, node, pid])
      {:reply, :ok, state}
    end
  end

  def handle_cast({:sync, store}, state) do
    state = map_store(state, fn _ -> store end)
    {:noreply, state}
  end

  def handle_cast({:append_name, name, node, pid}, state) do
    state = map_store(state, &Map.put(&1, name, {node, pid}))

    {:noreply, state}
  end

  def handle_cast({:remove_name, key}, state) do
    state = map_store(state, &Map.delete(&1, key))

    {:noreply, state}
  end

  def handle_cast({:attach, source_node, source_pid, attaching_back?}, state) do
    Logger.info(
      "#{inspect(__MODULE__)}.attach node=#{inspect(source_node)} pid=#{inspect(source_pid)}"
    )

    if not attaching_back? do
      :rpc.call(source_node, Bottin.Aggregator, :attach_back, [
        state.local_name,
        Node.self(),
        self()
      ])

      :rpc.call(source_node, Bottin.Aggregator, :sync, [state.local_name, state.store])
    end

    {:noreply, attach_node(state, {source_node, source_pid})}
  end

  def handle_info({:DOWN, _ref, :process, pid, _}, state) do
    state =
      map_store(state, fn map ->
        key = Enum.find_value(map, fn {key, {_, ^pid}} -> key end)

        if key do
          call_nodes(state, Bottin.Aggregator, :remove_name, [state.local_name, key])

          Map.delete(map, key)
        end
      end)

    {:noreply, state}
  end

  def handle_info({:attach_outside, nodes}, state) do
    self_node = Node.self()
    self_pid = self()

    call_nodes(nodes, Bottin.Aggregator, :attach, [state.local_name, self_node, self_pid])

    {:noreply, state}
  end

  def handle_info({:nodedown, node}, state) do
    Logger.info("#{inspect(__MODULE__)}.nodedown node=#{node}")
    {:noreply, map_nodes(state, &Map.delete(&1, node))}
  end

  defp call_nodes(%{nodes: nodes}, module, function, arguments) do
    nodes
    |> Enum.map(fn {key, _} -> key end)
    |> call_nodes(module, function, arguments)
  end

  defp call_nodes(nodes, module, function, arguments) do
    Enum.each(
      nodes,
      &:rpc.call(&1, module, function, arguments)
    )
  end

  defp attach_node(state, {node, pid}) do
    Node.monitor(node, true)

    map_nodes(state, &Map.put(&1, node, pid))
  end

  defp map_nodes(state, function) do
    Map.update!(state, :nodes, function)
    |> tap(&IO.inspect(&1.nodes, label: "Nodes"))
  end

  defp map_store(state, function) do
    Map.update!(state, :store, function)
    |> tap(&IO.inspect(&1.store, label: "Store"))
  end
end
