defmodule Trebejo.Mox do
  @moduledoc """
  Test-only mocking layer for Trebejo command execution.

  Lets you stub `Trebejo.Util.run_cmd/3` (and downstream wrappers)
  without spinning up real binaries. Unlike `Mox`, this is **explicit**:
  you stub a specific `(cmd_name, args)` pair, not a behaviour. The
  tradeoff is simplicity — no `expect/3` count tracking, no
  `verify_on_exit!`.

  ## Usage

  In a test:

      use ExUnit.Case, async: false
      import Trebejo.Mox

      setup do
        stub_cmd("echo", ["hello"], {:ok, "hello\\n", 0})
        stub_cmd("git", ["status"], {:ok, "", 0})
        :ok
      end

      test "wraps echo in docker" do
        {:ok, out, 0} = Trebejo.Util.run_cmd("echo", ["hello"])
        assert out =~ "hello"
      end

  `stub_cmd/3` is order-specific by default (the args list must match
  exactly). For `git`-style wrappers that build args dynamically, use
  `stub_cmd_pattern/2` with a regex on the joined command line.

  ## Cleanup

  Stubs live in a process named `Trebejo.Mox.Server`. The agent is
  started automatically on first stub and reset by `reset_stubs/0`.
  Tests using `stub_cmd/3` should call `reset_stubs/0` in `setup` if
  they run with `async: true`.
  """

  @doc """
  Stub a specific `(cmd_name, args) → result` triple.

  `result` must be a `{:ok, stdout, exit_code}` or `{:error, term()}`
  tuple. Anything else is ignored by the runner.
  """
  @spec stub_cmd(binary(), [binary()], {:ok, binary(), non_neg_integer()} | {:error, term()}) ::
          :ok
  def stub_cmd(cmd_name, args, result) when is_binary(cmd_name) and is_list(args) do
    key = {cmd_name, args}
    Agent.update(server(), &Map.put(&1, key, result))
    :ok
  end

  @doc """
  Stub any call whose joined command line matches `regex`. Useful for
  commands whose args are built dynamically and vary by call site.

      stub_cmd_pattern(~r/^docker compose ps/, {:ok, "myapp\\n", 0})
  """
  @spec stub_cmd_pattern(Regex.t(), {:ok, binary(), non_neg_integer()} | {:error, term()}) ::
          :ok
  def stub_cmd_pattern(regex, result) when is_struct(regex, Regex) do
    Agent.update(server(), &Map.put(&1, {:pattern, regex.source}, {:pattern, regex, result}))
    :ok
  end

  @doc """
  Wipe all stubs. Call in `setup` to keep tests isolated.
  """
  @spec reset_stubs() :: :ok
  def reset_stubs do
    Agent.update(server(), fn _ -> %{} end)
    :ok
  end

  @doc """
  Look up a stub for the given call. Returns the result tuple or `:miss`.

  Internal — used by `Trebejo.Mox.Runner`.
  """
  @spec lookup(binary(), [binary()]) ::
          {:ok, binary(), non_neg_integer()}
          | {:error, term()}
          | {:pattern, Regex.t(), {:ok, binary(), non_neg_integer()} | {:error, term()}}
          | :miss
  def lookup(cmd_name, args) do
    exact_key = {cmd_name, args}

    Agent.get(server(), fn st ->
      case Map.get(st, exact_key) do
        nil -> find_pattern(st, cmd_name, args)
        result -> result
      end
    end)
  end

  # Walk the stub map looking for a regex pattern that matches the
  # joined command line. Pulled out of `lookup/2` so neither function
  # exceeds the nesting limit (max depth = 2).
  @spec find_pattern(map(), binary(), [binary()]) :: term()
  defp find_pattern(stubs, cmd_name, args) do
    Enum.find_value(stubs, :miss, fn entry -> try_pattern_match(entry, cmd_name, args) end)
  end

  @spec try_pattern_match({term(), term()}, binary(), [binary()]) ::
          {:pattern, Regex.t(), term()} | false
  defp try_pattern_match({{:pattern, _source}, {:pattern, regex, result}}, cmd_name, args) do
    cmd_line = Enum.join([cmd_name | args], " ")

    if Regex.match?(regex, cmd_line) do
      {:pattern, regex, result}
    else
      false
    end
  end

  defp try_pattern_match(_other, _cmd_name, _args), do: false

  @doc false
  @spec server() :: pid()
  def server do
    case Process.whereis(__MODULE__.Server) do
      nil -> start_server()
      pid -> pid
    end
  end

  defp start_server do
    {:ok, pid} = Agent.start_link(fn -> %{} end, name: __MODULE__.Server)
    pid
  end

  defmodule Runner do
    @moduledoc false
    @behaviour Trebejo.Runner

    @impl true
    def run(cmd_name, args, _opts) do
      case Trebejo.Mox.lookup(cmd_name, args) do
        {:ok, _, _} = ok ->
          ok

        {:error, _} = err ->
          err

        {:pattern, _regex, result} ->
          result

        :miss ->
          {:error, :no_stub_for_command}
      end
    end
  end
end
