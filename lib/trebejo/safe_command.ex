defmodule Trebejo.SafeCommand do
  @moduledoc """
  Safe wrapper around Arrea.Command.execute/2.

  This is the **single entry point** for all command execution in Trebejo.
  Modules must call `SafeCommand.execute/3` instead of calling
  `Arrea.Command.execute/2` directly.

  Validation ensures:
  * the command name is non‑empty and contains only safe characters
  * each argument passes the `shell_quote/1` transform

  ## Usage

      # Run a simple command:
      SafeCommand.execute("echo", ["hello"], validate: false)
  """

  alias Arrea.Command
  alias Trebejo.Util

  @safe_command_regex ~r/^[a-zA-Z0-9_\/\.-]+$/

  @doc """
  Executes a command string directly (legacy API).

  Validates the command and delegates to `Arrea.Command.execute/2`.
  For new code, prefer `execute/3` with explicit arg lists.
  """
  @spec execute(binary()) :: {:ok, map()} | {:error, term()}
  def execute(cmd_str) when is_binary(cmd_str) do
    parts = String.split(cmd_str)

    case parts do
      [] ->
        {:error, :empty_command}

      [cmd_name | args] ->
        execute(cmd_name, args, validate: true, stderr_to_stdout: true)
    end
  end

  @doc """
  Executes a command with the given arguments.

  ## Options

    * `:validate` — when `false`, skips the command-name validation
      (default: `true`). Passed through to `Arrea.Command.execute/2`.
    * All other options are forwarded to `Arrea.Command.execute/2`.
  """
  @spec execute(binary(), [binary()], keyword()) :: {:ok, map()} | {:error, term()}
  def execute(cmd_name, args, opts \\ []) when is_binary(cmd_name) and is_list(args) do
    with :ok <- validate_cmd(cmd_name, Keyword.get(opts, :validate, true)) do
      cmd_line = build_cmd_line(cmd_name, args)
      base_opts = [stderr_to_stdout: true]
      full_opts = Keyword.merge(base_opts, Keyword.drop(opts, [:validate]))

      Command.execute(cmd_line, full_opts)
    end
  end

  # Build a single command line from binary name + shell-quoted args.
  defp build_cmd_line(cmd_name, args) do
    quoted = Enum.map(args, &Util.shell_quote/1)
    [cmd_name | quoted] |> Enum.join(" ")
  end

  # Validate the command name contains only safe characters.
  defp validate_cmd(_cmd_name, false), do: :ok

  defp validate_cmd(cmd_name, true) when is_binary(cmd_name) do
    cond do
      cmd_name == "" ->
        {:error, :empty_command}

      not Regex.match?(@safe_command_regex, cmd_name) ->
        {:error, :unsafe_command_name}

      true ->
        :ok
    end
  end
end
