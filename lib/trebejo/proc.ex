defmodule Trebejo.Proc do
  # credo:disable-for-this-file Credo.Check.Refactor.CyclomaticComplexity
  @moduledoc """
  Process and executable utilities (shell-based operations).

  Shell-dependent operations: process listing, signalling, lsof, fuser,
  and log access. For command availability and VM introspection use
  `Apero.Proc` directly.

  All command execution is routed through `Trebejo.Util` with arg lists
  — never interpolated into shell strings — to prevent shell injection.
  """

  alias Trebejo.Util

  # ── Shell-based operations ───────────────────────────────────────────

  @doc "Lists running processes (cross-platform via `ps`)."
  @spec ps(keyword()) :: {:ok, [map()]} | {:error, String.t()}
  def ps(opts \\ []) do
    case Apero.OS.type() do
      :linux -> ps_linux(opts)
      :macos -> ps_macos(opts)
      :windows -> ps_windows(opts)
      _ -> {:error, :unsupported_os}
    end
  end

  @doc "Sends a signal to a process by PID."
  @spec kill(non_neg_integer(), atom()) :: :ok | {:error, term()}
  def kill(pid, signal \\ :term) do
    sig = signal_to_int(signal)

    case Apero.OS.type() do
      os when os in [:linux, :macos] ->
        case Util.run_cmd_legacy("kill", ["-#{sig}", to_string(pid)]) do
          {_, 0} -> :ok
          {_, _} -> {:error, "kill signal #{sig} for pid #{pid} failed"}
        end

      :windows ->
        case Util.run_cmd_legacy("taskkill", ["/PID", to_string(pid), "/F"]) do
          {_, 0} -> :ok
          {_, _} -> {:error, "taskkill for pid #{pid} failed"}
        end

      _ ->
        {:error, :unsupported_os}
    end
  end

  @doc "Lists files opened by a process (lsof wrapper). Linux/macOS only."
  @spec lsof(non_neg_integer()) :: {:ok, [String.t()]} | {:error, term()}
  def lsof(pid) do
    case Util.run_cmd_legacy("lsof", ["-p", to_string(pid)]) do
      {output, 0} ->
        lines = output |> String.split("\n") |> Enum.drop(1) |> Enum.reject(&(&1 == ""))
        {:ok, lines}

      {output, _} ->
        {:error, output}
    end
  end

  @doc "Lists processes using a specific file or port (fuser wrapper)."
  @spec fuser(String.t()) :: {:ok, [non_neg_integer()]} | {:error, term()}
  def fuser(target) do
    case Util.run_cmd_legacy("fuser", [target]) do
      {output, 0} ->
        {:ok, parse_fuser_pids(output)}

      {output, _} ->
        {:error, output}
    end
  end

  @doc "Shows recent logs for a process via journalctl (Linux systemd) or log (macOS)."
  @spec logs(String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def logs(service, opts \\ []) do
    lines = Keyword.get(opts, :lines, 50)

    case Apero.OS.type() do
      :linux ->
        case Util.run_cmd_legacy("journalctl", ["-u", service, "-n", to_string(lines), "--no-pager"]) do
          {out, 0} -> {:ok, String.trim(out)}
          {out, _} -> {:error, String.trim(out)}
        end

      :macos ->
        with {:ok, s} <- validate_service_name(service) do
          case Util.run_cmd_legacy("log", ["show", "--predicate", "process == '#{s}'", "--last", "#{lines}m"]) do
            {out, 0} -> {:ok, String.trim(out)}
            {out, _} -> {:error, String.trim(out)}
          end
        end

      _ ->
        {:error, :unsupported_os}
    end
  end

  # ── Private ──────────────────────────────────────────────────────────

  defp validate_service_name(name) when is_binary(name) do
    if Regex.match?(~r/\A[\w.\-\/]+\z/, name) do
      {:ok, name}
    else
      {:error, "invalid service name"}
    end
  end

  defp validate_service_name(_), do: {:error, "invalid service name"}

  defp ps_linux(_opts) do
    case Util.run_cmd_legacy("ps", ["-eo", "pid,ppid,user,%cpu,%mem,comm", "--no-headers"]) do
      {output, 0} -> {:ok, parse_ps_output(output)}
      {output, _} -> {:error, output}
    end
  end

  defp ps_macos(_opts) do
    case Util.run_cmd_legacy("ps", ["-eo", "pid,ppid,user,%cpu,%mem,comm", "-r"]) do
      {output, 0} -> {:ok, parse_ps_output(output)}
      {output, _} -> {:error, output}
    end
  end

  defp ps_windows(_opts) do
    case Util.run_cmd_legacy("tasklist", ["/FO", "CSV", "/NH"]) do
      {output, 0} -> {:ok, parse_tasklist(output)}
      {output, _} -> {:error, output}
    end
  end

  defp parse_ps_output(output) do
    output
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.flat_map(fn line ->
      parts = String.split(line, ~r/\s+/, parts: 6)

      with {pid, ""} <- Integer.parse(Enum.at(parts, 0) || ""),
           {ppid, ""} <- Integer.parse(Enum.at(parts, 1) || ""),
           {cpu, ""} <- Float.parse(Enum.at(parts, 3) || ""),
           {mem, ""} <- Float.parse(Enum.at(parts, 4) || "") do
        [
          %{
            pid: pid,
            ppid: ppid,
            user: Enum.at(parts, 2) || "",
            cpu: cpu,
            mem: mem,
            command: Enum.at(parts, 5) || ""
          }
        ]
      else
        _ -> []
      end
    end)
  end

  defp parse_tasklist(output) do
    output
    |> String.split("\n")
    |> Enum.map(&String.trim(&1, "\""))
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(fn line ->
      [name, pid, _session, _session_num, mem] = String.split(line, "\",\"")

      %{
        pid: String.to_integer(pid),
        mem: mem,
        command: String.trim(name, "\"")
      }
    end)
  end

  defp parse_fuser_pids(output) do
    output
    |> String.split()
    |> Enum.flat_map(fn token ->
      case Integer.parse(token) do
        {n, ""} -> [n]
        _ -> []
      end
    end)
  end

  defp signal_to_int(:term), do: 15
  defp signal_to_int(:kill), do: 9
  defp signal_to_int(:hup), do: 1
  defp signal_to_int(:int), do: 2
  defp signal_to_int(:quit), do: 3
  defp signal_to_int(:usr1), do: 10
  defp signal_to_int(:usr2), do: 12
  defp signal_to_int(:stop), do: 19
  defp signal_to_int(:cont), do: 18
  defp signal_to_int(other) when is_integer(other), do: other
end
