defmodule Trebejo.Compress do
  @moduledoc """
  Universal compression and archive utilities.

  Wraps system-level tools behind a consistent `{:ok, result} | {:error, reason}`
  interface. Supports: zip, tar (gzip/bzip2/xz/zstd), gzip, gunzip, zstd, xz,
  bzip2, 7z, rar. Auto-detects format from file extension.

  This module is a facade that delegates to per-format sub-modules:
  `Trebejo.Compress.Format`, `.Zip`, `.Tar`, `.Gzip`, `.Algorithm`, `.SevenZ`, `.Rar`.
  """

  alias Trebejo.Compress.{Algorithm, Format, Gzip, Rar, SevenZ, Tar, Zip}

  @type archive_type :: Format.archive_type()
  @type single_algo :: Algorithm.single_algo()

  @doc """
  Detects the archive or compression type from a file extension.
  Delegates to `Trebejo.Compress.Format.detect_type/1`.
  """
  @spec detect_type(binary()) :: archive_type()
  def detect_type(path), do: Format.detect_type(path)

  @doc """
  Extracts an archive, auto-detecting the format from its extension.

  ## Options
    * `:output` — destination directory (default: current directory)
    * `:password` — optional password for zip/7z/rar
  """
  @spec extract(binary(), keyword()) :: {:ok, binary()} | {:error, binary()}
  def extract(file, opts \\ []) do
    case Format.detect_type(file) do
      :zip -> Zip.unzip(file, opts)
      :tar -> Tar.untar(file, opts)
      type when type in [:tar_gz, :tar_bz2, :tar_xz, :tar_zst] -> Tar.untar(file, opts)
      :gz -> Gzip.gunzip(file)
      :zst -> Algorithm.decompress(file, :zstd)
      :xz -> Algorithm.decompress(file, :xz)
      :bz2 -> Algorithm.decompress(file, :bzip2)
      :seven_z -> SevenZ.extract(file, opts)
      :rar -> Rar.extract(file, opts)
      :unknown -> {:error, "Unknown archive format: #{file}"}
    end
  end

  @doc """
  Creates a zip archive from source paths. Supports password.
  Delegates to `Trebejo.Compress.Zip.zip/3`.
  """
  @spec zip(binary(), [binary()], keyword()) :: {:ok, binary()} | {:error, binary()}
  def zip(output, files, opts \\ []), do: Zip.zip(output, files, opts)

  @doc """
  Extracts a zip archive.
  Delegates to `Trebejo.Compress.Zip.unzip/2`.
  """
  @spec unzip(binary(), keyword()) :: {:ok, binary()} | {:error, binary()}
  def unzip(file, opts \\ []), do: Zip.unzip(file, opts)

  @doc """
  Creates a tar archive. Supports compression: `:gzip`, `:bzip2`, `:xz`, `:zstd`, `:none`.
  Delegates to `Trebejo.Compress.Tar.tar/3`.
  """
  @spec tar(binary(), binary(), keyword()) :: {:ok, binary()} | {:error, binary()}
  def tar(output, input, opts \\ []), do: Tar.tar(output, input, opts)

  @doc "Extracts a tar archive. Compression auto-detected from extension."
  @spec untar(binary(), keyword()) :: {:ok, binary()} | {:error, binary()}
  def untar(file, opts \\ []), do: Tar.untar(file, opts)

  @doc "Compresses a file with gzip (replaces original with .gz)."
  @spec gzip(binary()) :: {:ok, binary()} | {:error, binary()}
  def gzip(file), do: Gzip.gzip(file)

  @doc "Decompresses a gzip file, keeping the original."
  @spec gunzip(binary()) :: {:ok, binary()} | {:error, binary()}
  def gunzip(file), do: Gzip.gunzip(file)

  @doc """
  Compresses a single file with the specified algorithm.
  Replaces the original with the compressed version.
  Delegates to `Trebejo.Compress.Algorithm.compress/2`.
  """
  @spec compress(binary(), single_algo()) :: {:ok, binary()} | {:error, binary()}
  def compress(file, algo), do: Algorithm.compress(file, algo)

  @doc """
  Decompresses a single file. Algorithm auto-detected from extension.
  Delegates to `Trebejo.Compress.Algorithm.decompress/2`.
  """
  @spec decompress(binary(), single_algo()) :: {:ok, binary()} | {:error, binary()}
  def decompress(file, algo), do: Algorithm.decompress(file, algo)

  @doc "Extracts a 7z archive."
  @spec extract_7z(binary(), keyword()) :: {:ok, binary()} | {:error, binary()}
  def extract_7z(file, opts \\ []), do: SevenZ.extract(file, opts)

  @doc "Creates a 7z archive from source paths."
  @spec create_7z(binary(), [binary()], keyword()) :: {:ok, binary()} | {:error, binary()}
  def create_7z(output, files, opts \\ []), do: SevenZ.create(output, files, opts)

  @doc "Extracts a RAR archive."
  @spec extract_rar(binary(), keyword()) :: {:ok, binary()} | {:error, binary()}
  def extract_rar(file, opts \\ []), do: Rar.extract(file, opts)

  @doc "Creates a RAR archive from source paths."
  @spec create_rar(binary(), [binary()], keyword()) :: {:ok, binary()} | {:error, binary()}
  def create_rar(output, files, opts \\ []), do: Rar.create(output, files, opts)

  @doc "Lists the contents of an archive. Auto-detects format."
  @spec list(binary()) :: {:ok, [binary()]} | {:error, binary()}
  def list(file), do: Format.list(file)
end
