defmodule Trebejo.RedisTest do
  use ExUnit.Case, async: false

  alias Trebejo.Mox
  alias Trebejo.Redis
  alias Trebejo.Runner

  setup do
    Mox.reset_stubs()
    previous = :persistent_term.get({Runner, :runner}, :unset)
    Runner.set_runner(Mox.Runner)
    on_exit(fn -> if previous == :unset, do: :ok, else: Runner.set_runner(previous) end)
    :ok
  end

  test "run/2 appends -h -p -n defaults" do
    Mox.stub_cmd(
      "redis-cli",
      ["-h", "127.0.0.1", "-p", "6379", "-n", "0", "PING"],
      {:ok, "PONG\n", 0}
    )

    assert {:ok, "PONG\n", 0} = Redis.run(["PING"])
  end

  test "run/2 forwards -a password" do
    Mox.stub_cmd(
      "redis-cli",
      ["-h", "127.0.0.1", "-p", "6379", "-n", "0", "-a", "secret", "INFO"],
      {:ok, "...", 0}
    )

    assert {:ok, "...", 0} = Redis.run(["INFO"], password: "secret")
  end

  test "run/2 returns typed error on non-zero exit" do
    Mox.stub_cmd(
      "redis-cli",
      ["-h", "127.0.0.1", "-p", "6379", "-n", "0", "BAD"],
      {:ok, "ERR unknown command\n", 1}
    )

    assert {:error, %Trebejo.Error{kind: :exit_nonzero}} = Redis.run(["BAD"])
  end

  test "ping?/1 returns true on PONG" do
    Mox.stub_cmd("redis-cli", ["-h", "127.0.0.1", "-p", "6379", "-n", "0", "PING"], {:ok, "PONG\n", 0})
    assert Redis.ping?()
  end

  test "ping?/1 returns false on error" do
    Mox.stub_cmd("redis-cli", ["-h", "127.0.0.1", "-p", "6379", "-n", "0", "PING"], {:error, :timeout})
    refute Redis.ping?()
  end
end
