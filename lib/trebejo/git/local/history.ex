defmodule Trebejo.Git.Local.History do
  @moduledoc """
  Git history operations — log, blame, diff, churn, commit info.
  """

  alias Trebejo.Git.Local

  @doc """
  Shows commit history (log).
  """
  @spec log(binary(), keyword()) :: {:ok, binary()} | {:error, binary()}
  def log(repo_path \\ ".", opts \\ []) do
    count = Keyword.get(opts, :count, 10)
    format = Keyword.get(opts, :format, "--oneline")
    format_args = String.split(format, " ")

    case Local.run_git(["log", "-#{count}"] ++ format_args, cd: repo_path) do
      {:ok, %{exit_code: 0, stdout: out}} -> {:ok, String.trim(out)}
      {:ok, %{stdout: err}} -> {:error, String.trim(err)}
      {:error, reason} -> {:error, inspect(reason)}
    end
  end

  @doc """
  Shows who last modified each line of a file (blame).
  """
  @spec blame(binary(), binary()) :: {:ok, binary()} | {:error, binary()}
  def blame(repo_path, file) do
    case Local.run_git(["blame", file], cd: repo_path) do
      {:ok, %{exit_code: 0, stdout: out}} -> {:ok, String.trim(out)}
      {:ok, %{stdout: err}} -> {:error, String.trim(err)}
      {:error, reason} -> {:error, inspect(reason)}
    end
  end

  @doc """
  Shows diff of changes.
  """
  @spec diff(binary(), keyword()) :: {:ok, binary()} | {:error, binary()}
  def diff(repo_path \\ ".", opts \\ []) do
    staged = Keyword.get(opts, :staged, false)
    args = if staged, do: ["diff", "--staged"], else: ["diff"]

    case Local.run_git(args, cd: repo_path) do
      {:ok, %{exit_code: 0, stdout: out}} -> {:ok, String.trim(out)}
      {:ok, %{stdout: err}} -> {:error, String.trim(err)}
      {:error, reason} -> {:error, inspect(reason)}
    end
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
    top = Keyword.get(opts, :top, 20)
    include_authors = Keyword.get(opts, :include_authors, false)
    args = build_churn_args(opts)
    git_opts = Local.build_git_opts(repo_path, Keyword.get(opts, :timeout))

    case Local.run_git(args, git_opts) do
      {:ok, %{exit_code: 0, stdout: out}} ->
        {:ok, parse_churn_output(out, include_authors) |> Enum.take(top)}

      {:ok, %{exit_code: 128, stdout: err}} ->
        if contains_no_commits?(err) do
          {:ok, []}
        else
          {:error, String.trim(err)}
        end

      {:ok, %{stdout: err}} ->
        {:error, String.trim(err)}

      {:error, reason} ->
        {:error, inspect(reason)}
    end
  end

  @doc """
  Gets the short (7-char) commit hash for `HEAD`.
  """
  @spec get_short_commit(binary()) :: {:ok, binary()} | {:error, binary()}
  def get_short_commit(repo_path) do
    case log(repo_path, ["-1", "--format=%h"]) do
      {:ok, sha} -> {:ok, String.trim(sha)}
      error -> error
    end
  end

  @doc """
  Returns the list of commits between `from_sha` and `to_sha`.

  Equivalent to `git log from_sha..to_sha`.  By default returns a list
  of `{:ok, sha, message}` tuples, one per commit.

  ## Options

    * `:format` — `:short | :full | :oneline` (default `:short`)

  ## Examples

      iex> Trebejo.Git.Local.History.commits_between(".", "abc123", "HEAD")
      {:ok, [{"def456", "Fix bug"}, {"ghi789", "Add feature"}]}
  """
  @spec commits_between(binary(), binary(), binary(), keyword()) ::
          {:ok, [{binary(), binary()}]} | {:error, binary()}
  def commits_between(repo_path, from_sha, to_sha, opts \\ []) do
    format = Keyword.get(opts, :format, :short)

    format_flag =
      case format do
        :short -> "--format=%h %s"
        :full -> "--format=%H %s%n%b"
        :oneline -> "--format=%h %s"
      end

    range = "#{from_sha}..#{to_sha}"

    case log(repo_path, [range, format_flag, "--"]) do
      {:ok, ""} ->
        {:ok, []}

      {:ok, output} ->
        commits =
          output
          |> String.split("\n", trim: true)
          |> Enum.map(&parse_commit_line(&1, format))

        {:ok, commits}

      error ->
        error
    end
  end

  defp parse_commit_line(line, :full) do
    case String.split(line, "\n", parts: 2) do
      [first, body] ->
        [sha, subject] = String.split(first, " ", parts: 2)
        {sha, "#{subject}\n#{String.trim(body)}"}

      [first] ->
        [sha, subject] = String.split(first, " ", parts: 2)
        {sha, subject}
    end
  end

  defp parse_commit_line(line, _format) do
    case String.split(line, " ", parts: 2) do
      [sha, subject] -> {sha, subject}
      [sha] -> {sha, ""}
    end
  end
    case Local.run_git(["rev-parse", "--short", "HEAD"], cd: repo_path) do
      {:ok, %{exit_code: 0, stdout: output}} -> {:ok, String.trim(output)}
      {:ok, %{stdout: output}} -> {:error, String.trim(output)}
      {:error, reason} -> {:error, inspect(reason)}
    end
  end

  @doc """
  Gets the current commit hash for a repository.
  """
  @spec get_current_commit(binary()) :: {:ok, binary()} | {:error, any()}
  def get_current_commit(repo_path) do
    case Local.run_git(["rev-parse", "HEAD"], cd: repo_path) do
      {:ok, %{exit_code: 0, stdout: output}} -> {:ok, String.trim(output)}
      error -> error
    end
  end

  @doc """
  Gets the commit count for a repository.
  """
  @spec get_commit_count(binary()) :: {:ok, integer()} | {:error, any()}
  def get_commit_count(repo_path) do
    case Local.run_git(["rev-list", "--count", "HEAD"], cd: repo_path) do
      {:ok, %{exit_code: 0, stdout: output}} ->
        {:ok, String.to_integer(String.trim(output))}

      error ->
        error
    end
  end

  @doc """
  Gets the first commit hash for a repository.
  """
  @spec get_first_commit(binary()) :: {:ok, binary()} | {:error, any()}
  def get_first_commit(repo_path) do
    case Local.run_git(["rev-list", "--max-parents=0", "HEAD"], cd: repo_path) do
      {:ok, %{exit_code: 0, stdout: output}} -> {:ok, String.trim(output)}
      error -> error
    end
  end

  @doc false
  def build_churn_args(opts) do
    max_commits = Keyword.get(opts, :max_commits)
    period = Keyword.get(opts, :period, "6.months")
    branch = Keyword.get(opts, :branch)
    no_merges = Keyword.get(opts, :no_merges, false)
    include_authors = Keyword.get(opts, :include_authors, false)

    format =
      if include_authors, do: "--format=COMMIT:%an", else: "--pretty=format:"

    limit =
      if max_commits,
        do: ["--max-count=#{max_commits}"],
        else: ["--since=#{period}"]

    ["log", "--name-only", format] ++
      limit ++
      if(no_merges, do: ["--no-merges"], else: []) ++
      if(branch, do: [branch], else: [])
  end

  @doc false
  def parse_churn_output(output, include_authors?) do
    if include_authors? do
      output
      |> String.split("\n")
      |> Enum.reduce({%{}, nil}, &process_churn_line/2)
      |> elem(0)
      |> Enum.map(fn {file, %{churn: churn, authors: authors}} ->
        %{file: file, churn: churn, authors: Enum.uniq(authors)}
      end)
      |> Enum.sort_by(fn %{churn: c} -> -c end)
    else
      output
      |> String.split("\n", trim: true)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.frequencies()
      |> Enum.sort_by(fn {_file, count} -> -count end)
      |> Enum.map(fn {file, count} -> %{file: file, churn: count} end)
    end
  end

  defp process_churn_line(line, {acc, author}) do
    cond do
      String.starts_with?(line, "COMMIT:") ->
        {acc, String.slice(line, 7..-1//1)}

      String.trim(line) != "" and author != nil ->
        path = String.trim(line)

        updated =
          Map.update(acc, path, %{churn: 1, authors: [author]}, fn s ->
            %{churn: s.churn + 1, authors: [author | s.authors]}
          end)

        {updated, author}

      true ->
        {acc, author}
    end
  end

  @doc false
  def contains_no_commits?(err) do
    String.contains?(err, "no commits") or String.contains?(err, "no tiene ningún commit")
  end
end
