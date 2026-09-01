defmodule Trebejo.ErrorTest do
  use ExUnit.Case, async: true

  alias Trebejo.Error

  describe "classify_exit/1" do
    test "127 → :not_found" do
      assert Error.classify_exit(127) == :not_found
    end

    test "126 → :permission_denied" do
      assert Error.classify_exit(126) == :permission_denied
    end

    test "2, 64, 65 → :invalid_args" do
      assert Error.classify_exit(2) == :invalid_args
      assert Error.classify_exit(64) == :invalid_args
      assert Error.classify_exit(65) == :invalid_args
    end

    test "130, 137, 143, 139 → :signal" do
      assert Error.classify_exit(130) == :signal
      assert Error.classify_exit(137) == :signal
      assert Error.classify_exit(143) == :signal
      assert Error.classify_exit(139) == :signal
    end

    test "anything else → :exit_nonzero" do
      assert Error.classify_exit(1) == :exit_nonzero
      assert Error.classify_exit(99) == :exit_nonzero
    end
  end

  describe "from_exit/3" do
    test "wraps exit code, stderr, cmd into struct" do
      err = Error.from_exit(127, "sh: missing: command not found", "missing")
      assert err.kind == :not_found
      assert err.exit_status == 127
      assert err.cmd == "missing"
      assert err.stderr == "sh: missing: command not found"
    end

    test "trim trailing whitespace in stderr" do
      err = Error.from_exit(1, "  boom  \n", "cmd")
      assert err.stderr == "boom"
    end

    test "nil/empty stderr becomes nil" do
      assert Error.from_exit(0, "", "x").stderr == nil
      assert Error.from_exit(0, nil, "x").stderr == nil
    end
  end

  describe "wrap/2" do
    test ":timeout becomes :timeout kind" do
      err = Error.wrap(:timeout, cmd: "sleep 5")
      assert err.kind == :timeout
      assert err.cmd == "sleep 5"
    end

    test "{:exit_status, code, err} passes through classifier" do
      err = Error.wrap({:exit_status, 127, "missing"}, cmd: "x")
      assert err.kind == :not_found
      assert err.exit_status == 127
      assert err.stderr == "missing"
    end

    test "{:blocked, :circuit_open} becomes :circuit_open" do
      err = Error.wrap({:blocked, :circuit_open}, cmd: "x")
      assert err.kind == :circuit_open
    end

    test "{:error, :rate_limited} becomes :rate_limited" do
      err = Error.wrap({:error, :rate_limited}, cmd: "x")
      assert err.kind == :rate_limited
    end

    test "{:error, :bulkhead_full} becomes :bulkhead_full" do
      err = Error.wrap({:error, :bulkhead_full}, cmd: "x")
      assert err.kind == :bulkhead_full
    end

    test "bare integer is classified" do
      err = Error.wrap(126, cmd: "x")
      assert err.kind == :permission_denied
    end
  end

  describe "message/1" do
    test "renders kind, exit, cmd and duration when present" do
      err =
        Error.from_exit(127, "missing", "x", duration_ms: 1234)

      msg = Error.message(err)
      assert msg =~ "not_found"
      assert msg =~ "exit=127"
      assert msg =~ "cmd=x"
      assert msg =~ "duration=1234ms"
    end
  end
end
