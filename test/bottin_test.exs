defmodule BottinTest do
  use ExUnit.Case
  doctest Bottin

  test "greets the world" do
    assert Bottin.hello() == :world
  end
end
