defmodule Trebejo.MoxTest do
  use ExUnit.Case, async: false

  alias Trebejo.Mox
  alias Trebejo.Runner

  setup do
    Mox.reset_stubs()
    previous = :persistent_term.get({Runner, :runner}, :unset)
    Runner.set_runner(Mox.Runner)

    on_exit(fn ->
      case previous do
        :unset -> :ok
        mod -> Runner.set_runner(mod)
      end
    end)

    :ok
  end

  test "stub_cmd/3 intercepts exact call" do
    Mox.stub_cmd("echo", ["hello"], {:ok, "MOCKED\n", 0})
    assert {:ok, "MOCKED\n", 0} = Runner.run("echo", ["hello"], [])
  end

  test "stub_cmd/3 does not intercept other args" do
    Mox.stub_cmd("echo", ["hello"], {:ok, "MOCKED\n", 0})
    assert {:error, :no_stub_for_command} = Runner.run("echo", ["other"], [])
  end

  test "stub_cmd_pattern/2 intercepts matching commands" do
    Mox.stub_cmd_pattern(~r/^docker compose ps/, {:ok, "myapp\n", 0})
    assert {:ok, "myapp\n", 0} = Runner.run("docker", ["compose", "ps"], [])
  end

  test "reset_stubs/0 clears all stubs" do
    Mox.stub_cmd("echo", ["x"], {:ok, "STUB\n", 0})
    assert {:ok, "STUB\n", 0} = Runner.run("echo", ["x"], [])
    Mox.reset_stubs()
    assert {:error, :no_stub_for_command} = Runner.run("echo", ["x"], [])
  end

  test "stub_cmd/3 for an error" do
    Mox.stub_cmd("false", [], {:error, :fake_error})
    assert {:error, :fake_error} = Runner.run("false", [], [])
  end
end
