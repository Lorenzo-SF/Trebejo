defmodule Trebejo.Util do
  @moduledoc """
  Shared utilities for Trebejo modules.

  Provides shell-quoting and a unified command runner that routes
  through `SafeCommand.execute/3` for consistent validation and error
  handling.
  """

  alias Trebejo.SafeCommand

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
  Runs a command via `SafeCommand.execute/3`, returning
  `{:ok, stdout, exit_code}` or `{:error, reason}`.

  This is the single integration point with Arrea so that error handling
  is consistent everywhere and command names are validated.

  ## Options

  All options are forwarded to `SafeCommand.execute/3`. See
  `SafeCommand.execute/3` for details. By default `validate` is set to
  `false` to maintain backward compatibility with existing callers.
  """
  @spec run_cmd(binary(), [binary()], keyword()) ::
          {:ok, binary(), non_neg_integer()} | {:error, term()}
  def run_cmd(cmd_name, args, opts \\ []) do
    base_opts = [validate: false, stderr_to_stdout: true]
    full_opts = Keyword.merge(base_opts, opts)

    case SafeCommand.execute(cmd_name, args, full_opts) do
      {:ok, %{stdout: out, exit_code: code}} ->
        {:ok, out, code}

      {:error, reason} ->
        {:error, reason}
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
  Runs a command and returns `:ok` on zero exit or `{:error, reason}`.
  """
  @spec run_ok(binary(), [binary()], keyword()) :: :ok | {:error, binary()}
  def run_ok(cmd_name, args, opts \\ []) do
    case run_cmd(cmd_name, args, opts) do
      {:ok, _out, 0} -> :ok
      {:ok, out, _code} -> {:error, String.trim(out)}
      {:error, reason} -> {:error, inspect(reason)}
    end
  end
end
