defmodule Trebejo.Util do
  @moduledoc """
  Shared utilities for Trebejo modules.

  Provides shell-quoting and a unified command runner that routes
  through `Arrea.Command.execute/2`, with consistent error handling.
  """

  alias Arrea.Command

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
  Runs a command via Arrea.Command, returning `{:ok, stdout, exit_code}` or
  `{:error, reason}`.

  This is the single integration point with Arrea so that error handling
  is consistent everywhere.
  """
  @spec run_cmd(binary(), [binary()], keyword()) ::
          {:ok, binary(), non_neg_integer()} | {:error, term()}
  def run_cmd(cmd_name, args, opts \\ []) do
    cmd_line = build_cmd_line(cmd_name, args)
    base_opts = [validate: false, stderr_to_stdout: true]
    full_opts = Keyword.merge(base_opts, opts)

    case Command.execute(cmd_line, full_opts) do
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

  # Build a single command string from binary name + quoted args.
  defp build_cmd_line(cmd_name, args) do
    quoted = Enum.map(args, &shell_quote/1)
    [cmd_name | quoted] |> Enum.join(" ")
  end
end
