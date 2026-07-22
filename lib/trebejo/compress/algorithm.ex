defmodule Trebejo.Compress.Algorithm do
  @moduledoc """
  Single-file compression algorithms: zstd, xz, bzip2.
  """

  alias Trebejo.Util

  @type single_algo :: :zstd | :xz | :bzip2 | :gzip

  @doc """
  Compresses a single file with the specified algorithm.
  Replaces the original with the compressed version.
  """
  @spec compress(binary(), single_algo()) :: {:ok, binary()} | {:error, binary()}
  def compress(file, :zstd) do
    case Util.run_cmd_legacy("zstd", [file, "--rm"], stderr_to_stdout: true) do
      {_out, 0} -> {:ok, file <> ".zst"}
      {err, _} -> {:error, String.trim(err)}
    end
  end

  def compress(file, :xz) do
    case Util.run_cmd_legacy("xz", [file], stderr_to_stdout: true) do
      {_out, 0} -> {:ok, file <> ".xz"}
      {err, _} -> {:error, String.trim(err)}
    end
  end

  def compress(file, :bzip2) do
    case Util.run_cmd_legacy("bzip2", [file], stderr_to_stdout: true) do
      {_out, 0} -> {:ok, file <> ".bz2"}
      {err, _} -> {:error, String.trim(err)}
    end
  end

  def compress(_file, algo), do: {:error, "Unsupported algorithm: #{algo}"}

  @doc """
  Decompresses a single file. Algorithm auto-detected from extension.
  """
  @spec decompress(binary(), single_algo()) :: {:ok, binary()} | {:error, binary()}
  def decompress(file, :zstd) do
    case Util.run_cmd_legacy("zstd", ["-d", file, "--rm"], stderr_to_stdout: true) do
      {_out, 0} -> {:ok, String.replace_suffix(file, ".zst", "")}
      {err, _} -> {:error, String.trim(err)}
    end
  end

  def decompress(file, :xz) do
    case Util.run_cmd_legacy("xz", ["-d", file], stderr_to_stdout: true) do
      {_out, 0} -> {:ok, String.replace_suffix(file, ".xz", "")}
      {err, _} -> {:error, String.trim(err)}
    end
  end

  def decompress(file, :bzip2) do
    case Util.run_cmd_legacy("bzip2", ["-d", file], stderr_to_stdout: true) do
      {_out, 0} -> {:ok, String.replace_suffix(file, ".bz2", "")}
      {err, _} -> {:error, String.trim(err)}
    end
  end

  def decompress(_file, algo), do: {:error, "Unsupported algorithm: #{algo}"}
end
