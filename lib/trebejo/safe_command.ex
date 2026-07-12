defmodule Trebejo.SafeCommand do
  @moduledoc """
  Safe wrapper around Arrea.Command.execute/2 that validates the command string
  before delegating the execution.

  Validation ensures:
  * the command is non‑empty
  * does not contain shell meta characters like ; | $ or backticks.
  """

  @spec execute(String.t(), keyword()) :: {:ok, map()} | {:error, :unsafe_command | :empty_command | any()}
  def execute(command, opts) when is_binary(command) and is_list(opts) do
    with :ok <- validate(command) do
      Arrea.Command.execute(command, Keyword.put(opts, :validate, false))
    end
  end

  @spec execute(String.t()) :: {:ok, map()} | {:error, :unsafe_command | :empty_command | any()}
  def execute(command) when is_binary(command) do
    execute(command, [])
  end

  @spec validate(String.t()) :: :ok | {:error, :unsafe_command | :empty_command}
  defp validate(command) when is_binary(command) do
    trimmed = String.trim(command)
    cond do
      trimmed == "" ->
        {:error, :empty_command}

      Regex.match?(~r/[;&|\$`\\]/, trimmed) ->
        {:error, :unsafe_command}

      true ->
        :ok
    end
  end
end
