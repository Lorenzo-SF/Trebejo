defmodule Trebejo.Git.Local.Clone do
  @moduledoc """
  Git repository cloning, update and existence-check operations.
  """

  alias Apero.File.Tree
  alias Trebejo.Git.Local

  @doc """
  Updates an existing repository by fetching from origin.
  """
  @spec update_existing_repository(binary()) :: {:ok, binary()} | {:error, any()}
  def update_existing_repository(repo_path) do
    if File.dir?(repo_path) do
      fetch_repository_updates(repo_path)
    else
      {:error, {:cannot_access_path, :enoent}}
    end
  end

  @doc """
  Fetches repository updates from origin.
  """
  @spec fetch_repository_updates(binary()) :: {:ok, binary()} | {:error, any()}
  def fetch_repository_updates(repo_path) do
    case Local.run_git(["rev-parse", "--git-dir"], cd: repo_path) do
      {:ok, %{exit_code: 0}} -> fetch_all_changes(repo_path)
      _ -> {:error, :not_a_git_repository}
    end
  end

  @doc """
  Fetches all changes from origin.
  """
  @spec fetch_all_changes(binary()) :: {:ok, binary()} | {:error, any()}
  def fetch_all_changes(repo_path) do
    case Local.run_git(["fetch", "--all"], cd: repo_path) do
      {:ok, %{exit_code: 0, stdout: output}} -> {:ok, String.trim(output)}
      _ -> {:error, :fetch_failed}
    end
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
    Enum.map(repos, fn repo -> ensure_clone(repo, workspace_path) end)
  end

  def ensure_clone(%{url: _url, path: path} = repo, _workspace_path)
      when is_binary(path) do
    if File.dir?(path) do
      {:repo_exists, repo}
    else
      case Local.clone(repo) do
        {:ok, repo} -> {:repo_cloned, repo}
        {:error, reason} -> {:repo_error, repo, reason}
      end
    end
  end

  @doc """
  Returns a tree string of existing (already-cloned) repositories from a list
  of `{:repo_exists | :repo_error, map(), ...}` tuples.
  """
  @spec existing_repos([tuple()]) :: binary()
  def existing_repos(repos) do
    repos
    |> Enum.filter(fn
      {:repo_exists, %{path: _}, _} -> true
      {:repo_exists, %{path: _}} -> true
      _ -> false
    end)
    |> Enum.map(fn
      {:repo_exists, %{path: path}, _} -> path
      {:repo_exists, %{path: path}} -> path
    end)
    |> Tree.generate_tree()
  end

  @doc """
  Clones a repository from `url` to `path`.
  """
  @spec clone(map()) :: {:ok, map()} | {:error, any()}
  def clone(%{url: url, path: path} = repo) do
    case Local.clone_repository(url, path) do
      {:ok, _output} -> {:ok, repo}
      {:error, output} -> {:error, {output, repo}}
    end
  end

  @doc """
  Clones a repository from a URL to a target path.
  """
  @spec clone_repository(binary(), binary()) :: {:ok, binary()} | {:error, any()}
  def clone_repository(url, target_path) do
    env = %{"GIT_TERMINAL_PROMPT" => "0"}

    case Local.run_git(["clone", "--quiet", url, target_path], env: env) do
      {:ok, %{exit_code: 0, stdout: output}} -> {:ok, String.trim(output)}
      {:ok, %{stdout: output}} -> {:error, String.trim(output)}
      {:error, reason} -> {:error, inspect(reason)}
    end
  end
end
