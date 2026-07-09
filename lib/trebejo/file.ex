defmodule Trebejo.File do
  @moduledoc """
  File system watching backed by `Apero.File.Watcher` and `Arrea.WorkerSupervisor`.

  These operations were moved from `Apero.File` (v2.x) to `Trebejo.File` (v1.x)
  because they depend on `Arrea.WorkerSupervisor` for process supervision.
  The pure file operations remain in `Apero.File` with no Arrea dependency.

  ## Example

      iex> {:ok, _pid} = Trebejo.File.watch(["/tmp"], fn events ->
      ...>   IO.inspect(events, label: "changed")
      ...> end, debounce_ms: 50)
  """

  @doc """
  Starts watching `dirs` for file system changes.

  Calls `callback` with a list of `{path, events}` tuples after each
  debounce window.

  ## Options

    * `:debounce_ms` — debounce delay in ms (default: `100`)
    * `:name` — optional name for the watcher process

  Returns `{:ok, pid}`.
  """
  @spec watch([binary()], ([{binary(), [atom()]}] -> any()), keyword()) ::
          {:ok, pid()} | {:error, term()}
  def watch(dirs, callback, opts \\ []) when is_list(dirs) and is_function(callback, 1) do
    watcher_opts = %{
      dirs: dirs,
      callback: callback,
      debounce_ms: Keyword.get(opts, :debounce_ms, 100),
      name: Keyword.get(opts, :name)
    }

    child_spec = {Apero.File.Watcher, watcher_opts}

    case DynamicSupervisor.start_child(Arrea.WorkerSupervisor, child_spec) do
      {:ok, pid} -> {:ok, pid}
      {:ok, pid, _info} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
      :ignore -> {:error, :ignore}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Stops a file watcher by PID.
  """
  @spec unwatch(pid()) :: :ok
  def unwatch(pid) when is_pid(pid) do
    GenServer.stop(pid, :normal)
    :ok
  end
end
