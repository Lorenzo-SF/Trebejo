defmodule Trebejo.Git.Local.Branches do
  @moduledoc """
  Git branch operations — checkout, current branch, stash, create, delete.
  """

  alias Trebejo.Git.Local

  @doc """
  Returns `true` if the given branch exists locally or remotely.
  """
  @spec branch_exists?(binary()) :: boolean()
  def branch_exists?(branch) do
    local =
      Local.run_git(["show-ref", "--verify", "--quiet", "refs/heads/#{branch}"])

    remote =
      Local.run_git(["ls-remote", "--exit-code", "--heads", "origin", branch])

    match?({:ok, %{exit_code: 0}}, local) or match?({:ok, %{exit_code: 0}}, remote)
  end

  @doc """
  Checks out the `main_branch` of a repository, stashing uncommitted
  changes first if necessary.
  """
  @spec checkout(map()) :: {:ok, map()} | {:error, any()}
  def checkout(%{path: path, main_branch: target_branch} = repo)
      when not is_nil(path) and not is_nil(target_branch) do
    if Local.has_uncommitted_changes?(path) do
      Local.run_git(
        ["stash", "push", "-u", "-m", "apero auto-stash before checkout"],
        cd: path
      )
    end

    case Local.run_git(["checkout", target_branch], cd: path) do
      {:ok, %{exit_code: 0}} -> {:ok, repo}
      {:ok, %{stdout: output}} -> {:error, {output, repo}}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Returns the currently checked-out branch name.
  """
  @spec get_current_branch(binary()) :: {:ok, binary()} | {:error, binary()}
  def get_current_branch(repo_path) do
    case Local.run_git(["rev-parse", "--abbrev-ref", "HEAD"], cd: repo_path) do
      {:ok, %{exit_code: 0, stdout: output}} -> {:ok, String.trim(output)}
      {:ok, %{stdout: output}} -> {:error, String.trim(output)}
      {:error, reason} -> {:error, inspect(reason)}
    end
  end

  @doc """
  Pushes stash entries in a repository.

  ## Options

    * `:message` — stash description (default: `"auto-stash"`)
    * `:include_untracked` — include untracked files (default: `true`)

  """
  @spec stash_push(binary(), keyword()) :: {:ok, binary()} | {:error, binary()}
  def stash_push(repo_path, opts \\ []) do
    message = Keyword.get(opts, :message, "auto-stash")
    include_untracked = Keyword.get(opts, :include_untracked, true)

    git_args =
      if include_untracked,
        do: ["stash", "push", "-u", "-m", message],
        else: ["stash", "push", "-m", message]

    case Local.run_git(git_args, cd: repo_path) do
      {:ok, %{exit_code: 0, stdout: output}} -> {:ok, String.trim(output)}
      {:ok, %{stdout: output}} -> {:error, String.trim(output)}
      {:error, reason} -> {:error, inspect(reason)}
    end
  end

  @doc """
  Returns `true` if the repository has stash entries.
  """
  @spec has_stash?(binary()) :: boolean()
  def has_stash?(repo_path) do
    case Local.run_git(["stash", "list"], cd: repo_path) do
      {:ok, %{exit_code: 0, stdout: output}} -> String.trim(output) != ""
      _ -> false
    end
  end

  @doc """
  Stashes uncommitted changes if the working tree is dirty.

  Returns `{:ok, {:stashed, branch}}`, `{:ok, :clean}`, or `{:error, reason}`.
  """
  @spec stash_if_needed(binary()) ::
          {:ok, {:stashed, binary()} | :clean} | {:error, any()}
  def stash_if_needed(repo_path) do
    with {:ok, branch} <- Local.get_current_branch(repo_path) do
      if Local.has_uncommitted_changes?(repo_path) do
        do_stash(repo_path, branch)
      else
        {:ok, :clean}
      end
    end
  end

  @doc """
  Restores stashed changes.
  """
  @spec stash_pop(binary()) :: {:ok, binary()} | {:error, binary()}
  def stash_pop(repo_path) do
    case Local.run_git(["stash", "pop"], cd: repo_path) do
      {:ok, %{exit_code: 0, stdout: output}} -> {:ok, String.trim(output)}
      {:ok, %{stdout: output}} -> {:error, String.trim(output)}
      {:error, reason} -> {:error, inspect(reason)}
    end
  end

  @doc """
  Returns the list of all local branches.
  """
  @spec list_local_branches(binary()) :: {:ok, [binary()]} | {:error, any()}
  def list_local_branches(repo_path) do
    case Local.run_git(["branch", "--list"], cd: repo_path) do
      {:ok, %{exit_code: 0, stdout: output}} ->
        branches = String.split(output, "\n", trim: true)
        {:ok, Enum.map(branches, &String.trim/1)}

      error ->
        error
    end
  end

  @doc """
  Creates a new branch.
  """
  @spec create_branch(binary(), binary()) :: {:ok, binary()} | {:error, any()}
  def create_branch(repo_path, branch_name) do
    case Local.run_git(["checkout", "-b", branch_name], cd: repo_path) do
      {:ok, %{exit_code: 0, stdout: output}} -> {:ok, String.trim(output)}
      {:ok, %{stdout: output}} -> {:error, String.trim(output)}
      {:error, reason} -> {:error, inspect(reason)}
    end
  end

  @doc """
  Deletes a branch.
  """
  @spec delete_branch(binary(), binary()) :: {:ok, binary()} | {:error, any()}
  def delete_branch(repo_path, branch_name) do
    case Local.run_git(["branch", "-D", branch_name], cd: repo_path) do
      {:ok, %{exit_code: 0, stdout: output}} -> {:ok, String.trim(output)}
      {:ok, %{stdout: output}} -> {:error, String.trim(output)}
      {:error, reason} -> {:error, inspect(reason)}
    end
  end

  defp do_stash(repo_path, branch) do
    case stash_push(repo_path, message: "sync-stash from #{branch}") do
      {:ok, _} -> {:ok, {:stashed, branch}}
      {:error, reason} -> {:error, reason}
    end
  end
end
