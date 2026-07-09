defmodule Trebejo.ModulePresenceTest do
  use ExUnit.Case

  @expected_modules [
    Trebejo.Docker,
    Trebejo.Git,
    Trebejo.Git.Local,
    Trebejo.SSH,
    Trebejo.Kubernetes,
    Trebejo.Compress,
    Trebejo.Network,
    Trebejo.OS,
    Trebejo.Proc,
    Trebejo.File,
    Trebejo.File.IO
  ]

  test "all migrated modules are defined" do
    for mod <- @expected_modules do
      assert {:module, ^mod} = Code.ensure_loaded(mod),
             "Expected module #{inspect(mod)} to be defined"
    end
  end

  test "Arrea.Command is accessible (trebejo depends on arrea)" do
    assert {:module, _} = Code.ensure_loaded(Arrea.Command)
  end

  test "Apero is accessible (trebejo depends on apero)" do
    assert {:module, _} = Code.ensure_loaded(Apero)
  end

  test "Apero.File.Watcher is accessible (used by Trebejo.File.watch/3)" do
    assert {:module, _} = Code.ensure_loaded(Apero.File.Watcher)
  end
end
