defmodule Trebejo.Compress.Tar do
  @moduledoc """
  TAR archive operations — create and extract with optional compression.
  """

  alias Trebejo.Compress.Format
  alias Trebejo.Util

  @doc """
  Creates a tar archive. Supports compression: `:gzip`, `:bzip2`, `:xz`, `:zstd`, `:none`.
  """
  @spec tar(binary(), binary(), keyword()) :: {:ok, binary()} | {:error, binary()}
  def tar(output, input, opts \\ []) do
    compressed = Keyword.get(opts, :compressed, :none)

    {flag_list, extra_flag} =
      case compressed do
        :gzip -> {["-c", "-z", "-v", "-f"], []}
        :bzip2 -> {["-c", "-j", "-v", "-f"], []}
        :xz -> {["-c", "-J", "-v", "-f"], []}
        :zstd -> {["-c", "-v", "-f"], ["--zstd"]}
        :none -> {["-c", "-v", "-f"], []}
      end

    args = extra_flag ++ flag_list ++ [output, input]

    case Util.run_cmd_legacy("tar", args, stderr_to_stdout: true) do
      {_out, 0} -> {:ok, output}
      {err, _} -> {:error, String.trim(err)}
    end
  end

  @doc "Extracts a tar archive. Compression auto-detected from extension."
  @spec untar(binary(), keyword()) :: {:ok, binary()} | {:error, binary()}
  def untar(file, opts \\ []) do
    output = Keyword.get(opts, :output, ".")
    type = Format.detect_type(file)

    {flag_list, extra_flag} =
      case type do
        :tar_gz -> {["-x", "-z", "-v", "-f"], []}
        :tar_bz2 -> {["-x", "-j", "-v", "-f"], []}
        :tar_xz -> {["-x", "-J", "-v", "-f"], []}
        :tar_zst -> {["-x", "-v", "-f"], ["--zstd"]}
        _ -> {["-x", "-v", "-f"], []}
      end

    args = extra_flag ++ flag_list ++ [file, "-C", output]

    case Util.run_cmd_legacy("tar", args, stderr_to_stdout: true) do
      {_out, 0} -> {:ok, output}
      {err, _} -> {:error, String.trim(err)}
    end
  end
end
