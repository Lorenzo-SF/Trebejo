defmodule Trebejo.PostgresTest do
  use ExUnit.Case, async: false

  alias Trebejo.Mox
  alias Trebejo.Postgres
  alias Trebejo.Runner

  setup do
    Mox.reset_stubs()
    previous = :persistent_term.get({Runner, :runner}, :unset)
    Runner.set_runner(Mox.Runner)
    on_exit(fn -> if previous == :unset, do: :ok, else: Runner.set_runner(previous) end)
    :ok
  end

  test "execute/2 builds a psql -c command" do
    Mox.stub_cmd_pattern(~r/^psql -c SELECT 1/, {:ok, "1\n", 0})
    assert {:ok, "1\n", 0} = Postgres.execute("SELECT 1", host: "db.local")
  end

  test "execute/2 returns typed error for non-zero exit" do
    Mox.stub_cmd_pattern(~r/^psql -c bad/, {:ok, "syntax error\n", 2})
    assert {:error, %Trebejo.Error{kind: :invalid_args}} = Postgres.execute("bad", [])
  end

  test "execute/2 wraps a runner error" do
    Mox.stub_cmd_pattern(~r/^psql/, {:error, :timeout})
    assert {:error, %Trebejo.Error{kind: :timeout}} = Postgres.execute("x", [])
  end

  test "dump/1 writes a plain SQL script by default" do
    Mox.stub_cmd_pattern(~r/^pg_dump.*--format=plain.*-f \/tmp\/app\.sql/, {:ok, "", 0})

    assert :ok = Postgres.dump("app", file: "/tmp/app.sql", host: "h")
  end

  test "restore/1 uses -f for plain format" do
    Mox.stub_cmd_pattern(~r/^pg_restore.*--format=plain.*-f app\.dump/, {:ok, "", 0})

    assert :ok = Postgres.restore("app", file: "app.dump", format: :plain, host: "h")
  end
end
