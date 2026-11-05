defmodule Trebejo.Postgres do
  @moduledoc """
  PostgreSQL client wrapper around `psql`, `pg_dump`, and `pg_restore`.

  Routes everything through `Trebejo.Util.run_cmd/3` (and therefore
  `Trebejo.Runner`) so it picks up `:timeout`, the circuit breaker, and
  `Trebejo.Mox` mocking automatically.

  All connection parameters are passed via env vars (`PGHOST`, `PGUSER`,
  `PGPASSWORD`, `PGDATABASE`, `PGPORT`) and command-line flags. Passwords
  are never interpolated into shell strings — use the env var or a
  `~/.pgpass` file.

  ## Options (shared)

    * `:host` — `PGHOST`, default `localhost`
    * `:port` — `PGPORT`, default `5432`
    * `:user` — `PGUSER`, default `$USER`
    * `:database` — `PGDATABASE`
    * `:password` — passed as `PGPASSWORD` env var (NOT as `-W`)
    * `:timeout` — passed through to the underlying runner
    * `:breaker` — circuit breaker name (passed to `Trebejo.Breaker.with_breaker/3`)

  ## Examples

      iex> Trebejo.Postgres.execute("SELECT 1", host: "db.internal", database: "app")
      {:ok, "1\\n", 0}

      iex> Trebejo.Postgres.dump("app", file: "/tmp/app.dump", host: "db.internal")
      :ok
  """

  alias Trebejo.Error, as: TrebejoError
  alias Trebejo.Runner

  @default_port 5432

  @doc """
  Run a SQL statement or query via `psql -c`.

  Returns `{:ok, stdout, 0}` on success or `{:error, %Trebejo.Error{}}`.
  """
  @spec execute(String.t(), keyword()) ::
          {:ok, String.t(), 0} | {:error, TrebejoError.t()}
  def execute(sql, opts \\ []) when is_binary(sql) do
    args = ["-c", sql, "--no-psqlrc"] ++ db_args(opts)
    do_run("psql", args, opts)
  end

  @doc """
  Stream a query via `psql` line by line. See `Trebejo.Stream.lines/3`.
  """
  @spec stream(String.t(), keyword()) ::
          {:ok, Enumerable.t()} | {:error, TrebejoError.t()}
  def stream(sql, opts \\ []) when is_binary(sql) do
    args = ["-c", sql, "--no-psqlrc"] ++ db_args(opts)
    Trebejo.Stream.lines("psql", args, merge_opts(opts))
  end

  @doc """
  Dump a database to a file using `pg_dump`.

  If `:format` is `:plain` (default) the file is a SQL script.
  Otherwise it is a custom-format dump suitable for `pg_restore`.
  """
  @spec dump(String.t(), keyword()) :: :ok | {:error, TrebejoError.t()}
  def dump(database, opts) when is_binary(database) do
    file = Keyword.fetch!(opts, :file)
    format = Keyword.get(opts, :format, :plain)

    args =
      ["--no-owner", "--no-privileges"] ++
        format_arg(format) ++
        ["-f", file, database] ++
        db_args(opts)

    case do_run("pg_dump", args, opts) do
      {:ok, _out, 0} -> :ok
      {:error, %TrebejoError{} = err} -> {:error, err}
    end
  end

  @doc """
  Restore a dump produced by `pg_dump` (or `pg_dumpall`).

  Pass `:format: :plain` for SQL dumps and any other value for custom
  dumps.
  """
  @spec restore(String.t(), keyword()) :: :ok | {:error, TrebejoError.t()}
  def restore(database, opts) when is_binary(database) do
    file = Keyword.fetch!(opts, :file)
    format = Keyword.get(opts, :format, :plain)

    args =
      ["--no-owner", "--no-privileges", "-d", database] ++
        format_arg(format) ++
        restore_input_arg(file, format) ++
        db_args(opts)

    case do_run("pg_restore", args, opts) do
      {:ok, _out, 0} -> :ok
      {:error, %TrebejoError{} = err} -> {:error, err}
    end
  end

  # ── Private ─────────────────────────────────────────────────────────────

  @spec format_arg(:plain | :custom | :tar | :directory) :: [String.t()]
  defp format_arg(:plain), do: ["--format=plain"]
  defp format_arg(:custom), do: ["--format=custom"]
  defp format_arg(:tar), do: ["--format=tar"]
  defp format_arg(:directory), do: ["--format=directory"]

  @spec restore_input_arg(String.t(), :plain | :custom | :tar | :directory) :: [String.t()]
  defp restore_input_arg(file, :plain), do: ["-f", file]
  defp restore_input_arg(file, _), do: [file]

  @spec db_args(keyword()) :: [String.t()]
  defp db_args(opts) do
    []
    |> maybe_flag("--host", opts[:host])
    |> maybe_flag("--port", opts[:port] || @default_port)
    |> maybe_flag("--username", opts[:user])
    |> maybe_flag("--dbname", opts[:database])
  end

  defp maybe_flag(args, _flag, nil), do: args
  defp maybe_flag(args, flag, value), do: args ++ [flag, to_string(value)]

  @spec merge_opts(keyword()) :: keyword()
  defp merge_opts(opts) do
    opts
    |> Keyword.drop([:host, :port, :user, :database, :password, :breaker, :file, :format])
    |> maybe_set_env(opts[:password])
  end

  defp maybe_set_env(opts, nil), do: opts
  defp maybe_set_env(opts, pwd), do: opts ++ [env: [{"PGPASSWORD", pwd} | Keyword.get(opts, :env, [])]]

  @spec do_run(String.t(), [String.t()], keyword()) ::
          {:ok, String.t(), 0} | {:error, TrebejoError.t()}
  defp do_run(cmd, args, opts) do
    runner_opts = merge_opts(opts)

    result =
      case opts[:breaker] do
        nil -> Runner.run(cmd, args, runner_opts)
        name -> Trebejo.Breaker.with_breaker(name, fn -> Runner.run(cmd, args, runner_opts) end)
      end

    case result do
      {:ok, out, 0} ->
        {:ok, out, 0}

      {:ok, out, code} ->
        {:error, exit_to_error(out, code, cmd, args)}

      {:error, %TrebejoError{} = err} ->
        {:error, err}

      {:error, reason} ->
        cmd_line = Enum.join([cmd | args], " ")
        {:error, TrebejoError.wrap(reason, cmd: cmd_line)}
    end
  end

  defp exit_to_error(out, code, cmd, args) do
    cmd_line = Enum.join([cmd | args], " ")
    TrebejoError.from_exit(code, out, cmd_line)
  end
end
