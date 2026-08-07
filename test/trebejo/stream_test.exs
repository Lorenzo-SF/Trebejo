defmodule Trebejo.StreamTest do
  use ExUnit.Case, async: false

  alias Trebejo.Stream

  @tag :tmp_dir
  test "open/3 returns chunks for a simple command" do
    {:ok, stream} = Stream.open("sh", ["-c", "echo alpha; echo beta; echo gamma"])
    chunks = Enum.to_list(stream)
    refute chunks == []
    assert Enum.any?(chunks, &String.contains?(&1, "alpha"))
    assert Enum.any?(chunks, &String.contains?(&1, "gamma"))
  end

  test "open/3 returns error tuple for missing command" do
    assert {:error, %Trebejo.Error{}} = Stream.open("nonexistent_xyzzy_42", [])
  end

  test "lines/3 yields complete lines" do
    {:ok, lines} = Stream.lines("sh", ["-c", "echo one; echo two; echo three"])
    collected = Enum.to_list(lines)
    assert "one" in collected
    assert "two" in collected
    assert "three" in collected
  end

  test "lines/3 propagates error for missing command" do
    assert {:error, %Trebejo.Error{}} = Stream.lines("nonexistent_xyzzy_42", [])
  end

  test "stderr: :separate falls back to :merge with a deprecation warning" do
    capture_log =
      ExUnit.CaptureLog.capture_log(fn ->
        {:ok, stream} =
          Stream.open(
            "sh",
            ["-c", "exec 2>&1; echo out1; echo err1 1>&2"],
            stderr: :separate
          )

        chunks = Enum.to_list(stream)
        assert Enum.any?(chunks, &String.contains?(&1, "err1"))
      end)

    assert capture_log =~ "stderr: :separate is deprecated"
  end
end
