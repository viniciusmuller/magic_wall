defmodule MagicWallTest do
  use ExUnit.Case
  doctest MagicWall

  test "greets the world" do
    assert MagicWall.hello() == :world
  end
end
