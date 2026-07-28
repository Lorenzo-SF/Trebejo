defmodule Trebejo.Image do
  @moduledoc """
  Shell-based image operations: sixel rendering, ASCII conversion,
  and format conversion via external tools.

  These functions wrap external CLI tools (`img2sixel`, `img2txt`,
  ImageMagick's `convert`) through `Trebejo.Util.run_cmd_legacy/3`
  with arg lists — never interpolated into shell strings.

  ## Available tools

  | Tool         | Purpose                    | Required for                    |
  |--------------|----------------------------|---------------------------------|
  | `img2sixel`  | Render image as sixel       | Sixel protocol                  |
  | `img2txt`    | Convert image to ASCII art  | ASCII fallback                  |
  | `convert`    | Image format conversion     | Non-PNG image loading           |
  """

  alias Trebejo.Util

  @doc """
  Renders an image to sixel format using `img2sixel`.

  Returns `{:ok, output_string}` on success, `{:error, reason}` on failure,
  or `:tool_not_found` if `img2sixel` is not installed.
  """
  @spec render_sixel(String.t(), pos_integer(), pos_integer()) ::
          {:ok, String.t()} | {:error, String.t()} | :tool_not_found
  def render_sixel(path, width, height) do
    if System.find_executable("img2sixel") do
      case Util.run_cmd_legacy("img2sixel", ["-w", to_string(width), "-h", to_string(height), path]) do
        {out, 0} -> {:ok, out}
        {err, _} -> {:error, String.slice(err, 0, 200)}
      end
    else
      :tool_not_found
    end
  end

  @doc """
  Converts an image to ASCII using `img2txt`.

  Returns `{:ok, output_string}` on success, `{:error, reason}` on failure,
  or `:tool_not_found` if `img2txt` is not installed.
  """
  @spec image_to_ascii(String.t(), pos_integer()) ::
          {:ok, String.t()} | {:error, String.t()} | :tool_not_found
  def image_to_ascii(path, width) do
    if System.find_executable("img2txt") do
      case Util.run_cmd_legacy("img2txt", ["-W", to_string(width), path]) do
        {out, 0} -> {:ok, out}
        {err, _} -> {:error, String.slice(err, 0, 200)}
      end
    else
      :tool_not_found
    end
  end

  @doc """
  Converts an image to PNG using ImageMagick's `convert`.

  Resizes to fit within `width x height`. Returns `{:ok, tmp_path}`
  on success, or `{:error, reason}`. The caller is responsible for
  cleaning up the temp file.

  Returns `:tool_not_found` if `convert` is not installed.
  """
  @spec convert_to_png(String.t(), pos_integer(), pos_integer()) ::
          {:ok, String.t()} | {:error, String.t()} | :tool_not_found
  def convert_to_png(path, target_w, target_h) do
    if System.find_executable("convert") do
      safe_path = if String.starts_with?(path, "-"), do: "./#{path}", else: path
      tmp = Path.expand("/tmp/alaja_img_#{:erlang.unique_integer([:positive])}.png")

      case Util.run_cmd_legacy("convert", [safe_path, "-resize", "#{target_w}x#{target_h}>", tmp]) do
        {_out, 0} -> {:ok, tmp}
        {err, _} -> {:error, String.slice(err, 0, 200)}
      end
    else
      :tool_not_found
    end
  end
end
