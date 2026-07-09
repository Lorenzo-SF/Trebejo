defmodule Trebejo.File.IO do
  @moduledoc """
  I/O operations that depend on shell commands.

  Moved from `Apero.File.IO` in v3.0.0. Pure file I/O operations
  (atomic writes, checksums, temp files, locking) remain in `Apero.File.IO`.
  Only `disk_usage/1` (which requires the `df` command via Arrea) lives here.
  """

  alias Arrea.Command

  @doc """
  Returns disk usage information for the filesystem containing `path`.

  Returns a map with `:total_mb`, `:used_mb`, `:free_mb`, `:use_pct`.
  Only supported on Unix-like systems.
  """
  @spec disk_usage(binary()) :: {:ok, map()} | {:error, binary()}
  def disk_usage(path \\ "/") do
    case Command.execute("df -k #{path}",
           validate: false,
           env: %{"LC_ALL" => "C"}
         ) do
      {:ok, %{exit_code: 0, stdout: output}} -> parse_df(output)
      {:ok, %{exit_code: _, stdout: err}} -> {:error, String.trim(err)}
      {:error, reason} -> {:error, inspect(reason)}
    end
  end

  defp parse_df(output) do
    case String.split(output, "\n", trim: true) do
      [_ | [line | _]] ->
        parts = String.split(line, ~r/\s+/, trim: true)

        case parts do
          [_fs, total_kb, used_kb, free_kb | rest] ->
            {:ok,
             %{
               total_mb: div(String.to_integer(total_kb), 1_024),
               used_mb: div(String.to_integer(used_kb), 1_024),
               free_mb: div(String.to_integer(free_kb), 1_024),
               use_pct: parse_use_pct(rest)
             }}

          _ ->
            {:error, "cannot parse df output"}
        end

      _ ->
        {:error, "unexpected df output"}
    end
  end

  defp parse_use_pct(rest) do
    case rest do
      [pct | _] ->
        pct
        |> String.trim_trailing("%")
        |> Integer.parse()
        |> elem(0)

      _ ->
        0
    end
  end
end
