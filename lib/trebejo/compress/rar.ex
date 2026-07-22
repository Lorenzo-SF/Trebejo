defmodule Trebejo.Compress.Rar do
  @moduledoc """
  RAR archive operations — create and extract.
  """

  alias Trebejo.Util

  @doc "Extracts a RAR archive."
  @spec extract(binary(), keyword()) :: {:ok, binary()} | {:error, binary()}
  def extract(file, opts \\ []) do
    output = Keyword.get(opts, :output, ".")

    case Util.run_cmd_legacy("unrar", ["x", "-y", file, output], stderr_to_stdout: true) do
      {_out, 0} -> {:ok, output}
      {err, _} -> {:error, String.trim(err)}
    end
  end

  @doc "Creates a RAR archive from source paths."
  @spec create(binary(), [binary()], keyword()) :: {:ok, binary()} | {:error, binary()}
  def create(output, files, _opts \\ []) do
    case Util.run_cmd_legacy("rar", ["a", output] ++ files, stderr_to_stdout: true) do
      {_out, 0} -> {:ok, output}
      {err, _} -> {:error, String.trim(err)}
    end
  end
end
