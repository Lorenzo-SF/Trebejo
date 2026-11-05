defmodule Trebejo.Compress.SevenZ do
  @moduledoc """
  7-Zip archive operations — create and extract.
  """

  alias Trebejo.Util

  @doc """
  Extracts a 7z archive.

  > ⚠️ **Security**: The password is passed via `-p` on the command line
  > and is visible in the process list (`ps aux`).
  """
  @spec extract(binary(), keyword()) :: {:ok, binary()} | {:error, binary()}
  def extract(file, opts \\ []) do
    output = Keyword.get(opts, :output, ".")
    password = Keyword.get(opts, :password)

    args = ["x", "-o#{output}", "-y", file]
    args = if password, do: args ++ ["-p#{password}"], else: args

    case Util.run_cmd_legacy("7z", args, stderr_to_stdout: true) do
      {_out, 0} -> {:ok, output}
      {err, _} -> {:error, String.trim(err)}
    end
  end

  @doc """
  Creates a 7z archive from source paths.

  > ⚠️ **Security**: The password is passed via `-p` on the command line
  > and is visible in the process list (`ps aux`).
  """
  @spec create(binary(), [binary()], keyword()) :: {:ok, binary()} | {:error, binary()}
  def create(output, files, opts \\ []) do
    cd = Keyword.get(opts, :cd, ".")
    password = Keyword.get(opts, :password)

    args = ["a", output, "-y"] ++ files
    args = if password, do: args ++ ["-p#{password}"], else: args

    case Util.run_cmd_legacy("7z", args, cd: cd, stderr_to_stdout: true) do
      {_out, 0} -> {:ok, output}
      {err, _} -> {:error, String.trim(err)}
    end
  end
end
