defmodule Trebejo.Redis do
  @moduledoc """
  Redis client wrapper around `redis-cli`.

  Routes everything through `Trebejo.Util.run_cmd/3` (via
  `Trebejo.Runner`) so it picks up `:timeout`, the circuit breaker, and
  `Trebejo.Mox` mocking automatically.

  Designed for ad-hoc shell-friendly operations (info, ping, config
  tweaks, monitoring) rather than a high-throughput data path. For
  production workloads consider `:redix` or `:eredis` directly.

  ## Options (shared)

    * `:host` — `-h`, default `127.0.0.1`
    * `:port` — `-p`, default `6379`
    * `:password` — `-a`, passed via the CLI flag (NOT as an env var;
      see `:auth` for the env-var alternative)
    * `:auth` — `[:env]` uses `REDISCLI_AUTH` env var instead of `-a`
    * `:database` — `-n`, default `0`
    * `:tls` — `--tls` if `true`
    * `:timeout` — passed through to the underlying runner
    * `:breaker` — circuit breaker name

  ## Examples

      iex> Trebejo.Redis.run(["PING"])
      {:ok, "PONG\\n", 0}

      iex> Trebejo.Redis.run(["INFO", "server"], host: "redis.internal", port: 6380)
      {:ok, "# Server\\n...", 0}
  """

  alias Trebejo.Error, as: TrebejoError
  alias Trebejo.Runner

  @default_port 6379
  @default_database 0

  @doc """
  Run a redis-cli command given as a list of args.

  Returns `{:ok, stdout, 0}` on success or
  `{:error, %Trebejo.Error{}}` on failure (non-zero exit, missing
  binary, timeout, breaker open).
  """
  @spec run([String.t()], keyword()) ::
          {:ok, String.t(), 0} | {:error, TrebejoError.t()}
  def run(args, opts \\ []) when is_list(args) do
    cli_args = base_args(opts) ++ args

    runner_opts =
      opts
      |> Keyword.drop([:host, :port, :password, :auth, :database, :tls, :breaker])
      |> maybe_set_env(opts)

    result =
      case opts[:breaker] do
        nil -> Runner.run("redis-cli", cli_args, runner_opts)
        name -> Trebejo.Breaker.with_breaker(name, fn -> Runner.run("redis-cli", cli_args, runner_opts) end)
      end

    case result do
      {:ok, out, 0} ->
        {:ok, out, 0}

      {:ok, out, code} ->
        {:error, exit_to_error(out, code, cli_args)}

      {:error, %TrebejoError{} = err} ->
        {:error, err}

      {:error, reason} ->
        cmd_line = Enum.join(["redis-cli" | cli_args], " ")
        {:error, TrebejoError.wrap(reason, cmd: cmd_line)}
    end
  end

  @doc """
  Shortcut for `PING`. Returns `true` if the server responds `PONG`.
  """
  @spec ping?(keyword()) :: boolean()
  def ping?(opts \\ []) do
    case run(["PING"], opts) do
      {:ok, out, 0} -> String.trim(out) == "PONG"
      _ -> false
    end
  end

  @doc """
  Stream a long-running `MONITOR` session. Returns a
  `Trebejo.Stream.lines/3` enumerable of events.
  """
  @spec monitor(keyword()) :: {:ok, Enumerable.t()} | {:error, TrebejoError.t()}
  def monitor(opts \\ []) do
    Trebejo.Stream.lines("redis-cli", base_args(opts) ++ ["MONITOR"], opts)
  end

  # ── Private ─────────────────────────────────────────────────────────────

  @spec base_args(keyword()) :: [String.t()]
  defp base_args(opts) do
    []
    |> maybe_flag("-h", opts[:host] || "127.0.0.1")
    |> maybe_flag("-p", opts[:port] || @default_port)
    |> maybe_flag("-n", opts[:database] || @default_database)
    |> maybe_password(opts)
    |> maybe_flag("--tls", opts[:tls])
  end

  defp maybe_flag(args, _flag, nil), do: args
  defp maybe_flag(args, _flag, false), do: args
  defp maybe_flag(args, flag, true), do: args ++ [flag]
  defp maybe_flag(args, flag, value), do: args ++ [flag, to_string(value)]

  defp maybe_password(args, opts) do
    case {Keyword.get(opts, :auth), opts[:password]} do
      {:env, _} -> args ++ ["--no-auth-warning"]
      {_, nil} -> args
      {_, pwd} -> args ++ ["-a", pwd]
    end
  end

  @spec maybe_set_env(keyword(), keyword()) :: keyword()
  defp maybe_set_env(opts, source_opts) do
    if Keyword.get(source_opts, :auth) == :env do
      Keyword.put(opts, :env, [{"REDISCLI_AUTH", source_opts[:password] || ""}])
    else
      opts
    end
  end

  @spec exit_to_error(String.t(), non_neg_integer(), [String.t()]) :: TrebejoError.t()
  defp exit_to_error(out, code, args) do
    cmd_line = Enum.join(["redis-cli" | args], " ")
    TrebejoError.from_exit(code, out, cmd_line)
  end
end
