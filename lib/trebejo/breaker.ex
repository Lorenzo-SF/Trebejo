defmodule Trebejo.Breaker do
  @moduledoc """
  Circuit-breaker integration for Trebejo commands.

  Wraps any `Trebejo` command execution in `Arrea.CircuitBreaker.call/3`
  so that a flaky dependency (e.g. a remote SSH host, a slow docker
  daemon) trips the breaker after a few failures and the rest of your
  pipeline fails fast instead of piling up requests.

  ## Usage

  Wrap an arbitrary command:

      Trebejo.Breaker.with_breaker(:ssh_prod, fn ->
        Trebejo.Runner.run("ssh", ["prod-1", "systemctl restart nginx"])
      end)

  Or pass `breaker: name` to a wrapper:

      Trebejo.Docker.ps(breaker: :docker_local)

  ## Telemetry

  Emits standard `[:arrea, :circuit_breaker, ...]` events. See
  `Arrea.Telemetry.Events.circuit_breaker_metadata/0`.

  ## See also

    * `Arrea.CircuitBreaker` — the underlying primitive.
    * `Trebejo.Runner` — the indirection that lets `Trebejo.Mox`
      intercept real commands in tests.
  """

  alias Arrea.CircuitBreaker
  alias Trebejo.Error, as: TrebejoError

  @doc """
  Execute `fun` under the breaker identified by `name`.

  The breaker must have been started elsewhere (typically in your
  application's supervision tree). Returns whatever the wrapped call
  returns, or `{:error, %Trebejo.Error{kind: :circuit_open}}` if the
  breaker is open.

  ## Options

    * `:threshold` — default `3` (passed to the breaker if it has to be
      started lazily).
    * `:timeout` — default `30_000` ms.
    * `:required_successes` — default `1`.

  See `Arrea.CircuitBreaker.start_link/1` for the full set of options.
  """
  @spec with_breaker(atom(), (-> term()), keyword()) :: term()
  def with_breaker(name, fun, opts \\ []) when is_atom(name) and is_function(fun, 0) do
    ensure_breaker(name, opts)

    case CircuitBreaker.call(name, fun) do
      {:ok, value} ->
        value

      {:error, :circuit_open} ->
        {:error, %TrebejoError{kind: :circuit_open, cmd: nil, reason: :circuit_open}}

      {:error, :execution_failed} ->
        {:error, %TrebejoError{kind: :unknown, reason: :execution_failed}}

      {:error, :timeout} ->
        {:error, %TrebejoError{kind: :timeout, reason: :timeout}}
    end
  end

  @doc """
  Notify the breaker of an explicit success.

  Use this when you've already executed the side-effect outside of
  `with_breaker/3` and want the breaker to record a success.
  """
  @spec success(atom()) :: :ok
  def success(name) when is_atom(name), do: CircuitBreaker.success(name)

  @doc """
  Notify the breaker of an explicit failure.

  Use this when you've already executed the side-effect outside of
  `with_breaker/3` and want the breaker to record a failure (which may
  trip it).
  """
  @spec failure(atom()) :: :ok
  def failure(name) when is_atom(name), do: CircuitBreaker.failure(name)

  @doc """
  Read the breaker's current state.

  Returns one of `:closed | :open | :half_open`, or `nil` if no
  breaker is registered under `name`.

  Note: a brand-new `:closed` state for an unstarted breaker is
  indistinguishable from a healthy running breaker. There is no
  way to tell "never started" from "started but no failures yet"
  from the public API of `Arrea.CircuitBreaker`. If you need to know
  whether the breaker exists, call `Arrea.CircuitBreaker.start_link/1`
  with the same name and trap `{:error, {:already_started, _}}`.
  """
  @spec state(atom()) :: :closed | :open | :half_open | nil
  def state(name) when is_atom(name) do
    case CircuitBreaker.get_state(name) do
      :closed -> :closed
      :open -> :open
      :half_open -> :half_open
    end
  end

  # ── Private ─────────────────────────────────────────────────────────────

  # Start the breaker lazily if it isn't already running. We don't link
  # because the caller may be a short-lived task; the supervisor is
  # responsible for keeping it alive long-term.
  @spec ensure_breaker(atom(), keyword()) :: :ok | {:error, term()}
  defp ensure_breaker(name, opts) do
    if breaker_started?(name) do
      :ok
    else
      breaker_opts =
        [
          name: name,
          threshold: Keyword.get(opts, :threshold, 3),
          timeout: Keyword.get(opts, :timeout, 30_000),
          required_successes: Keyword.get(opts, :required_successes, 1)
        ]

      case CircuitBreaker.start_link(breaker_opts) do
        {:ok, _pid} -> :ok
        {:error, {:already_started, _pid}} -> :ok
        {:error, %Arrea.Error{} = err} -> {:error, err}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  # Arrea.CircuitBreaker.get_state/1 returns `:closed` for both
  # "registered and healthy" and "never registered", so we can't use it
  # to tell the two apart. A direct Registry lookup is the only way.
  @spec breaker_started?(atom()) :: boolean()
  defp breaker_started?(name) do
    case Registry.lookup(Arrea.CircuitBreaker.Registry, name) do
      [{_pid, _}] -> true
      [] -> false
    end
  end
end
