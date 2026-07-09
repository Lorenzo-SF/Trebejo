defmodule TrebejoTest do
  use ExUnit.Case
  doctest Trebejo

  test "Trebejo module is defined" do
    assert {:module, _} = Code.ensure_loaded(Trebejo)
  end

  test "Trebejo.Application module is defined" do
    assert {:module, _} = Code.ensure_loaded(Trebejo.Application)
  end
end
