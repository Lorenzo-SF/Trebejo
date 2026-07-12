defmodule Trebejo.Docker do
  @moduledoc """
  Docker / Podman container lifecycle management.

  Detects the available container runtime (Docker or Podman) and provides
  a unified interface for container and compose operations.

  All command execution is routed through `Trebejo.SafeCommand.execute/3`
  with arg lists — never interpolated into shell strings — to prevent
  shell injection. Runtime is auto-detected via
  `Apero.Proc.command_exists?/1`; environment variable `CONTAINER_RUNTIME`
  (`docker` | `podman`) overrides the detection.
  """

  alias Trebejo.Util

  @type runtime :: :docker | :podman
  @type container_name :: String.t()
  @type image :: String.t()

  # ═══════════════════════════════════════════════════════════════════════
  # Runtime detection
  # ═══════════════════════════════════════════════════════════════════════

  @doc "Detects the available container runtime."
  @spec runtime() :: runtime() | :none
  def runtime do
    env = System.get_env("CONTAINER_RUNTIME")

    cond do
      env == "podman" -> :podman
      env == "docker" -> :docker
      Apero.Proc.command_exists?("podman") -> :podman
      Apero.Proc.command_exists?("docker") -> :docker
      true -> :none
    end
  end

  @doc "Returns the runtime binary name as a string."
  @spec runtime_binary() :: String.t()
  def runtime_binary do
    case runtime() do
      :docker -> "docker"
      :podman -> "podman"
      :none -> "docker"
    end
  end

  @doc "Returns true if running inside a container."
  @spec in_container?() :: boolean()
  def in_container? do
    Apero.OS.container?()
  end

  # ═══════════════════════════════════════════════════════════════════════
  # Image operations
  # ═══════════════════════════════════════════════════════════════════════

  @doc "Pulls a Docker image."
  @spec pull(image) :: :ok | {:error, String.t()}
  def pull(image) when is_binary(image) do
    run_cmd_ok(["pull", image])
  end

  # ═══════════════════════════════════════════════════════════════════════
  # Container lifecycle
  # ═══════════════════════════════════════════════════════════════════════

  @doc """
  Creates and starts a new container.
  """
  @spec run(keyword()) :: {:ok, container_name} | {:error, String.t()}
  def run(opts) when is_list(opts) do
    image = Keyword.fetch!(opts, :image)
    args = build_run_args(opts, image)

    run_cmd_out(args)
  end

  defp build_run_args(opts, image) do
    args = ["run"]

    args = if Keyword.get(opts, :detach, true), do: args ++ ["--detach"], else: args
    args = if name = Keyword.get(opts, :name), do: args ++ ["--name", name], else: args

    args =
      if restart = Keyword.get(opts, :restart, "unless-stopped"),
        do: args ++ ["--restart", restart],
        else: args

    args = Enum.reduce(Keyword.get(opts, :ports, []), args, fn p, acc -> acc ++ ["-p", p] end)
    args = Enum.reduce(Keyword.get(opts, :env, []), args, fn e, acc -> acc ++ ["-e", e] end)
    args = Enum.reduce(Keyword.get(opts, :volume, []), args, fn v, acc -> acc ++ ["-v", v] end)

    args =
      if entrypoint = Keyword.get(opts, :entrypoint) do
        args ++ ["--entrypoint", entrypoint]
      else
        args
      end

    args = args ++ [image]

    if cmd = Keyword.get(opts, :cmd), do: args ++ cmd, else: args
  end

  @doc "Starts an existing container."
  @spec start(container_name) :: :ok | {:error, String.t()}
  def start(container) do
    run_cmd_ok(["start", container])
  end

  @doc "Stops a running container."
  @spec stop(container_name, pos_integer()) :: :ok | {:error, String.t()}
  def stop(container, timeout \\ 10) do
    run_cmd_ok(["stop", "--time", to_string(timeout), container])
  end

  @doc "Removes a container."
  @spec rm(container_name, keyword()) :: :ok | {:error, String.t()}
  def rm(container, opts \\ []) do
    args = ["rm"]
    args = if Keyword.get(opts, :force), do: args ++ ["--force"], else: args
    args = if Keyword.get(opts, :volumes), do: args ++ ["--volumes"], else: args
    args = args ++ [container]

    run_cmd_ok(args)
  end

  @doc "Executes a command inside a running container."
  @spec exec(container_name, [String.t()], keyword()) :: {:ok, String.t()} | {:error, String.t()}
  def exec(container, cmd, opts \\ []) do
    args = ["exec"]

    args = if Keyword.get(opts, :interactive, false), do: args ++ ["--interactive"], else: args
    args = if user = Keyword.get(opts, :user), do: args ++ ["--user", user], else: args
    args = if workdir = Keyword.get(opts, :workdir), do: args ++ ["--workdir", workdir], else: args
    args = args ++ [container | cmd]

    run_cmd_out(args)
  end

  @doc "Returns the state of a container."
  @spec state(container_name) :: :running | :stopped | :missing | {:error, String.t()}
  def state(container) do
    case Util.run_cmd_legacy(runtime_binary(), ["inspect", container, "--format", "{{.State.Running}}"]) do
      {"true\n", 0} -> :running
      {"false\n", 0} -> :stopped
      {_, 0} -> :missing
      {_, _} -> :missing
    end
  end

  @doc "Lists running containers."
  @spec ps(keyword()) :: {:ok, String.t()} | {:error, String.t()}
  def ps(opts \\ []) do
    args = ["ps"]

    args = if Keyword.get(opts, :all, false), do: args ++ ["--all"], else: args
    args = if filter = Keyword.get(opts, :filter), do: args ++ ["--filter", filter], else: args
    args = if format = Keyword.get(opts, :format), do: args ++ ["--format", format], else: args

    run_cmd_out(args)
  end

  # ═══════════════════════════════════════════════════════════════════════
  # Compose operations
  # ═══════════════════════════════════════════════════════════════════════

  @doc "Starts services defined in docker-compose.yml."
  @spec compose_up(keyword()) :: {:ok, binary()} | {:error, binary()}
  def compose_up(opts \\ []), do: compose("up", ["-d"], opts)

  @doc "Stops and removes services."
  @spec compose_down(keyword()) :: {:ok, binary()} | {:error, binary()}
  def compose_down(opts \\ []), do: compose("down", [], opts)

  @doc "Restarts services."
  @spec compose_restart(keyword()) :: {:ok, binary()} | {:error, binary()}
  def compose_restart(opts \\ []), do: compose("restart", [], opts)

  @doc "Pulls images for compose services."
  @spec compose_pull(keyword()) :: {:ok, binary()} | {:error, binary()}
  def compose_pull(opts \\ []), do: compose("pull", [], opts)

  @doc "Builds images."
  @spec compose_build(keyword()) :: {:ok, binary()} | {:error, binary()}
  def compose_build(opts \\ []), do: compose("build", [], opts)

  @doc "Lists running compose services."
  @spec compose_ps(keyword()) :: {:ok, binary()} | {:error, binary()}
  def compose_ps(opts \\ []) do
    case Util.run_cmd_legacy(runtime_binary(), ["compose", "ps", "|", Keyword.get(opts, :cd, ".")]) do
      {out, 0} -> {:ok, String.trim(out)}
      {err, _} -> {:error, String.trim(err)}
    end
  end

  @doc "Shows logs for compose services."
  @spec compose_logs(keyword()) :: {:ok, binary()} | {:error, binary()}
  def compose_logs(opts \\ []), do: compose("logs", ["-f"], opts)

  @doc "Executes a command in a compose service container."
  @spec compose_exec(binary(), [binary()], keyword()) :: {:ok, binary()} | {:error, binary()}
  def compose_exec(service, command, opts \\ []) do
    case Util.run_cmd_legacy(runtime_binary(), ["compose", "exec", service | command], cd: Keyword.get(opts, :cd, ".")) do
      {out, 0} -> {:ok, String.trim(out)}
      {err, _} -> {:error, String.trim(err)}
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # Volume operations
  # ═══════════════════════════════════════════════════════════════════════

  @doc "Creates a volume."
  @spec volume_create(binary(), keyword()) :: {:ok, binary()} | {:error, binary()}
  def volume_create(name, opts \\ []), do: raw_cmd(["volume", "create", name], opts)

  @doc "Lists volumes."
  @spec volume_list(keyword()) :: {:ok, binary()} | {:error, binary()}
  def volume_list(opts \\ []), do: raw_cmd(["volume", "ls"], opts)

  @doc "Removes a volume."
  @spec volume_remove(binary(), keyword()) :: {:ok, binary()} | {:error, binary()}
  def volume_remove(name, opts \\ []), do: raw_cmd(["volume", "rm", name], opts)

  # ═══════════════════════════════════════════════════════════════════════
  # Network operations
  # ═══════════════════════════════════════════════════════════════════════

  @doc "Creates a network."
  @spec network_create(binary(), keyword()) :: {:ok, binary()} | {:error, binary()}
  def network_create(name, opts \\ []), do: raw_cmd(["network", "create", name], opts)

  @doc "Lists networks."
  @spec network_list(keyword()) :: {:ok, binary()} | {:error, binary()}
  def network_list(opts \\ []), do: raw_cmd(["network", "ls"], opts)

  @doc "Removes a network."
  @spec network_remove(binary(), keyword()) :: {:ok, binary()} | {:error, binary()}
  def network_remove(name, opts \\ []), do: raw_cmd(["network", "rm", name], opts)

  # ═══════════════════════════════════════════════════════════════════════
  # Private
  # ═══════════════════════════════════════════════════════════════════════

  defp compose(command, extra_args, opts) do
    case Util.run_cmd_legacy(runtime_binary(), ["compose", command | extra_args], cd: Keyword.get(opts, :cd, ".")) do
      {out, 0} -> {:ok, String.trim(out)}
      {err, _} -> {:error, String.trim(err)}
    end
  end

  defp raw_cmd(args, opts) do
    case Util.run_cmd_legacy(runtime_binary(), args, opts) do
      {out, 0} -> {:ok, String.trim(out)}
      {err, _} -> {:error, String.trim(err)}
    end
  end

  # Run a command through SafeCommand, return :ok or {:error, trimmed_output}
  defp run_cmd_ok(args) do
    case Util.run_cmd_legacy(runtime_binary(), args) do
      {_, 0} -> :ok
      {out, _} -> {:error, String.trim(out)}
    end
  end

  # Run a command through SafeCommand, return {:ok, trimmed_output} or {:error, trimmed_output}
  defp run_cmd_out(args) do
    case Util.run_cmd_legacy(runtime_binary(), args) do
      {out, 0} -> {:ok, String.trim(out)}
      {out, _} -> {:error, String.trim(out)}
    end
  end
end
