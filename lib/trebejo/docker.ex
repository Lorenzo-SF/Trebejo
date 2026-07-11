defmodule Trebejo.Docker do
  @moduledoc """
  Docker / Podman container lifecycle management.

  Detects the available container runtime (Docker or Podman) and provides
  a unified interface for container and compose operations.

  All command execution is routed through `Arrea.Command.execute/2` with
  `validate: false`. Runtime is auto-detected via
  `Apero.Proc.command_exists?/1`; environment variable `CONTAINER_RUNTIME`
  (`docker` | `podman`) overrides the detection.

  ## Container detection

  Use `runtime/0` to detect the available runtime, or set the
  `CONTAINER_RUNTIME` environment variable to override.
  """

  alias Arrea.Command

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
    case run_cmd(["pull", image]) do
      {_, 0} -> :ok
      {out, _} -> {:error, String.trim(out)}
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # Container lifecycle
  # ═══════════════════════════════════════════════════════════════════════

  @doc """
  Creates and starts a new container.

  ## Options

    * `:image` — required, image to use
    * `:name` — container name (optional, auto-generated if omitted)
    * `:ports` — list of `"host_port:container_port"` strings
    * `:env` — list of `"KEY=VALUE"` strings
    * `:volume` — list of `"host_path:container_path"` strings
    * `:restart` — restart policy (default: `"unless-stopped"`)
    * `:detach` — run in background (default: `true`)
    * `:entrypoint` — custom entrypoint (optional)
    * `:cmd` — list of command args (optional)
  """
  @spec run(keyword()) :: {:ok, container_name} | {:error, String.t()}
  def run(opts) when is_list(opts) do
    image = Keyword.fetch!(opts, :image)
    args = build_run_args(opts, image)

    case run_cmd(args) do
      {out, 0} -> {:ok, String.trim(out)}
      {out, _} -> {:error, String.trim(out)}
    end
  end

  defp build_run_args(opts, image) do
    args = ["run"]

    if Keyword.get(opts, :detach, true), do: args |> push("--detach")
    if name = Keyword.get(opts, :name), do: args |> push("--name", name)

    if restart = Keyword.get(opts, :restart, "unless-stopped"),
      do: args |> push("--restart", restart)

    for p <- Keyword.get(opts, :ports, []), do: args |> push("-p", p)
    for e <- Keyword.get(opts, :env, []), do: args |> push("-e", e)
    for v <- Keyword.get(opts, :volume, []), do: args |> push("-v", v)

    if entrypoint = Keyword.get(opts, :entrypoint) do
      args |> push("--entrypoint", entrypoint)
    end

    args |> push(image)

    if cmd = Keyword.get(opts, :cmd), do: args ++ cmd, else: args
  end

  @doc "Starts an existing container."
  @spec start(container_name) :: :ok | {:error, String.t()}
  def start(container) do
    case run_cmd(["start", container]) do
      {_, 0} -> :ok
      {out, _} -> {:error, String.trim(out)}
    end
  end

  @doc "Stops a running container."
  @spec stop(container_name, pos_integer()) :: :ok | {:error, String.t()}
  def stop(container, timeout \\ 10) do
    case run_cmd(["stop", "--time", to_string(timeout), container]) do
      {_, 0} -> :ok
      {out, _} -> {:error, String.trim(out)}
    end
  end

  @doc "Removes a container."
  @spec rm(container_name, keyword()) :: :ok | {:error, String.t()}
  def rm(container, opts \\ []) do
    args = ["rm"]
    if Keyword.get(opts, :force), do: args |> push("--force")
    if Keyword.get(opts, :volumes), do: args |> push("--volumes")
    args |> push(container)

    case run_cmd(args) do
      {_, 0} -> :ok
      {out, _} -> {:error, String.trim(out)}
    end
  end

  @doc "Executes a command inside a running container."
  @spec exec(container_name, [String.t()], keyword()) :: {:ok, String.t()} | {:error, String.t()}
  def exec(container, cmd, opts \\ []) do
    args = ["exec"]

    if Keyword.get(opts, :interactive, false), do: args |> push("--interactive")
    if user = Keyword.get(opts, :user), do: args |> push("--user", user)
    if workdir = Keyword.get(opts, :workdir), do: args |> push("--workdir", workdir)

    args = args ++ [container | cmd]

    case run_cmd(args) do
      {out, 0} -> {:ok, String.trim(out)}
      {out, _} -> {:error, String.trim(out)}
    end
  end

  @doc "Returns the state of a container: `:running`, `:stopped`, `:missing`, or `{:error, _}`."
  @spec state(container_name) :: :running | :stopped | :missing | {:error, String.t()}
  def state(container) do
    case run_cmd(["inspect", container, "--format", "{{.State.Running}}"]) do
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

    if Keyword.get(opts, :all, false), do: args |> push("--all")
    if filter = Keyword.get(opts, :filter), do: args |> push("--filter", filter)
    if format = Keyword.get(opts, :format), do: args |> push("--format", format)

    case run_cmd(args) do
      {out, 0} -> {:ok, String.trim(out)}
      {out, _} -> {:error, String.trim(out)}
    end
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
    cd = Keyword.get(opts, :cd, ".")

    case compose_cmd_str(["compose", "ps"], cd: cd) do
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
    cd = Keyword.get(opts, :cd, ".")

    case compose_cmd_str(["compose", "exec", service | command], cd: cd) do
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
    cd = Keyword.get(opts, :cd, ".")

    case compose_cmd_str(["compose", command | extra_args], cd: cd) do
      {out, 0} -> {:ok, String.trim(out)}
      {err, _} -> {:error, String.trim(err)}
    end
  end

  defp compose_cmd_str(args, opts) do
    run_cmd_str(runtime(), args, opts)
  end

  # Run a top-level `runtime <args> ...` invocation and normalise the
  # legacy {output, exit_code} tuple into the public {:ok, _} / {:error, _}
  # contract shared by the compose helpers.
  defp raw_cmd(args, opts) do
    case run_cmd_str(runtime(), args, opts) do
      {out, 0} -> {:ok, String.trim(out)}
      {err, _} -> {:error, String.trim(err)}
    end
  end

  defp run_cmd(args) do
    run_cmd_str(runtime(), args, [])
  end

  # Builds a single command string from a runtime binary + argv list,
  # shell-quoting each argument. Routes through Arrea.Command.execute/2
  # which gives real timeout cancellation, telemetry, and structured
  # errors. Returns the legacy {output, exit_code} tuple so the
  # call sites above stay readable; on Arrea failure (timeout, missing
  # binary) returns {"", 1} so the caller falls through to the
  # error branch.
  defp run_cmd_str(runtime, args, opts) do
    quoted = Enum.map(args, &shell_quote/1)
    cmd = [runtime | quoted] |> Enum.join(" ")

    base = [validate: false, stderr_to_stdout: true]
    arity = Keyword.merge(base, opts)

    case Command.execute(cmd, arity) do
      {:ok, %{stdout: out, exit_code: code}} -> {out, code}
      _ -> {"", 1}
    end
  end

  # Single-quote a string for safe inclusion in a POSIX shell command
  # line. Replaces internal single quotes with the standard
  # `'\\''` close-then-reopen pattern. Same approach as Trebejo.Git.Local.
  defp shell_quote(str) when is_binary(str) do
    escaped = String.replace(str, "'", "'\\''")
    "'#{escaped}'"
  end

  defp push(list, value), do: list ++ [value]
  defp push(list, key, value), do: list ++ [key, value]
end
