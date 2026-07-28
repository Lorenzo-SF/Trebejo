defmodule Trebejo.Git.Local do
  @moduledoc """
  Local Git operations — clone, commit, pull, push, branch, stash, merge, etc.

  All user-supplied values (commit messages, branch names, file paths)
  are passed as argument lists — never interpolated into shell strings —
  to prevent shell injection attacks. Arguments are shell-quoted
  before being joined into the final command line, so values
  containing whitespace, quotes or shell metacharacters are safe.
  """

  alias Trebejo.Git.Local.Clone
  alias Trebejo.Git.Local.Sync
  alias Trebejo.Git.Local.Branches
  alias Trebejo.Git.Local.Config
  alias Trebejo.Git.Local.History
  alias Trebejo.Git.Local.Merge
  alias Trebejo.Git.Local.Utils

  @doc """
  Updates an existing repository by fetching from origin.
  """
  @spec update_existing_repository(binary()) :: {:ok, binary()} | {:error, any()}
  def update_existing_repository(repo_path) do
    Clone.update_existing_repository(repo_path)
  end

  @doc """
  Returns `true` if the given branch exists locally or remotely.
  """
  @spec branch_exists?(binary()) :: boolean()
  def branch_exists?(branch) do
    Branches.branch_exists?(branch)
  end

  @doc """
  Ensures a repository is cloned. If it already exists, updates it.

  Accepts a single repo map, a list of repo maps, or `nil`.
  """
  @spec ensure_clone(nil) :: {:error, :no_repo_defined}
  @spec ensure_clone([map()], binary()) :: [
          {:repo_exists | :repo_cloned, map()} | {:repo_error, map(), term()}
        ]
  @spec ensure_clone(map(), binary()) ::
          {:repo_exists | :repo_cloned, map()} | {:repo_error, map(), term()}
  def ensure_clone(nil), do: {:error, :no_repo_defined}

  def ensure_clone(repos, workspace_path) when is_list(repos) do
    Clone.ensure_clone(repos, workspace_path)
  end

  def ensure_clone(repo, workspace_path) do
    Clone.ensure_clone(repo, workspace_path)
  end

  @doc """
  Returns a tree string of existing (already-cloned) repositories from a list
  of `{:repo_exists | :repo_error, map(), ...}` tuples.
  """
  @spec existing_repos([tuple()]) :: binary()
  def existing_repos(repos) do
    Clone.existing_repos(repos)
  end

  @doc """
  Clones a repository from `url` to `path`.
  """
  @spec clone(map()) :: {:ok, map()} | {:error, any()}
  def clone(repo) do
    Clone.clone(repo)
  end

  @doc """
  Clones a repository from a URL to a target path.
  """
  @spec clone_repository(binary(), binary()) :: {:ok, binary()} | {:error, any()}
  def clone_repository(url, target_path) do
    Clone.clone_repository(url, target_path)
  end

  @doc """
  Fetches repository updates from origin.
  """
  @spec fetch_repository_updates(binary()) :: {:ok, binary()} | {:error, any()}
  def fetch_repository_updates(repo_path) do
    Clone.fetch_repository_updates(repo_path)
  end

  @doc """
  Fetches all repository changes from origin.
  """
  @spec fetch_all_changes(binary()) :: {:ok, binary()} | {:error, any()}
  def fetch_all_changes(repo_path) do
    Clone.fetch_all_changes(repo_path)
  end

  @doc """
  Synchronises a list of repositories (checkout → fetch → pull).
  """
  @spec sync([map()]) :: :ok
  def sync(repos) when is_list(repos) do
    Sync.sync(repos)
  end

  @spec sync(map()) :: {:ok, map()} | {:error, any()}
  def sync(repo) do
    Sync.sync(repo)
  end

  @doc """
  Stages files in a repository.

  Pass `:all` to stage everything, a list of paths, or a single path binary.
  """
  @spec add(binary(), :all | [binary()] | binary()) :: :ok | {:ok, binary()} | {:error, any()}
  def add(repo_path, :all) do
    case Utils.run_git(["add", "."], cd: repo_path) do
      {:ok, %{exit_code: 0}} -> :ok
      _ -> {:error, :add_failed}
    end
  end

  def add(repo_path, files) when is_list(files) do
    Enum.each(files, fn file -> add(repo_path, file) end)
    :ok
  end

  def add(repo_path, file) when is_binary(file) do
    case Utils.run_git(["add", "--", file], cd: repo_path) do
      {:ok, %{exit_code: 0, stdout: output}} -> {:ok, String.trim(output)}
      {:ok, %{stdout: output}} -> {:error, String.trim(output)}
      {:error, reason} -> {:error, inspect(reason)}
    end
  end

  @doc """
  Checks out the `main_branch` of a repository, stashing uncommitted
  changes first if necessary.
  """
  @spec checkout(map()) :: {:ok, map()} | {:error, any()}
  def checkout(repo) do
    Branches.checkout(repo)
  end

  @doc """
  Creates a commit with the given message in a repository.
  """
  @spec commit(map(), binary()) :: {:ok, map()} | {:error, any()}
  def commit(%{path: path} = repo, message) do
    case Utils.run_git(["commit", "-m", message], cd: path) do
      {:ok, %{exit_code: 0}} -> {:ok, repo}
      {:ok, %{stdout: output}} -> {:error, {output, repo}}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Gets a Git configuration value (local → global → system).

  Accepts an optional `cd:` option to scope the lookup to a specific
  repository directory.
  """
  @spec config(binary(), keyword()) :: binary()
  def config(attr, opts \\ []) do
    Config.config(attr, opts)
  end

  @doc """
  Gets a Git configuration value from the global scope.

  Accepts an optional `cd:` option (kept for signature parity with
  `config/2`; ignored at the global scope).
  """
  @spec config_global(binary(), keyword()) :: binary()
  def config_global(attr, _opts \\ []) do
    Config.config_global(attr)
  end

  @doc """
  Gets a Git configuration value from the local (repo) scope.

  Accepts an optional `cd:` option to scope the lookup to a specific
  repository directory.
  """
  @spec config_local(binary(), keyword()) :: binary()
  def config_local(attr, opts \\ []) do
    Config.config_local(attr, opts)
  end

  @doc """
  Fetches all remotes in a repository.
  """
  @spec fetch(map()) :: {:ok, map()} | {:error, any()}
  def fetch(%{path: path} = repo) do
    case Utils.run_git(["fetch", "--all"], cd: path) do
      {:ok, %{exit_code: 0}} -> {:ok, repo}
      {:ok, %{stdout: output}} -> {:error, {output, repo}}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Pulls from origin using the repository's `main_branch`.
  """
  @spec pull(map()) :: {:ok, map()} | {:error, any()}
  def pull(%{path: path, main_branch: branch} = repo) do
    case Utils.run_git(["pull", "origin", branch], cd: path) do
      {:ok, %{exit_code: 0}} -> {:ok, repo}
      {:ok, %{stdout: output}} -> {:error, {output, repo}}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Fetches from `origin` in the given repository path.
  """
  @spec fetch_origin(binary()) :: {:ok, binary()} | {:error, binary()}
  def fetch_origin(repo_path) do
    case Utils.run_git(["fetch", "origin"], cd: repo_path) do
      {:ok, %{exit_code: 0, stdout: output}} -> {:ok, String.trim(output)}
      {:ok, %{stdout: output}} -> {:error, String.trim(output)}
      {:error, reason} -> {:error, inspect(reason)}
    end
  end

  @doc """
  Pulls from `origin` for the given branch (default: `"main"`).
  """
  @spec pull_origin(binary(), binary()) :: {:ok, binary()} | {:error, binary()}
  def pull_origin(repo_path, branch \\ "main") do
    case Utils.run_git(["pull", "origin", branch], cd: repo_path) do
      {:ok, %{exit_code: 0, stdout: output}} -> {:ok, String.trim(output)}
      {:ok, %{stdout: output}} -> {:error, String.trim(output)}
      {:error, reason} -> {:error, inspect(reason)}
    end
  end

  @doc """
  Returns the configured Git user name, or `nil` if not set.
  """
  @spec get_git_user_name() :: binary() | nil
  def get_git_user_name do
    Config.get_git_user_name()
  end

  @doc """
  Returns the configured Git user email, or `nil` if not set.
  """
  @spec get_git_user_email() :: binary() | nil
  def get_git_user_email do
    Config.get_git_user_email()
  end

  @doc """
  Returns the current system user name.
  """
  @spec get_system_user_name() :: binary()
  def get_system_user_name do
    Config.get_system_user_name()
  end

  @doc """
  Returns the current system user email from the `USER_EMAIL` env variable,
  falling back to `"user@domain.com"`.
  """
  @spec get_system_user_email() :: binary()
  def get_system_user_email do
    Config.get_system_user_email()
  end

  @doc """
  Returns the machine's hostname.
  """
  @spec get_hostname() :: binary()
  def get_hostname do
    Config.get_hostname()
  end

  @doc """
  Returns a map with the current Git user information.

  Falls back to system user information if Git is not configured.
  """
  @spec get_user_info() :: map()
  def get_user_info do
    Config.get_user_info()
  end

  @doc """
  Sets Git user name, email, and URL rewrite rules globally.
  """
  @spec set_user_info(binary(), binary()) :: :ok | {:error, binary()}
  def set_user_info(name, email) do
    Config.set_user_info(name, email)
  end

  @doc """
  Stages all changes and creates a commit with the given message.
  """
  @spec stage_and_commit(map(), binary()) :: {:ok, map()} | {:error, any()}
  def stage_and_commit(%{path: path} = repo, message) when is_binary(message) do
    with :ok <- add(path, :all),
         {:ok, repo} <- commit(repo, message) do
      {:ok, repo}
    else
      {:error, reason} -> {:error, reason}
      _ -> {:error, :unknown}
    end
  end

  @doc """
  Shows commit history (log).
  """
  @spec log(binary(), keyword()) :: {:ok, binary()} | {:error, binary()}
  def log(repo_path \\ ".", opts \\ []) do
    History.log(repo_path, opts)
  end

  @doc """
  Shows who last modified each line of a file (blame).
  """
  @spec blame(binary(), binary()) :: {:ok, binary()} | {:error, binary()}
  def blame(repo_path, file) do
    History.blame(repo_path, file)
  end

  @doc """
  Shows diff of changes.
  """
  @spec diff(binary(), keyword()) :: {:ok, binary()} | {:error, binary()}
  def diff(repo_path \\ ".", opts \\ []) do
    History.diff(repo_path, opts)
  end

  @doc """
  Returns churn metrics — the most frequently changed files.

  Runs `git log --name-only` for the given period or max commits and counts
  how many times each file has been modified. Results are sorted by churn
  count descending.

  When `include_authors: true`, uses `--format=COMMIT:%an` to track which
  authors touched each file, so callers can compute risk scores like
  `churn * (1 + log(num_authors))`.

  ## Options
    - `:period` — Time period for git log (default: `"6.months"`).
      Ignored if `:max_commits` is set.
    - `:max_commits` — Limit to the last N commits (uses `--max-count`).
      Overrides `:period`.
    - `:no_merges` — Exclude merge commits via `--no-merges` (default: `false`)
    - `:top` — Return only the top N files (default: 20)
    - `:branch` — Git branch to analyze (default: current branch)
    - `:include_authors` — Track distinct authors per file (default: `false`).
      When `true`, each result includes `:authors` (list of author names).
    - `:timeout` — Command timeout in milliseconds (default: `nil`,
      meaning Arrea's default). Passed to `Arrea.Command.execute/2`.

  ## Examples

      iex> Trebejo.Git.Local.churn(".")
      {:ok, [%{file: "lib/foo.ex", churn: 15}, ...]}

      iex> Trebejo.Git.Local.churn(".", max_commits: 1000, no_merges: true, include_authors: true)
      {:ok, [%{file: "lib/foo.ex", churn: 15, authors: ["Alice", "Bob"]}, ...]}

  """
  @spec churn(binary(), keyword()) :: {:ok, [map()]} | {:error, binary()}
  def churn(repo_path \\ ".", opts \\ []) do
    History.churn(repo_path, opts)
  end

  @doc """
  Gets the short (7-char) commit hash for `HEAD`.
  """
  @spec get_short_commit(binary()) :: {:ok, binary()} | {:error, binary()}
  def get_short_commit(repo_path) do
    History.get_short_commit(repo_path)
  end

  @doc """
  Gets the current commit hash for a repository.
  """
  @spec get_current_commit(binary()) :: {:ok, binary()} | {:error, any()}
  def get_current_commit(repo_path) do
    History.get_current_commit(repo_path)
  end

  @doc """
  Gets the commit count for a repository.
  """
  @spec get_commit_count(binary()) :: {:ok, integer()} | {:error, any()}
  def get_commit_count(repo_path) do
    History.get_commit_count(repo_path)
  end

  @doc """
  Gets the first commit hash for a repository.
  """
  @spec get_first_commit(binary()) :: {:ok, binary()} | {:error, any()}
  def get_first_commit(repo_path) do
    History.get_first_commit(repo_path)
  end

  @doc """
  Lists files with merge conflicts in the repo.
  """
  @spec conflict_files(binary()) :: {:ok, [binary()]} | {:error, binary()}
  def conflict_files(repo_path \\ ".") do
    Merge.conflict_files(repo_path)
  end

  @doc """
  Aborts a merge in progress.
  """
  @spec merge_abort(binary()) :: {:ok, binary()} | {:error, binary()}
  def merge_abort(repo_path \\ ".") do
    Merge.merge_abort(repo_path)
  end

  @doc """
  Marks a conflicted file as resolved (after manual fix).
  """
  @spec mark_resolved(binary(), binary()) :: :ok | {:error, binary()}
  def mark_resolved(repo_path, file) do
    Merge.mark_resolved(repo_path, file)
  end

  @doc """
  Merges a branch into the current branch.
  """
  @spec merge(binary(), binary()) :: {:ok, binary()} | {:error, any()}
  def merge(repo_path, branch) do
    Merge.merge(repo_path, branch)
  end

  @doc """
  Reverts a commit.
  """
  @spec revert(binary(), binary()) :: {:ok, binary()} | {:error, any()}
  def revert(repo_path, commit_hash) do
    Merge.revert(repo_path, commit_hash)
  end

  @doc """
  Squashes commits into one.
  """
  @spec squash(binary(), binary()) :: {:ok, binary()} | {:error, any()}
  def squash(repo_path, commit_hash) do
    Merge.squash(repo_path, commit_hash)
  end

  @doc """
  Cherry-picks a commit.
  """
  @spec cherry_pick(binary(), binary()) :: {:ok, binary()} | {:error, any()}
  def cherry_pick(repo_path, commit_hash) do
    Merge.cherry_pick(repo_path, commit_hash)
  end

  @doc """
  Stages all changes.
  """
  @spec stage_all(binary()) :: {:ok, binary()} | {:error, any()}
  def stage_all(repo_path) do
    Merge.stage_all(repo_path)
  end

  @doc """
  Commits all staged changes.
  """
  @spec commit_all(binary(), binary()) :: {:ok, binary()} | {:error, any()}
  def commit_all(repo_path, message) do
    Merge.commit_all(repo_path, message)
  end

  @doc """
  Rebase a branch onto another.
  """
  @spec rebase(binary(), binary()) :: {:ok, binary()} | {:error, any()}
  def rebase(repo_path, branch) do
    Merge.rebase(repo_path, branch)
  end

  @doc """
  Merges a commit into the current branch.
  """
  @spec merge_commit(binary(), binary()) :: {:ok, binary()} | {:error, any()}
  def merge_commit(repo_path, commit_hash) do
    Merge.merge_commit(repo_path, commit_hash)
  end

  @doc """
  Pushes stash entries in a repository.

  ## Options

    * `:message` — stash description (default: `"auto-stash"`)
    * `:include_untracked` — include untracked files (default: `true`)

  """
  @spec stash_push(binary(), keyword()) :: {:ok, binary()} | {:error, binary()}
  def stash_push(repo_path, opts \\ []) do
    Branches.stash_push(repo_path, opts)
  end

  @doc """
  Returns `true` if the repository has stash entries.
  """
  @spec has_stash?(binary()) :: boolean()
  def has_stash?(repo_path) do
    Branches.has_stash?(repo_path)
  end

  @doc """
  Stashes uncommitted changes if the working tree is dirty.

  Returns `{:ok, {:stashed, branch}}`, `{:ok, :clean}`, or `{:error, reason}`.
  """
  @spec stash_if_needed(binary()) ::
          {:ok, {:stashed, binary()} | :clean} | {:error, any()}
  def stash_if_needed(repo_path) do
    Branches.stash_if_needed(repo_path)
  end

  @doc """
  Restores stashed changes.
  """
  @spec stash_pop(binary()) :: {:ok, binary()} | {:error, binary()}
  def stash_pop(repo_path) do
    Branches.stash_pop(repo_path)
  end

  @doc """
  Returns the currently checked-out branch name.
  """
  @spec get_current_branch(binary()) :: {:ok, binary()} | {:error, binary()}
  def get_current_branch(repo_path) do
    Branches.get_current_branch(repo_path)
  end

  @doc """
  Returns the list of all local branches.
  """
  @spec list_local_branches(binary()) :: {:ok, [binary()]} | {:error, any()}
  def list_local_branches(repo_path) do
    Branches.list_local_branches(repo_path)
  end

  @doc """
  Creates a new branch.
  """
  @spec create_branch(binary(), binary()) :: {:ok, binary()} | {:error, any()}
  def create_branch(repo_path, branch_name) do
    Branches.create_branch(repo_path, branch_name)
  end

  @doc """
  Deletes a branch.
  """
  @spec delete_branch(binary(), binary()) :: {:ok, binary()} | {:error, any()}
  def delete_branch(repo_path, branch_name) do
    Branches.delete_branch(repo_path, branch_name)
  end

  @doc """
  Returns `true` if there are uncommitted changes in the repository.
  """
  @spec has_uncommitted_changes?(binary()) :: boolean()
  def has_uncommitted_changes?(repo_path) do
    Utils.has_uncommitted_changes?(repo_path)
  end

  @doc """
  Checks if `gh` is available.
  """
  @spec gh_available?() :: boolean()
  def gh_available? do
    Utils.gh_available?()
  end

  @doc """
  Checks if `glab` is available.
  """
  @spec glab_available?() :: boolean()
  def glab_available? do
    Utils.glab_available?()
  end

  @doc """
  Configures Git credentials (SSH key path or credential helper).
  """
  @spec setup_credentials(keyword()) :: :ok | {:error, binary()}
  def setup_credentials(opts \\ []) do
    Utils.setup_credentials(opts)
  end

  @doc """
  Sets up an SSH key for git.
  """
  @spec setup_ssh_key(binary()) :: :ok | {:error, binary()}
  def setup_ssh_key(ssh_key) do
    Utils.setup_ssh_key(ssh_key)
  end

  @doc """
  Sets up a credential helper for git.
  """
  @spec setup_credential_helper(binary()) :: :ok | {:error, binary()}
  def setup_credential_helper(credential_helper) do
    Utils.setup_credential_helper(credential_helper)
  end

  @doc """
  Quotes a binary string for safe shell use.
  """
  @spec shell_quote(binary()) :: binary()
  def shell_quote(str) when is_binary(str) do
    Utils.shell_quote(str)
  end

  @doc """
  Builds git options for a repository path and optional timeout.
  """
  @spec build_git_opts(binary(), integer() | nil) :: keyword()
  def build_git_opts(repo_path, timeout) do
    Utils.build_git_opts(repo_path, timeout)
  end

  @doc """
  Builds churn arguments for git log.
  """
  @spec build_churn_args(keyword()) :: [binary()]
  def build_churn_args(opts) do
    History.build_churn_args(opts)
  end

  @doc """
  Parses churn output.
  """
  @spec parse_churn_output(binary(), boolean()) :: binary()
  def parse_churn_output(output, _include_authors?) do
    History.parse_churn_output(output, false)
  end

  @doc """
  Checks if a repository contains no commits.
  """
  @spec contains_no_commits?(any()) :: boolean()
  def contains_no_commits?(err) do
    History.contains_no_commits?(err)
  end

  @doc """
  Runs a git command with options.
  """
  @spec run_git([binary()], keyword()) :: {:ok, map()} | {:error, any()}
  def run_git(git_args, opts \\ []) do
    Utils.run_git(git_args, opts)
  end

  @doc """
  Runs a system command with telemetry instrumentation.
  """
  @spec run_system_cmd(binary(), binary(), keyword()) :: {:ok, map()} | {:error, any()}
  def run_system_cmd(cmd, telemetry_cmd_line, opts \\ []) do
    Utils.run_system_cmd(cmd, telemetry_cmd_line, opts)
  end

  @doc """
  Gets the current working directory.
  """
  @spec get_working_directory() :: binary()
  def get_working_directory do
    {:ok, dir} = File.cwd()
    dir
  end
end
