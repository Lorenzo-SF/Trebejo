defmodule Trebejo.GitHub do
  @moduledoc """
  GitHub CLI wrapper around `gh`.

  Covers the three highest-ROI subcommands used by agents and humans
  alike: `pr`, `issue`, `release`. For the full `gh` surface area,
  call `Trebejo.GitHub.run/2` with any `gh` args.

  Routes everything through `Trebejo.Util.run_cmd/3` (via
  `Trebejo.Runner`) so it picks up `:timeout`, the circuit breaker, and
  `Trebejo.Mox` mocking.

  ## Options (shared)

    * `:repo` — `owner/repo` (e.g. `"Lorenzo-SF/arrea"`). Defaults to
      the value of `gh repo set-default` if `gh` is logged in.
    * `:cwd` — run from this directory (where the local clone lives)
    * `:timeout` — passed through to the underlying runner
    * `:breaker` — circuit breaker name

  ## Authentication

  `gh` itself manages auth (`gh auth login`). Trebejo does not pass
  tokens — it relies on the `gh` CLI finding a valid session.

  ## Examples

      iex> Trebejo.GitHub.run(["pr", "list", "--state", "open"], repo: "Lorenzo-SF/arrea")
      {:ok, "12\\tMigrate to arrea 3.0\\t...\\n", 0}
  """

  alias Trebejo.Error, as: TrebejoError
  alias Trebejo.Runner

  @doc """
  Generic `gh` invocation. Use this for subcommands not covered by the
  specialised helpers below.
  """
  @spec run([String.t()], keyword()) ::
          {:ok, String.t(), 0} | {:error, TrebejoError.t()}
  def run(args, opts \\ []) when is_list(args) do
    gh_args = gh_args(args, opts)
    runner_opts = Keyword.drop(opts, [:repo, :cwd, :breaker])

    result =
      case opts[:breaker] do
        nil -> Runner.run("gh", gh_args, runner_opts)
        name -> Trebejo.Breaker.with_breaker(name, fn -> Runner.run("gh", gh_args, runner_opts) end)
      end

    case result do
      {:ok, out, 0} ->
        {:ok, out, 0}

      {:ok, out, code} ->
        {:error, exit_to_error(out, code, gh_args)}

      {:error, %TrebejoError{} = err} ->
        {:error, err}

      {:error, reason} ->
        cmd_line = Enum.join(["gh" | gh_args], " ")
        {:error, TrebejoError.wrap(reason, cmd: cmd_line)}
    end
  end

  # ── PR ──────────────────────────────────────────────────────────────────

  @doc """
  List pull requests. Thin wrapper over `gh pr list`.

  See `https://cli.github.com/manual/gh_pr_list` for the available
  flags you can pass in `args`.
  """
  @spec pr_list([String.t()], keyword()) ::
          {:ok, String.t(), 0} | {:error, TrebejoError.t()}
  def pr_list(args \\ [], opts \\ []), do: run(["pr", "list" | args], opts)

  @doc """
  View a single PR (number, title, body, diff). Thin wrapper over
  `gh pr view`.

  Pass `:comments`, `:diff`, or no extra arg for the default view.
  """
  @spec pr_view(String.t() | pos_integer(), keyword()) ::
          {:ok, String.t(), 0} | {:error, TrebejoError.t()}
  def pr_view(pr, opts \\ []) do
    flag =
      cond do
        Keyword.get(opts, :comments) -> "--comments"
        Keyword.get(opts, :diff) -> "--diff"
        true -> nil
      end

    args = ["pr", "view", to_string(pr) | maybe_flag(flag)]
    run(args, opts)
  end

  @doc """
  Create a pull request. Thin wrapper over `gh pr create`.

  At minimum pass `:title` and `:body`; pass `:base` to target a
  specific branch.
  """
  @spec pr_create(keyword()) :: {:ok, String.t(), 0} | {:error, TrebejoError.t()}
  def pr_create(opts) do
    args =
      ["pr", "create"]
      |> append_opt("--title", opts[:title])
      |> append_opt("--body", opts[:body])
      |> append_opt("--base", opts[:base])
      |> append_opt("--head", opts[:head])
      |> append_opt("--draft", if(opts[:draft], do: "--draft", else: nil))

    run(args, opts)
  end

  # ── Issue ───────────────────────────────────────────────────────────────

  @doc """
  List issues. Thin wrapper over `gh issue list`.
  """
  @spec issue_list([String.t()], keyword()) ::
          {:ok, String.t(), 0} | {:error, TrebejoError.t()}
  def issue_list(args \\ [], opts \\ []), do: run(["issue", "list" | args], opts)

  @doc """
  View a single issue. Thin wrapper over `gh issue view`.
  """
  @spec issue_view(String.t() | pos_integer(), keyword()) ::
          {:ok, String.t(), 0} | {:error, TrebejoError.t()}
  def issue_view(issue, opts \\ []) do
    args = [
      "issue",
      "view",
      to_string(issue) | maybe_flag(if(Keyword.get(opts, :comments), do: "--comments", else: nil))
    ]

    run(args, opts)
  end

  @doc """
  Create an issue. Pass `:title` and `:body` (or `:body-file`).
  """
  @spec issue_create(keyword()) :: {:ok, String.t(), 0} | {:error, TrebejoError.t()}
  def issue_create(opts) do
    args =
      ["issue", "create"]
      |> append_opt("--title", opts[:title])
      |> append_opt("--body", opts[:body])
      |> append_opt("--body-file", opts[:body_file])
      |> append_opt("--label", opts[:label])
      |> append_opt("--assignee", opts[:assignee])

    run(args, opts)
  end

  # ── Release ─────────────────────────────────────────────────────────────

  @doc """
  List releases. Thin wrapper over `gh release list`.
  """
  @spec release_list([String.t()], keyword()) ::
          {:ok, String.t(), 0} | {:error, TrebejoError.t()}
  def release_list(args \\ [], opts \\ []), do: run(["release", "list" | args], opts)

  @doc """
  Create a release. Pass `:tag` (required) and optionally `:title`,
  `:notes` (or `:notes-file`), `:target`, `:draft`, `:prerelease`.
  """
  @spec release_create(keyword()) :: {:ok, String.t(), 0} | {:error, TrebejoError.t()}
  def release_create(opts) do
    args =
      ["release", "create", opts[:tag] || ""]
      |> append_opt("--title", opts[:title])
      |> append_opt("--notes", opts[:notes])
      |> append_opt("--notes-file", opts[:notes_file])
      |> append_opt("--target", opts[:target])
      |> append_flag("--draft", opts[:draft])
      |> append_flag("--prerelease", opts[:prerelease])

    run(args, opts)
  end

  # ── Private ─────────────────────────────────────────────────────────────

  @spec gh_args([String.t()], keyword()) :: [String.t()]
  defp gh_args(args, opts) do
    base =
      case opts[:repo] do
        nil -> []
        repo -> ["--repo", repo]
      end

    base ++ args
  end

  @spec maybe_flag(String.t() | nil) :: [String.t()]
  defp maybe_flag(nil), do: []
  defp maybe_flag(flag), do: [flag]

  @spec append_opt([String.t()], String.t(), any()) :: [String.t()]
  defp append_opt(args, _flag, nil), do: args
  defp append_opt(args, flag, value) when is_binary(value), do: args ++ [flag, value]
  defp append_opt(args, flag, value), do: args ++ [flag, to_string(value)]

  @spec append_flag([String.t()], String.t(), any()) :: [String.t()]
  defp append_flag(args, _flag, nil), do: args
  defp append_flag(args, _flag, false), do: args
  defp append_flag(args, flag, _), do: args ++ [flag]

  @spec exit_to_error(String.t(), non_neg_integer(), [String.t()]) :: TrebejoError.t()
  defp exit_to_error(out, code, args) do
    cmd_line = Enum.join(["gh" | args], " ")
    TrebejoError.from_exit(code, out, cmd_line)
  end
end
