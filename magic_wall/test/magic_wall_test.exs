defmodule MagicWallTest do
  use ExUnit.Case
  doctest MagicWall
  doctest MagicWall.Wall

  test "greets the world" do
    assert MagicWall.hello() == :world
  end
end
