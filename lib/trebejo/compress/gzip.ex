defmodule Trebejo.Compress.Gzip do
  @moduledoc """
  GZIP compression and decompression.
  """

  alias Trebejo.Util

  @doc "Compresses a file with gzip (replaces original with .gz)."
  @spec gzip(binary()) :: {:ok, binary()} | {:error, binary()}
  def gzip(file) do
    case Util.run_cmd_legacy("gzip", [file], stderr_to_stdout: true) do
      {_out, 0} -> {:ok, file <> ".gz"}
      {err, _} -> {:error, String.trim(err)}
    end
  end

  @doc "Decompresses a gzip file, keeping the original."
  @spec gunzip(binary()) :: {:ok, binary()} | {:error, binary()}
  def gunzip(file) do
    case Util.run_cmd_legacy("gunzip", ["-k", file], stderr_to_stdout: true) do
      {_out, 0} -> {:ok, String.replace_suffix(file, ".gz", "")}
      {err, _} -> {:error, String.trim(err)}
    end
  end
end
