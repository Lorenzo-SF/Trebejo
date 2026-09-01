defmodule Trebejo.Util do
  @moduledoc """
  Shared utilities for Trebejo modules.

  Provides shell-quoting and a unified command runner that routes
  through `SafeCommand.execute/3` for consistent validation and error
  handling.
  """

  alias Trebejo.Error, as: TrebejoError
  alias Trebejo.SafeCommand

  @default_timeout 30_000

  @doc """
  Single-quote a string for safe inclusion in a POSIX shell command.

  Replaces internal single quotes with the standard `'\\''`
  close-then-reopen pattern.
  """
  @spec shell_quote(String.t()) :: String.t()
  def shell_quote(str) when is_binary(str) do
    escaped = String.replace(str, "'", "'\\''")
    "'#{escaped}'"
  end

  @doc """
  Default command timeout in milliseconds (30 s).

  Used by `run_cmd/3` when the caller does not pass `:timeout` and
  forwards `:timeout` to `Arrea.Command` when it does.
  """
  @spec default_timeout() :: pos_integer()
  def default_timeout, do: @default_timeout

  @doc """
  Runs a command via `SafeCommand.execute/3`, returning
  `{:ok, stdout, exit_code}` or `{:error, %Trebejo.Error{}}`.

  This is the single integration point with Arrea so that error handling
  is consistent everywhere and command names are validated.

  ## Options

  All options are forwarded to `SafeCommand.execute/3`. By default
  `validate` is `false` to maintain backward compatibility with
  existing callers, `timeout` is 30 s, and `stderr_to_stdout` is
  `true`. See `SafeCommand.execute/3` for details.
  """
  @spec run_cmd(binary(), [binary()], keyword()) ::
          {:ok, binary(), non_neg_integer()} | {:error, TrebejoError.t()}
  def run_cmd(cmd_name, args, opts \\ []) do
    base_opts = [
      validate: false,
      stderr_to_stdout: true,
      timeout: @default_timeout
    ]

    full_opts = Keyword.merge(base_opts, opts)
    cmd_line = build_cmd_line(cmd_name, args)
    start = System.monotonic_time()

    case SafeCommand.execute(cmd_name, args, full_opts) do
      {:ok, %{stdout: out, exit_code: code}} ->
        {:ok, out, code}

      {:error, reason} ->
        duration = System.monotonic_time() - start
        {:error, TrebejoError.wrap(reason, cmd: cmd_line, duration_ms: duration)}
    end
  end

  @doc """
  Like `run_cmd/3` but returns the legacy `{output, exit_code}` tuple
  that existing call-sites expect. On Arrea failure (timeout, missing
  binary) returns `{"", 1}` so callers fall through to their error branch.

  Prefer `run_cmd/3` for new code.
  """
  @spec run_cmd_legacy(binary(), [binary()], keyword()) :: {binary(), non_neg_integer()}
  def run_cmd_legacy(cmd_name, args, opts \\ []) do
    case run_cmd(cmd_name, args, opts) do
      {:ok, out, code} -> {out, code}
      {:error, _reason} -> {"", 1}
    end
  end

  @doc """
  Runs a command and returns `:ok` on zero exit or
  `{:error, %Trebejo.Error{}}` on any failure.

  Like `run_cmd/3` but collapses the success branch to `:ok` and wraps
  every error path in a `%Trebejo.Error{}`.
  """
  @spec run_ok(binary(), [binary()], keyword()) :: :ok | {:error, TrebejoError.t()}
  def run_ok(cmd_name, args, opts \\ []) do
    case run_cmd(cmd_name, args, opts) do
      {:ok, _out, 0} -> :ok
      {:ok, out, code} -> {:error, error_from_output(out, code, cmd_name, args, opts)}
      {:error, %TrebejoError{} = err} -> {:error, err}
    end
  end

  defp build_cmd_line(cmd_name, args) do
    quoted = Enum.map(args, &shell_quote/1)
    [cmd_name | quoted] |> Enum.join(" ")
  end

  defp error_from_output(out, code, cmd_name, args, opts) do
    cmd_line = build_cmd_line(cmd_name, args)
    duration_ms = Keyword.get(opts, :_duration_ms)
    TrebejoError.from_exit(code, out, cmd_line, duration_ms: duration_ms)
  end

  defmodule Runner do
    @moduledoc false
    @behaviour Trebejo.Runner

    @impl true
    def run(cmd_name, args, opts) do
      Trebejo.Util.run_cmd(cmd_name, args, opts)
    end
  end
end
