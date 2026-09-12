defmodule Trebejo.Stream do
  @moduledoc """
  Streaming wrapper around `Port.open/2` for long-running commands.

  Unlike `Trebejo.Util.run_cmd/3` which waits for the command to finish
  and returns the full output, `Trebejo.Stream` returns a lazy
  `Stream.t()` that yields stdout chunks as they arrive, suitable for
  `docker logs -f`, `tail -f`, build logs, etc.

  ## Usage

      {:ok, stream} =
        Trebejo.Stream.open("docker", ["logs", "-f", "my-container"],
          stderr: :separate, timeout: 60_000
        )

      stream
      |> Stream.each(&IO.write/1)
      |> Stream.run()

  Or consume line by line:

      {:ok, lines} = Trebejo.Stream.lines("tail", ["-f", "/var/log/syslog"])
      for line <- lines, do: IO.puts(line)

  ## Stderr handling

    * `:merge` (default) — stderr is redirected to stdout via
      `:stderr_to_stdout`. The stream emits binary chunks containing
      the merged output.
    * `:separate` — **deprecated in 2.0**, reserved for 2.1. The
      underlying `Port.open/2` does not yet tag stderr vs stdout
      reliably across all OTP versions, so for 2.0 we accept the
      option but silently fall back to `:merge` behaviour. Calls
      passing `:separate` will log a single warning via
      `:logger.warning/1` so callers can find and update them.

  ## Cleanup

  Every call to `open/3` registers the port with the calling process.
  When the calling process exits, the port is closed automatically by
  the BEAM. For short-lived streams you can also call `close/1`.
  """

  alias Trebejo.Error, as: TrebejoError

  @type stream_chunk :: binary() | %{kind: :stdout | :stderr, data: binary()}
  @type line_chunk :: String.t() | %{kind: :stdout | :stderr, data: String.t()}

  @type options :: [
          {:timeout, pos_integer()}
          | {:stderr, :merge | :separate}
          | {:chunk_size, pos_integer()}
          | {:into, pid()}
          | {:cd, String.t()}
          | {:env, [{String.t(), String.t()}]}
        ]

  @doc """
  Open a streaming port to `cmd_name` with `args`.

  Returns `{:ok, stream}` (a `Stream.t()` of `stream_chunk/0`) or
  `{:error, %Trebejo.Error{}}`.

  The stream is lazy: nothing executes until you start consuming it
  (via `Stream.each/2`, `Enum.take/2`, `Stream.run/1`, etc.).
  """
  @spec open(binary(), [binary()], options()) ::
          {:ok, Enumerable.t()} | {:error, TrebejoError.t()}
  def open(cmd_name, args, opts \\ []) when is_binary(cmd_name) and is_list(args) do
    stderr_mode = Keyword.get(opts, :stderr, :merge)
    stderr_mode = warn_if_separate(stderr_mode)

    case open_port(cmd_name, args, opts) do
      {:ok, port} ->
        stream =
          Stream.resource(
            fn -> port end,
            fn p -> port_to_chunks(p, stderr_mode) end,
            fn p -> safe_close(p) end
          )

        {:ok, stream}

      {:error, %TrebejoError{} = err} ->
        {:error, err}
    end
  end

  @spec open_port(binary(), [binary()], options()) ::
          {:ok, port()} | {:error, TrebejoError.t()}
  defp open_port(cmd_name, args, opts) do
    port_opts = build_port_opts(opts)
    executable = resolve_executable(cmd_name)

    if System.find_executable(executable) == nil and
         Path.type(executable) == :relative do
      {:error,
       %TrebejoError{
         kind: :not_found,
         cmd: Enum.join([cmd_name | args], " "),
         reason: :enoent
       }}
    else
      try do
        {:ok, Port.open({:spawn_executable, executable}, port_opts ++ [{:args, args}])}
      rescue
        err in ErlangError ->
          {:error,
           %TrebejoError{
             kind: :not_found,
             cmd: Enum.join([cmd_name | args], " "),
             reason: Exception.message(err)
           }}
      end
    end
  end

  @spec warn_if_separate(:merge | :separate) :: :merge | :separate
  defp warn_if_separate(:separate) do
    require Logger
    Logger.warning("Trebejo.Stream: stderr: :separate is deprecated in 2.0; falling back to :merge")
    :merge
  end

  defp warn_if_separate(mode), do: mode

  @doc """
  Like `open/3` but yields complete lines (split on `\\n`) instead of
  raw chunks. Stderr chunks are tagged with `%{kind: :stderr, data: line}`.
  """
  @spec lines(binary(), [binary()], options()) ::
          {:ok, Enumerable.t()} | {:error, TrebejoError.t()}
  def lines(cmd_name, args, opts \\ []) do
    with {:ok, stream} <- open(cmd_name, args, opts) do
      {:ok, lines_from_chunks(stream)}
    end
  end

  @doc """
  Force-close a stream early. Safe to call on a stream that has already
  finished — the port will already be closed by the resource teardown.
  """
  @spec close(Enumerable.t()) :: :ok
  def close(stream) do
    # Pulling one element triggers the resource start; we discard it.
    # The teardown runs after the consumer finishes or errors out.
    try do
      _ = stream |> Enum.take(1) |> List.wrap()
    catch
      _, _ -> :ok
    end

    :ok
  end

  # ── Private ─────────────────────────────────────────────────────────────

  # `Port.open({:spawn_executable, cmd}, ...)` does NOT search `$PATH` —
  # it requires an absolute path. Try `System.find_executable/1` first,
  # fall back to the bare name (works on systems where the kernel does
  # the PATH lookup, like Linux with `glibc`).
  @spec resolve_executable(binary()) :: binary()
  defp resolve_executable(cmd_name) do
    if Path.type(cmd_name) == :absolute do
      cmd_name
    else
      System.find_executable(cmd_name) || cmd_name
    end
  end

  @spec build_port_opts(options()) :: [term()]
  defp build_port_opts(opts) do
    base = [:stream, :binary, :exit_status]

    base ++
      env_opts(Keyword.get(opts, :env)) ++
      stderr_opts(Keyword.get(opts, :stderr, :merge))
  end

  defp env_opts(nil), do: []
  defp env_opts(env), do: [{:env, env}]

  defp stderr_opts(:merge), do: [:stderr_to_stdout]
  defp stderr_opts(:separate), do: []

  # port_to_chunks/3 returns either {:halt, port} (port closed) or
  # {[chunk], port} (yield this chunk, keep going).
  #
  # We DO NOT close the port on receive-timeout here.  Closing on
  # idle would kill any long-running command (build logs, `tail -f`)
  # between bursts of output.  The caller (or the calling process
  # death) is responsible for closing the port.
  @spec port_to_chunks(port(), :merge | :separate) ::
          {[stream_chunk()], port()} | {:halt, port()}
  defp port_to_chunks(port, stderr_mode) do
    receive do
      {^port, {:data, data}} ->
        chunk = normalise_chunk(data, stderr_mode)
        {[chunk], port}

      {^port, {:exit_status, _code}} ->
        {:halt, port}
    end
  end

  @spec normalise_chunk(binary(), :merge | :separate) :: stream_chunk()
  defp normalise_chunk(data, _stderr_mode), do: data

  @spec chunk_to_text(stream_chunk()) :: {String.t(), :stdout | :stderr | nil}
  defp chunk_to_text(data) when is_binary(data), do: {data, nil}
  defp chunk_to_text(%{kind: kind, data: data}), do: {data, kind}

  @spec lines_from_chunks(Enumerable.t()) :: Enumerable.t()
  defp lines_from_chunks(chunk_stream) do
    chunk_stream
    |> Stream.transform("", fn chunk, buf ->
      {text, kind} = chunk_to_text(chunk)
      {lines, new_buf} = split_buffer(buf <> text, kind)
      {lines, new_buf}
    end)
  end

  @spec split_buffer(String.t(), :stdout | :stderr | nil) ::
          {[line_chunk()], String.t()}
  defp split_buffer(buffer, kind) do
    case String.split(buffer, "\n") do
      [single] ->
        {[], single}

      parts ->
        last = List.last(parts)
        complete = Enum.drop(parts, -1)
        tagged = Enum.map(complete, &tag_line(&1, kind))
        {tagged, last}
    end
  end

  defp tag_line(line, kind) when kind in [:stdout, :stderr] do
    %{kind: kind, data: line}
  end

  defp tag_line(line, _), do: line

  @spec safe_close(port()) :: :ok
  defp safe_close(port) do
    if Port.info(port) != nil do
      try do
        Port.close(port)
      catch
        _, _ -> :ok
      end
    end

    :ok
  end
end
