defmodule Trebejo.Compress.Zip do
  @moduledoc """
  ZIP archive operations — create and extract.
  """

  alias Trebejo.Util

  @doc """
  Creates a zip archive from source paths. Supports password.

  > ⚠️ **Security**: The password is passed via `-P` on the command line
  > and is visible in the process list (`ps aux`). The `zip` tool does
  > not support reading passwords from stdin.
  """
  @spec zip(binary(), [binary()], keyword()) :: {:ok, binary()} | {:error, binary()}
  def zip(output, files, opts \\ []) do
    cd = Keyword.get(opts, :cd, ".")
    password = Keyword.get(opts, :password)

    args =
      if password do
        ["-r", "-P", password, output] ++ files
      else
        ["-r", output] ++ files
      end

    case Util.run_cmd_legacy("zip", args, cd: cd, stderr_to_stdout: true) do
      {_out, 0} -> {:ok, output}
      {err, _} -> {:error, String.trim(err)}
    end
  end

  @doc """
  Extracts a zip archive.

  > ⚠️ **Security**: The password is passed via `-P` on the command line
  > and is visible in the process list (`ps aux`). The `unzip` tool does
  > not support reading passwords from stdin.
  """
  @spec unzip(binary(), keyword()) :: {:ok, binary()} | {:error, binary()}
  def unzip(file, opts \\ []) do
    output = Keyword.get(opts, :output, ".")
    password = Keyword.get(opts, :password)

    args =
      if password do
        ["-o", "-P", password, "-d", output, file]
      else
        ["-o", "-d", output, file]
      end

    case Util.run_cmd_legacy("unzip", args, stderr_to_stdout: true) do
      {_out, 0} -> {:ok, output}
      {err, _} -> {:error, String.trim(err)}
    end
  end
end
