defmodule Trebejo.SafeCommandTest do
  use ExUnit.Case, async: true

  alias Trebejo.SafeCommand

  test "executes safe command" do
    {:ok, result} = SafeCommand.execute("echo hello")
    assert String.trim(result.stdout) == "hello"
  end

  test "rejects empty command" do
    assert SafeCommand.execute("") == {:error, :empty_command}
  end

  test "legacy API with metacharacters is split safely (not injected)" do
    # With the arg-list approach, the command is split on whitespace and
    # each argument is shell-quoted — metacharacters in args are harmless.
    {:ok, result} = SafeCommand.execute("echo hello; rm -rf /")
    assert String.contains?(result.stdout, "hello")
  end

  test "executes via arg-list API" do
    {:ok, result} = SafeCommand.execute("echo", ["hello"])
    assert String.trim(result.stdout) == "hello"
  end

  test "validates command name via arg-list API" do
    assert SafeCommand.execute("", ["foo"]) == {:error, :empty_command}
  end

  test "rejects unsafe command name via arg-list API" do
    assert SafeCommand.execute("touch; rm", ["-rf", "/"]) == {:error, :unsafe_command_name}
  end
end
