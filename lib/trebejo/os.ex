defmodule Trebejo.OS do
  alias Trebejo.Util

  @moduledoc """
  Operating system information utilities (shell-based).

  Provides shell-dependent system metadata queries: architecture, kernel
  version, CPU count, memory, and root check. For pure OS detection
  (type, hostname, distro, WSL, container) use `Apero.OS` directly.

  All command execution is routed through `Arrea.Command.execute/2`
  with `validate: false`.
  """

  @type os_type :: :linux | :macos | :windows | :unknown
  @type arch :: :x86_64 | :arm64 | :arm | :i386 | :unknown

  @doc """
  Returns the CPU architecture of the current machine.

  Possible values: `:x86_64`, `:arm64`, `:arm`, `:i386`, `:unknown`.
  """
  @spec arch() :: arch()
  def arch do
    System.get_env("PROCESSOR_ARCHITECTURE") || uname_m() |> parse_arch()
  end

  defp parse_arch("x86_64"), do: :x86_64
  defp parse_arch("amd64"), do: :x86_64
  defp parse_arch("arm64"), do: :arm64
  defp parse_arch("aarch64"), do: :arm64
  defp parse_arch("armv7l"), do: :arm
  defp parse_arch("i386"), do: :i386
  defp parse_arch("i686"), do: :i386
  defp parse_arch(_), do: :unknown

  @doc """
  Returns the OS kernel version string, or `"unknown"` if unavailable.
  """
  @spec kernel_version() :: binary()
  def kernel_version do
    case :os.type() do
      {:unix, _} ->
        case run_cmd("uname -r") do
          {out, 0} -> String.trim(out)
          _ -> "unknown"
        end

      {:win32, _} ->
        case run_cmd("cmd /c ver") do
          {out, 0} -> String.trim(out)
          _ -> "unknown"
        end
    end
  end

  @doc """
  Returns a consolidated map of system information.

  For pure-Elixir fields (type, hostname, distro) call `Apero.OS`
  directly. Keys: `:arch`, `:kernel_version`, `:cpu_count`,
  `:total_memory_mb`.
  """
  @spec info() :: map()
  def info do
    %{
      arch: arch(),
      kernel_version: kernel_version(),
      cpu_count: cpu_count(),
      total_memory_mb: total_memory_mb()
    }
  end

  @doc """
  Returns the number of logical CPU cores available to the OS.
  """
  @spec cpu_count() :: pos_integer()
  def cpu_count do
    # LC_ALL=C so nproc / sysctl output is locale-stable on Spanish/French
    # hosts (where default locale would otherwise corrupt numeric parsing).
    env = %{"LC_ALL" => "C"}

    case :os.type() do
      {:unix, :linux} ->
        case run_cmd("nproc", env: env) do
          {out, 0} -> parse_integer(out, System.schedulers_online())
          _ -> System.schedulers_online()
        end

      {:unix, :darwin} ->
        case run_cmd("sysctl -n hw.logicalcpu", env: env) do
          {out, 0} -> parse_integer(out, System.schedulers_online())
          _ -> System.schedulers_online()
        end

      _ ->
        System.schedulers_online()
    end
  end

  @doc """
  Returns the total system RAM in megabytes, or `0` if unavailable.
  """
  @spec total_memory_mb() :: non_neg_integer()
  def total_memory_mb do
    case :os.type() do
      {:unix, :linux} -> read_meminfo()
      {:unix, :darwin} -> read_macos_memory()
      _ -> 0
    end
  end

  @doc """
  Returns `true` if the current process is running as root / Administrator.
  """
  @spec root?() :: boolean()
  def root? do
    case :os.type() do
      {:unix, _} ->
        case run_cmd("id -u") do
          {output, 0} -> String.trim(output) == "0"
          _ -> false
        end

      {:win32, _} ->
        case run_cmd("net session") do
          {_, 0} -> true
          _ -> false
        end
    end
  end

  defp uname_m do
    case run_cmd("uname -m") do
      {out, 0} -> String.trim(out)
      _ -> ""
    end
  end

  defp read_meminfo do
    case File.read("/proc/meminfo") do
      {:ok, content} ->
        content
        |> String.split("\n", trim: true)
        |> Enum.find_value(&find_mem_total/1) || 0

      _ ->
        0
    end
  end

  defp read_macos_memory do
    case run_cmd("sysctl -n hw.memsize", env: %{"LC_ALL" => "C"}) do
      {out, 0} ->
        out |> String.trim() |> parse_integer(0) |> div(1_024 * 1_024)

      _ ->
        0
    end
  end

  defp parse_integer(str, default) do
    case Integer.parse(String.trim(str)) do
      {n, _} -> n
      :error -> default
    end
  end

  defp find_mem_total(line) do
    case Regex.run(~r/^MemTotal:\s+(\d+)\s+kB/, line) do
      [_, kb] -> div(String.to_integer(kb), 1_024)
      _ -> nil
    end
  end

  # Splits a command string into binary name + args and runs via
  # Util.run_cmd_legacy. Returns {output, exit_code}. On Arrea
  # failure returns {"", 1}.
  @spec run_cmd(String.t(), keyword()) :: {String.t(), non_neg_integer()}
  defp run_cmd(cmd, opts \\ []) do
    [bin | rest] = String.split(cmd)
    Util.run_cmd_legacy(bin, rest, opts)
  end
end
