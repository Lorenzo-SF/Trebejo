defmodule Trebejo.Git.Local.Sync do
  @moduledoc """
  Git repository synchronization operations — checkout, fetch and pull.
  """

  alias Trebejo.Git.Local

  @doc """
  Synchronises a list of repositories (checkout → fetch → pull).
  """
  @spec sync([map()]) :: :ok
  def sync(repos) when is_list(repos) do
    Enum.each(repos, &sync/1)
  end

  @doc """
  Synchronises a single repository: checkout main branch, fetch, then pull.
  """
  @spec sync(map()) :: {:ok, map()} | {:error, any()}
  def sync(%{path: _path} = repo) do
    with {:ok, repo} <- Local.checkout(repo),
         {:ok, repo} <- Local.fetch(repo),
         {:ok, repo} <- Local.pull(repo) do
      {:ok, repo}
    else
      {:error, reason} -> {:error, reason}
    end
  end
end
