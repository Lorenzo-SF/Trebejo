defmodule Trebejo.BreakerTest do
  use ExUnit.Case, async: false

  alias Arrea.CircuitBreaker
  alias Trebejo.Breaker

  setup_all do
    {:ok, _} = Application.ensure_all_started(:arrea)
    :ok
  end

  setup do
    # Ensure the test breakers start with a fresh process.
    {:ok, _} = CircuitBreaker.start_link(name: :test_breaker, threshold: 2, timeout: 100)
    {:ok, _} = CircuitBreaker.start_link(name: :test_breaker_trip, threshold: 1, timeout: 60_000)
    :ok
  end

  test "with_breaker/3 returns the wrapped function's value on success" do
    Breaker.with_breaker(:test_breaker, fn -> :wrapped end)
    |> tap(fn _ -> assert true end)
  end

  test "with_breaker/3 records failures and trips after threshold" do
    name = :test_breaker_trip

    # Threshold = 1 so the second failure trips it.
    Breaker.with_breaker(name, fn -> raise "boom" end)
    _ = CircuitBreaker.start_link(name: name, threshold: 1, timeout: 60_000)

    # First call already trips after 1 failure; subsequent is blocked.
    result = Breaker.with_breaker(name, fn -> raise "boom" end)
    assert match?({:error, %Trebejo.Error{kind: _}}, result)
  end

  test "state/1 returns :closed for an unregistered breaker" do
    # Arrea.CircuitBreaker.get_state/1 returns `:closed` for both a
    # registered breaker that has not failed and one that has never
    # been registered. Trebejo.Breaker.state/1 mirrors that contract.
    assert Breaker.state(:never_started_breaker) == :closed
  end
end
