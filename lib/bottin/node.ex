defmodule Bottin.Node do
  def other_nodes do
    this_node = Node.self()
    Enum.reject(Node.list(), &(&1 == this_node))
  end
end
