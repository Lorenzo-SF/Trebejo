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

  test "rejects unsafe command with metacharacters" do
    assert SafeCommand.execute("touch /tmp; rm -rf /") == {:error, :unsafe_command}
    assert SafeCommand.execute("echo `whoami`") == {:error, :unsafe_command}
  end
end
