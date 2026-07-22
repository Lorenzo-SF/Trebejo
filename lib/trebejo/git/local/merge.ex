defmodule Trebejo.Git.Local.Merge do
  @moduledoc """
  Git merge conflict operations — conflict detection, merge abort, marking
  files as resolved, and related merge/revert/squash operations.
  """

  alias Trebejo.Git.Local

  @doc """
  Lists files with merge conflicts in the repo.
  """
  @spec conflict_files(binary()) :: {:ok, [binary()]} | {:error, binary()}
  def conflict_files(repo_path \\ ".") do
    case Local.run_git(["diff", "--name-only", "--diff-filter=U"], cd: repo_path) do
      {:ok, %{exit_code: 0, stdout: out}} ->
        {:ok,
         out
         |> String.split("\n")
         |> Enum.map(&String.trim/1)
         |> Enum.reject(&(&1 == ""))}

      {:ok, %{stdout: err}} ->
        {:error, String.trim(err)}

      {:error, reason} ->
        {:error, inspect(reason)}
    end
  end

  @doc """
  Aborts a merge in progress.
  """
  @spec merge_abort(binary()) :: {:ok, binary()} | {:error, binary()}
  def merge_abort(repo_path \\ ".") do
    case Local.run_git(["merge", "--abort"], cd: repo_path) do
      {:ok, %{exit_code: 0, stdout: out}} -> {:ok, String.trim(out)}
      {:ok, %{stdout: err}} -> {:error, String.trim(err)}
      {:error, reason} -> {:error, inspect(reason)}
    end
  end

  @doc """
  Marks a conflicted file as resolved (after manual fix).
  """
  @spec mark_resolved(binary(), binary()) :: :ok | {:error, binary()}
  def mark_resolved(repo_path, file) do
    case Local.run_git(["add", file], cd: repo_path) do
      {:ok, %{exit_code: 0}} -> :ok
      {:ok, %{stdout: err}} -> {:error, String.trim(err)}
      {:error, reason} -> {:error, inspect(reason)}
    end
  end

  @doc """
  Merges a branch into the current branch.
  """
  @spec merge(binary(), binary()) :: {:ok, binary()} | {:error, any()}
  def merge(repo_path, branch) do
    Local.run_git(["merge", branch], cd: repo_path)
  end

  @doc """
  Reverts a commit.
  """
  @spec revert(binary(), binary()) :: {:ok, binary()} | {:error, any()}
  def revert(repo_path, commit_hash) do
    Local.run_git(["revert", commit_hash], cd: repo_path)
  end

  @doc """
  Squashes commits into one.
  """
  @spec squash(binary(), binary()) :: {:ok, binary()} | {:error, any()}
  def squash(repo_path, commit_hash) do
    Local.run_git(["reset", "--soft", commit_hash], cd: repo_path)
  end

  @doc """
  Cherry-picks a commit.
  """
  @spec cherry_pick(binary(), binary()) :: {:ok, binary()} | {:error, any()}
  def cherry_pick(repo_path, commit_hash) do
    Local.run_git(["cherry-pick", commit_hash], cd: repo_path)
  end

  @doc """
  Stages all changes.
  """
  @spec stage_all(binary()) :: {:ok, binary()} | {:error, any()}
  def stage_all(repo_path) do
    Local.run_git(["add", "."], cd: repo_path)
  end

  @doc """
  Commits all staged changes.
  """
  @spec commit_all(binary(), binary()) :: {:ok, binary()} | {:error, any()}
  def commit_all(repo_path, message) do
    Local.run_git(["commit", "-m", message], cd: repo_path)
  end

  @doc """
  Rebase a branch onto another.
  """
  @spec rebase(binary(), binary()) :: {:ok, binary()} | {:error, any()}
  def rebase(repo_path, branch) do
    Local.run_git(["rebase", branch], cd: repo_path)
  end

  @doc """
  Merges a commit into the current branch.
  """
  @spec merge_commit(binary(), binary()) :: {:ok, binary()} | {:error, any()}
  def merge_commit(repo_path, commit_hash) do
    Local.run_git(["merge", commit_hash], cd: repo_path)
  end
end
