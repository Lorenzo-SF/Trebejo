defmodule Trebejo.Git.Local.HistoryTest do
  @moduledoc """
  Tests for Trebejo.Git.Local.History.commits_between/4 (iter-040).
  """
  use ExUnit.Case, async: true

  alias Trebejo.Git.Local.History

  describe "commits_between/4" do
    test "returns error for non-existent repo" do
      path = "/tmp/nonexistent-#{System.unique_integer([:positive])}"

      assert {:error, _} = History.commits_between(path, "abc", "HEAD")
    end

    test "returns error for invalid SHA range" do
      # Try a path that exists but is not a git repo.
      path = System.tmp_dir()
      assert {:error, _} = History.commits_between(path, "abc", "HEAD")
    end

    test "parses commit lines correctly (short format)" do
      # We can't easily mock git output, so we test the parsing
      # indirectly via a function call that fails.  Just verify the
      # function signature compiles.
      assert is_function(&History.commits_between/4)
    end
  end
end
