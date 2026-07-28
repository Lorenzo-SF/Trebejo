defmodule Trebejo.Compress.Format do
  @moduledoc """
  Detects archive/compression format from file extensions and lists archive contents.
  """

  alias Trebejo.Util

  @type archive_type ::
          :zip | :tar | :tar_gz | :tar_bz2 | :tar_xz | :tar_zst | :gz | :zst | :xz | :bz2 | :seven_z | :rar | :unknown

  @archive_types [
    {".tar.gz", :tar_gz},
    {".tgz", :tar_gz},
    {".tar.bz2", :tar_bz2},
    {".tbz2", :tar_bz2},
    {".tar.xz", :tar_xz},
    {".txz", :tar_xz},
    {".tar.zst", :tar_zst},
    {".tzst", :tar_zst},
    {".tar", :tar},
    {".zip", :zip},
    {".gz", :gz},
    {".zstd", :zst},
    {".zst", :zst},
    {".xz", :xz},
    {".bz2", :bz2},
    {".7z", :seven_z},
    {".rar", :rar}
  ]

  @doc """
  Detects the archive or compression type from a file extension.
  """
  @spec detect_type(binary()) :: archive_type()
  def detect_type(path) do
    down = String.downcase(path)

    Enum.find_value(@archive_types, :unknown, fn {suffix, type} ->
      if String.ends_with?(down, suffix), do: type
    end)
  end

  @doc """
  Lists the contents of an archive. Auto-detects format.
  """
  @spec list(binary()) :: {:ok, [binary()]} | {:error, binary()}
  def list(file) do
    {cmd, args} = list_cmd_args(file)

    case Util.run_cmd_legacy(cmd, args, stderr_to_stdout: true) do
      {output, 0} ->
        lines =
          output
          |> String.split("\n", trim: true)
          |> Enum.map(&String.trim/1)
          |> Enum.reject(&(&1 == ""))

        {:ok, lines}

      {err, _} ->
        {:error, String.trim(err)}
    end
  end

  defp list_cmd_args(file) do
    case detect_type(file) do
      :zip -> {"unzip", ["-l", file]}
      :tar -> {"tar", ["-tvf", file]}
      :tar_gz -> {"tar", ["-tzvf", file]}
      :tar_bz2 -> {"tar", ["-tjvf", file]}
      :tar_xz -> {"tar", ["-tJvf", file]}
      :tar_zst -> {"tar", ["--zstd", "-tvf", file]}
      :seven_z -> {"7z", ["l", file]}
      :rar -> {"unrar", ["l", file]}
      _ -> {"file", [file]}
    end
  end
end
