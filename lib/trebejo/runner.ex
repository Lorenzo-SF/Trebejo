defmodule Trebejo.Runner do
  @moduledoc """
  Behaviour for executing external commands.

  The default runner is `Trebejo.Util.run_cmd/3` (via `Arrea.Command`).
  Tests can swap in `Trebejo.Mox.Runner` to stub specific calls without
  touching real binaries.

  ## Implementing

      defmodule MyApp.MockRunner do
        @behaviour Trebejo.Runner

        @impl true
        def run(_cmd_name, _args, _opts) do
          {:ok, "mocked output\\n", 0}
        end
      end

  Then set `Trebejo.run_with(MyApp.MockRunner)` in your test setup.

  ## Contract

  `run/3` returns:

    * `{:ok, stdout, exit_code}` on completion
    * `{:error, reason}` on failure (`:timeout`, `:enoent`, ...)

  The runner must be safe to call from any process; it owns the port
  lifecycle.
  """

  @callback run(binary(), [binary()], keyword()) ::
              {:ok, binary(), non_neg_integer()} | {:error, term()}

  @doc """
  Run a command using the active runner.

  The active runner defaults to `Trebejo.Util.Runner` (a thin adapter
  that delegates to `Trebejo.Util.run_cmd/3`). Tests can swap in
  `Trebejo.Mox.Runner` by calling `set_runner/1` in their setup.
  """
  @spec run(binary(), [binary()], keyword()) ::
          {:ok, binary(), non_neg_integer()} | {:error, term()}
  def run(cmd_name, args, opts \\ []) do
    runner().run(cmd_name, args, opts)
  end

  @doc """
  Swap the active runner. Use only in tests.
  """
  @spec set_runner(module()) :: :ok
  def set_runner(module) when is_atom(module) do
    :persistent_term.put({__MODULE__, :runner}, module)
    :ok
  end

  @spec runner() :: module()
  def runner do
    case :persistent_term.get({__MODULE__, :runner}, :unset) do
      :unset -> Trebejo.Util.Runner
      module -> module
    end
  end
end
