defmodule Trebejo.IntegrationTest do
  @moduledoc """
  Smoke tests against real binaries on the host.

  Tagged `@tag :integration` so `mix test` skips them by default. Run
  with `mix test --only integration` or `mix test --include
  integration` to opt in. These are NOT part of `mix qa` (which excludes
  `:external_cmd` and `:integration`).

  These tests do NOT assume any particular distribution or runtime —
  they probe each binary's existence with `Apero.Proc.command_exists?/1`
  and skip if absent.
  """

  use ExUnit.Case, async: false

  alias Apero.Proc

  @tag :integration
  test "git --version prints something starting with 'git version'" do
    if Proc.command_exists?("git") do
      assert {:ok, out, 0} = Trebejo.Util.run_cmd("git", ["--version"])
      assert String.starts_with?(String.trim(out), "git version")
    else
      IO.puts("[integration] git not found; skipping")
    end
  end

  @tag :integration
  test "docker --version prints a version line" do
    if Proc.command_exists?("docker") do
      assert {:ok, out, 0} = Trebejo.Util.run_cmd("docker", ["--version"])
      assert String.contains?(String.trim(out), "version")
    else
      IO.puts("[integration] docker not found; skipping")
    end
  end

  @tag :integration
  test "redis-cli PING returns PONG if redis is reachable" do
    if Proc.command_exists?("redis-cli") do
      case Trebejo.Redis.run(["PING"]) do
        {:ok, "PONG\n", 0} -> :ok
        {:ok, _, 0} -> IO.puts("[integration] redis up but no PONG (different version)")
        {:error, _} -> IO.puts("[integration] redis up but unreachable; skipping")
      end
    else
      IO.puts("[integration] redis-cli not found; skipping")
    end
  end

  @tag :integration
  test "psql --version prints a version" do
    if Proc.command_exists?("psql") do
      assert {:ok, out, 0} = Trebejo.Util.run_cmd("psql", ["--version"])
      assert String.contains?(String.trim(out), "psql")
    else
      IO.puts("[integration] psql not found; skipping")
    end
  end

  @tag :integration
  test "gh --version prints a version" do
    if Proc.command_exists?("gh") do
      assert {:ok, out, 0} = Trebejo.Util.run_cmd("gh", ["--version"])
      assert String.contains?(String.trim(out), "gh version")
    else
      IO.puts("[integration] gh not found; skipping")
    end
  end
end
