defmodule Trebejo.UtilTest do
  use ExUnit.Case, async: true

  alias Trebejo.Util

  describe "shell_quote/1" do
    test "quotes a plain string" do
      assert Util.shell_quote("hello") == "'hello'"
    end

    test "escapes internal single quotes" do
      # shell_quote("O'Brien") returns 'O'\''Brien'
      assert Util.shell_quote("O'Brien") == ~s|'O'\\''Brien'|
    end

    test "quotes an empty string" do
      assert Util.shell_quote("") == "''"
    end

    test "escapes newlines" do
      result = Util.shell_quote("a\nb")
      assert String.starts_with?(result, "'")
      assert String.ends_with?(result, "'")
      assert String.contains?(result, "\n")
    end

    test "escapes backslashes" do
      result = Util.shell_quote("a\\b")
      assert String.starts_with?(result, "'")
      assert String.ends_with?(result, "'")
    end

    test "preserves $HOME as literal (no variable expansion)" do
      assert Util.shell_quote("$HOME") == "'$HOME'"
    end

    test "preserves backticks as literal (no command expansion)" do
      assert Util.shell_quote("`command`") == "'`command`'"
    end

    test "quotes strings with spaces" do
      assert Util.shell_quote("hello world") == "'hello world'"
    end

    test "quotes strings with special characters" do
      assert Util.shell_quote("file$name.txt") == "'file$name.txt'"
    end
  end

  describe "run_cmd/3" do
    test "returns {:ok, stdout, 0} on success" do
      assert {:ok, _, 0} = Util.run_cmd("echo", ["hello"])
    end

    test "returns non-zero exit for non-existent command" do
      assert {:ok, _out, exit_code} = Util.run_cmd("nonexistent_cmd_xyzzy", [])
      assert exit_code != 0
    end

    test "preserves argument quoting" do
      assert {:ok, out, 0} = Util.run_cmd("echo", ["hello world"])
      assert String.trim(out) == "hello world"
    end
  end

  describe "run_cmd_legacy/3" do
    test "returns {output, 0} on success" do
      assert {out, 0} = Util.run_cmd_legacy("echo", ["hi"])
      assert String.trim(out) == "hi"
    end

    test "returns non-zero exit on missing command" do
      {_out, exit_code} = Util.run_cmd_legacy("nonexistent_cmd_xyzzy", [])
      assert exit_code != 0
    end
  end

  describe "run_ok/3" do
    test "returns :ok on zero exit" do
      assert :ok = Util.run_ok("echo", ["ok"])
    end

    test "returns {:error, _} on non-zero exit" do
      assert {:error, _} = Util.run_ok("sh", ["-c", "exit 1"])
    end
  end
end
