defmodule Trebejo.Compress do
  # credo:disable-for-this-file Credo.Check.Refactor.CyclomaticComplexity

  alias Trebejo.Util

  @moduledoc """
  Universal compression and archive utilities.

  Wraps system-level tools behind a consistent `{:ok, result} | {:error, reason}`
  interface. Supports: zip, tar (gzip/bzip2/xz/zstd), gzip, gunzip, zstd, xz,
  bzip2, 7z, rar. Auto-detects format from file extension.

  ## Security

  All paths passed to shell commands are properly escaped. Passwords are
  passed via command-line flags (`-P` for zip/unzip, `-p` for 7z) instead
  of shell piping to avoid shell injection vectors.
  """

  # ═══════════════════════════════════════════════════════════════════════
  # Auto-detect type
  # ═══════════════════════════════════════════════════════════════════════

  @type archive_type ::
          :zip
          | :tar
          | :tar_gz
          | :tar_bz2
          | :tar_xz
          | :tar_zst
          | :gz
          | :zst
          | :xz
          | :bz2
          | :seven_z
          | :rar
          | :unknown

  @doc """
  Detects the archive or compression type from a file extension.

  ## Examples

      iex> Trebejo.Compress.detect_type("backup.tar.gz")
      :tar_gz
      iex> Trebejo.Compress.detect_type("data.zst")
      :zst
      iex> Trebejo.Compress.detect_type("unknown.xyz")
      :unknown
  """
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

  @spec detect_type(binary()) :: archive_type()
  def detect_type(path) do
    down = String.downcase(path)

    Enum.find_value(@archive_types, :unknown, fn {suffix, type} ->
      if String.ends_with?(down, suffix), do: type
    end)
  end

  # ═══════════════════════════════════════════════════════════════════════
  # Universal extract (auto-detect)
  # ═══════════════════════════════════════════════════════════════════════

  @doc """
  Extracts an archive, auto-detecting the format from its extension.

  ## Options
    * `:output` — destination directory (default: current directory)
    * `:password` — optional password for zip/7z/rar

  ## Examples

      Trebejo.Compress.extract("backup.tar.gz", output: "/tmp/restore")
  """
  @spec extract(binary(), keyword()) :: {:ok, binary()} | {:error, binary()}
  def extract(file, opts \\ []) do
    case detect_type(file) do
      :zip -> unzip(file, opts)
      :tar -> untar(file, opts)
      type when type in [:tar_gz, :tar_bz2, :tar_xz, :tar_zst] -> untar(file, opts)
      :gz -> gunzip(file)
      :zst -> decompress(file, :zstd)
      :xz -> decompress(file, :xz)
      :bz2 -> decompress(file, :bzip2)
      :seven_z -> extract_7z(file, opts)
      :rar -> extract_rar(file, opts)
      :unknown -> {:error, "Unknown archive format: #{file}"}
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # ZIP
  # ═══════════════════════════════════════════════════════════════════════

  @doc """
  Creates a zip archive from source paths. Supports password.

  > ⚠️ **Security**: The password is passed via `-P` on the command line
  > and is visible in the process list (`ps aux`). The `zip` tool does
  > not support reading passwords from stdin. Prefer encrypted volumes
  > or key-based protection for sensitive data.
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

    case run("zip", args, cd: cd, stderr_to_stdout: true) do
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

    case run("unzip", args, stderr_to_stdout: true) do
      {_out, 0} -> {:ok, output}
      {err, _} -> {:error, String.trim(err)}
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # TAR (with optional compression)
  # ═══════════════════════════════════════════════════════════════════════

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

    case run("tar", args, stderr_to_stdout: true) do
      {_out, 0} -> {:ok, output}
      {err, _} -> {:error, String.trim(err)}
    end
  end

  @doc "Extracts a tar archive. Compression auto-detected from extension."
  @spec untar(binary(), keyword()) :: {:ok, binary()} | {:error, binary()}
  def untar(file, opts \\ []) do
    output = Keyword.get(opts, :output, ".")
    type = detect_type(file)

    {flag_list, extra_flag} =
      case type do
        :tar_gz -> {["-x", "-z", "-v", "-f"], []}
        :tar_bz2 -> {["-x", "-j", "-v", "-f"], []}
        :tar_xz -> {["-x", "-J", "-v", "-f"], []}
        :tar_zst -> {["-x", "-v", "-f"], ["--zstd"]}
        _ -> {["-x", "-v", "-f"], []}
      end

    args = extra_flag ++ flag_list ++ [file, "-C", output]

    case run("tar", args, stderr_to_stdout: true) do
      {_out, 0} -> {:ok, output}
      {err, _} -> {:error, String.trim(err)}
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # GZIP
  # ═══════════════════════════════════════════════════════════════════════

  @doc "Compresses a file with gzip (replaces original with .gz)."
  @spec gzip(binary()) :: {:ok, binary()} | {:error, binary()}
  def gzip(file) do
    case run("gzip", [file], stderr_to_stdout: true) do
      {_out, 0} -> {:ok, file <> ".gz"}
      {err, _} -> {:error, String.trim(err)}
    end
  end

  @doc "Decompresses a gzip file, keeping the original."
  @spec gunzip(binary()) :: {:ok, binary()} | {:error, binary()}
  def gunzip(file) do
    case run("gunzip", ["-k", file], stderr_to_stdout: true) do
      {_out, 0} -> {:ok, String.replace_suffix(file, ".gz", "")}
      {err, _} -> {:error, String.trim(err)}
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # Single-file compression (zstd, xz, bzip2)
  # ═══════════════════════════════════════════════════════════════════════

  @type single_algo :: :zstd | :xz | :bzip2 | :gzip

  @doc """
  Compresses a single file with the specified algorithm.
  Replaces the original with the compressed version.
  """
  @spec compress(binary(), single_algo()) :: {:ok, binary()} | {:error, binary()}
  def compress(file, :zstd) do
    case run("zstd", [file, "--rm"], stderr_to_stdout: true) do
      {_out, 0} -> {:ok, file <> ".zst"}
      {err, _} -> {:error, String.trim(err)}
    end
  end

  def compress(file, :xz) do
    case run("xz", [file], stderr_to_stdout: true) do
      {_out, 0} -> {:ok, file <> ".xz"}
      {err, _} -> {:error, String.trim(err)}
    end
  end

  def compress(file, :bzip2) do
    case run("bzip2", [file], stderr_to_stdout: true) do
      {_out, 0} -> {:ok, file <> ".bz2"}
      {err, _} -> {:error, String.trim(err)}
    end
  end

  def compress(file, :gzip), do: gzip(file)
  def compress(_file, algo), do: {:error, "Unsupported algorithm: #{algo}"}

  @doc """
  Decompresses a single file. Algorithm auto-detected from extension.
  """
  @spec decompress(binary(), single_algo()) :: {:ok, binary()} | {:error, binary()}
  def decompress(file, :zstd) do
    case run("zstd", ["-d", file, "--rm"], stderr_to_stdout: true) do
      {_out, 0} -> {:ok, String.replace_suffix(file, ".zst", "")}
      {err, _} -> {:error, String.trim(err)}
    end
  end

  def decompress(file, :xz) do
    case run("xz", ["-d", file], stderr_to_stdout: true) do
      {_out, 0} -> {:ok, String.replace_suffix(file, ".xz", "")}
      {err, _} -> {:error, String.trim(err)}
    end
  end

  def decompress(file, :bzip2) do
    case run("bzip2", ["-d", file], stderr_to_stdout: true) do
      {_out, 0} -> {:ok, String.replace_suffix(file, ".bz2", "")}
      {err, _} -> {:error, String.trim(err)}
    end
  end

  def decompress(file, :gzip), do: gunzip(file)
  def decompress(_file, algo), do: {:error, "Unsupported algorithm: #{algo}"}

  # ═══════════════════════════════════════════════════════════════════════
  # 7-Zip
  # ═══════════════════════════════════════════════════════════════════════

  @doc """
  Extracts a 7z archive.

  > ⚠️ **Security**: The password is passed via `-p` on the command line
  > and is visible in the process list (`ps aux`). The `7z` tool supports
  > reading passwords from stdin (`-p` with no value), but Arrea's
  > current pipeline does not support stdin. See
  > [Arrea#stdin](https://github.com/Lorenzo-SF/arrea) for future support.
  """
  @spec extract_7z(binary(), keyword()) :: {:ok, binary()} | {:error, binary()}
  def extract_7z(file, opts \\ []) do
    output = Keyword.get(opts, :output, ".")
    password = Keyword.get(opts, :password)

    args = ["x", "-o#{output}", "-y", file]
    args = if password, do: args ++ ["-p#{password}"], else: args

    case run("7z", args, stderr_to_stdout: true) do
      {_out, 0} -> {:ok, output}
      {err, _} -> {:error, String.trim(err)}
    end
  end

  @doc """
  Creates a 7z archive from source paths.

  > ⚠️ **Security**: The password is passed via `-p` on the command line
  > and is visible in the process list (`ps aux`). Consider using
  > encrypted volumes or key-based protection for sensitive data.
  """
  @spec create_7z(binary(), [binary()], keyword()) :: {:ok, binary()} | {:error, binary()}
  def create_7z(output, files, opts \\ []) do
    cd = Keyword.get(opts, :cd, ".")
    password = Keyword.get(opts, :password)

    args = ["a", output, "-y"] ++ files
    args = if password, do: args ++ ["-p#{password}"], else: args

    case run("7z", args, cd: cd, stderr_to_stdout: true) do
      {_out, 0} -> {:ok, output}
      {err, _} -> {:error, String.trim(err)}
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # RAR
  # ═══════════════════════════════════════════════════════════════════════

  @doc "Extracts a RAR archive."
  @spec extract_rar(binary(), keyword()) :: {:ok, binary()} | {:error, binary()}
  def extract_rar(file, opts \\ []) do
    output = Keyword.get(opts, :output, ".")

    case run("unrar", ["x", "-y", file, output], stderr_to_stdout: true) do
      {_out, 0} -> {:ok, output}
      {err, _} -> {:error, String.trim(err)}
    end
  end

  @doc "Creates a RAR archive from source paths."
  @spec create_rar(binary(), [binary()], keyword()) :: {:ok, binary()} | {:error, binary()}
  def create_rar(output, files, _opts \\ []) do
    case run("rar", ["a", output] ++ files, stderr_to_stdout: true) do
      {_out, 0} -> {:ok, output}
      {err, _} -> {:error, String.trim(err)}
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # List contents
  # ═══════════════════════════════════════════════════════════════════════

  @doc """
  Lists the contents of an archive. Auto-detects format.

  Returns a list of file name strings.
  """
  @spec list(binary()) :: {:ok, [binary()]} | {:error, binary()}
  def list(file) do
    {cmd, args} = list_cmd_args(file)

    case run(cmd, args, stderr_to_stdout: true) do
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

  # ═══════════════════════════════════════════════════════════════════════
  # Private helpers
  # ═══════════════════════════════════════════════════════════════════════

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

  # Routes a single tool invocation through Util.run_cmd_legacy which
  # gives real timeout cancellation, telemetry, and structured errors.
  # Returns the legacy {output, exit_code} tuple so the {_, 0} -> ...;
  # {_, _} -> ... case patterns above stay readable. On Arrea failure
  # (timeout, missing binary) returns {"", 1}.
  defp run(cmd, args, opts) do
    Util.run_cmd_legacy(cmd, args, opts)
  end
end
