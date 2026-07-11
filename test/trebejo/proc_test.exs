defmodule Trebejo.ProcTest do
  use ExUnit.Case, async: true

  alias Trebejo.Proc

  # Pure functions: now in Apero.Proc — test directly
  describe "command_exists?/1 (via Apero.Proc)" do
    test "returns true for commands that exist" do
      assert Apero.Proc.command_exists?("ls")
      assert Apero.Proc.command_exists?("echo")
    end

    test "returns false for commands that do not exist" do
      refute Apero.Proc.command_exists?("this_command_does_not_exist_xyz")
    end

    test "returns false for empty or non-binary input" do
      refute Apero.Proc.command_exists?("")
      refute Apero.Proc.command_exists?(nil)
      refute Apero.Proc.command_exists?(42)
    end
  end

  describe "which/1 (via Apero.Proc)" do
    test "returns path for existing command" do
      result = Apero.Proc.which("ls")
      assert is_binary(result)
      assert String.starts_with?(result, "/")
    end

    test "returns nil for missing command" do
      assert Apero.Proc.which("this_cmd_does_not_exist") == nil
    end
  end

  describe "available_commands/1 (via Apero.Proc)" do
    test "filters to only available commands" do
      result = Apero.Proc.available_commands(["ls", "nonexistent_xyz_cmd", "echo"])
      assert "ls" in result
      assert "echo" in result
      refute "nonexistent_xyz_cmd" in result
    end
  end

  describe "locate_commands/1 (via Apero.Proc)" do
    test "returns map with paths or nil" do
      result = Apero.Proc.locate_commands(["ls", "nonexistent_xyz"])
      assert is_map(result)
      assert is_binary(result["ls"])
      assert result["nonexistent_xyz"] == nil
    end
  end

  describe "os_pid/0 (via Apero.Proc)" do
    test "returns a positive integer" do
      pid = Apero.Proc.os_pid()
      assert is_integer(pid)
      assert pid > 0
    end
  end

  describe "scheduler_count/0 (via Apero.Proc)" do
    test "returns a positive integer" do
      count = Apero.Proc.scheduler_count()
      assert is_integer(count)
      assert count >= 1
    end
  end

  describe "vm_memory/0 (via Apero.Proc)" do
    test "returns a positive integer" do
      mem = Apero.Proc.vm_memory()
      assert is_integer(mem)
      assert mem > 0
    end
  end

  describe "vm_uptime/0 (via Apero.Proc)" do
    test "returns a non-negative integer" do
      uptime = Apero.Proc.vm_uptime()
      assert is_integer(uptime)
      assert uptime >= 0
    end
  end

  describe "kill/2" do
    @tag :external_cmd
    test "returns ok or error gracefully" do
      result = Proc.kill(:os.getpid(), 0)
      assert result == :ok or match?({:error, _}, result)
    end

    @tag :external_cmd
    test "returns error for non-existent pid" do
      assert {:error, _} = Proc.kill(999_999_999, 9)
    end
  end

  describe "lsof/1" do
    @tag :external_cmd
    test "returns ok or error for current pid" do
      result = Proc.lsof(:os.getpid())
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "fuser/1" do
    @tag :external_cmd
    test "returns ok or error for a known path" do
      result = Proc.fuser(System.tmp_dir!())
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "logs/2" do
    @tag :external_cmd
    test "returns ok or error" do
      result = Proc.logs("sshd", lines: 5)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "ps/1" do
    @tag :external_cmd
    test "returns process list" do
      result = Proc.ps([])
      assert match?({:ok, [_ | _]}, result) or match?({:error, _}, result)
    end
  end
end
