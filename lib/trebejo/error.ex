defmodule Trebejo.Error do
  @moduledoc """
  Typed error wrapper for Trebejo command failures.

  Wraps the raw `{:error, reason}` from `Arrea.Command` (or any other
  source) into a `%Trebejo.Error{}` struct so callers can pattern-match
  on a single error type without inspecting raw exit codes or stderr
  strings.

  ## Fields

    * `:kind` — atom describing the failure category (see `kind/0`).
    * `:exit_status` — integer exit code reported by the process, when
      available. `nil` for non-process errors (timeout, port crash).
    * `:cmd` — command line that was attempted (string).
    * `:stderr` — captured stderr (or merged output) for diagnostics,
      trimmed. `nil` if not captured.
    * `:reason` — raw underlying reason (atom, tuple, or string).
    * `:duration_ms` — wall-clock time spent before the error, in ms.
      Useful to distinguish a 31s timeout from a 30s+1ms timeout.

  ## Kind taxonomy

  | kind               | when                                                          |
  |--------------------|---------------------------------------------------------------|
  | `:not_found`       | exit 127 — command not found                                  |
  | `:permission_denied` | exit 126 — binary exists but not executable                |
  | `:invalid_args`    | exit 2/64/65 — bad arguments / syntax error                  |
  | `:timeout`         | command exceeded the configured timeout                      |
  | `:signal`          | process killed by a signal (e.g. SIGTERM → 137)               |
  | `:exit_nonzero`    | non-zero exit status that doesn't map to a more specific kind |
  | `:port_closed`     | the streaming port closed before EOF                          |
  | `:circuit_open`    | the call was rejected by `Arrea.CircuitBreaker`               |
  | `:rate_limited`    | the call was rejected by `Arrea.RateLimiter`                  |
  | `:bulkhead_full`   | the call was rejected by `Arrea.Bulkhead`                     |
  | `:unknown`         | fallback for anything that does not match the taxonomy above  |
  """

  @type kind ::
          :not_found
          | :permission_denied
          | :invalid_args
          | :timeout
          | :signal
          | :exit_nonzero
          | :port_closed
          | :circuit_open
          | :rate_limited
          | :bulkhead_full
          | :unknown

  @type t :: %__MODULE__{
          kind: kind(),
          exit_status: non_neg_integer() | nil,
          cmd: String.t() | nil,
          stderr: String.t() | nil,
          reason: term(),
          duration_ms: non_neg_integer() | nil
        }

  defstruct [:kind, :exit_status, :cmd, :stderr, :reason, :duration_ms]

  @doc """
  Build a `%Trebejo.Error{}` from an exit code, stderr and command line.

  ## Examples

      iex> Trebejo.Error.from_exit(127, "", "nonexistent")
      %Trebejo.Error{kind: :not_found, exit_status: 127, ...}

      iex> Trebejo.Error.from_exit(126, "perm denied", "./bin")
      %Trebejo.Error{kind: :permission_denied, exit_status: 126, ...}
  """
  @spec from_exit(non_neg_integer(), String.t(), String.t() | nil, keyword()) :: t()
  def from_exit(exit_status, stderr, cmd, opts \\ []) do
    %__MODULE__{
      kind: classify_exit(exit_status),
      exit_status: exit_status,
      cmd: cmd,
      stderr: trim(stderr),
      reason: Keyword.get(opts, :reason, exit_status),
      duration_ms: Keyword.get(opts, :duration_ms)
    }
  end

  @doc """
  Wrap a raw `{:error, reason}` from `Arrea.Command` (or any executor).

  Recognises `:timeout` and passes through Arrea-side reasons as-is.
  """
  @spec wrap(term(), keyword()) :: t()
  def wrap(reason, opts) do
    duration_ms = Keyword.get(opts, :duration_ms)
    cmd = Keyword.get(opts, :cmd)
    {kind, exit_status, stderr} = classify_reason(reason)

    %__MODULE__{
      kind: kind,
      exit_status: exit_status,
      cmd: cmd,
      stderr: stderr,
      reason: reason,
      duration_ms: duration_ms
    }
  end

  # Each clause maps one recognised failure shape to its kind/exit/stderr.
  # Pulling these out keeps `wrap/2` simple and lets `classify_reason/1`
  # be tested in isolation.
  @spec classify_reason(term()) :: {kind(), non_neg_integer() | nil, String.t() | nil}
  defp classify_reason(:timeout), do: {:timeout, nil, nil}
  defp classify_reason({:exit_status, code, err}) when is_integer(code), do: {classify_exit(code), code, err}
  defp classify_reason({:exit_status, code}) when is_integer(code), do: {classify_exit(code), code, nil}
  defp classify_reason({:port_closed, _}), do: {:port_closed, nil, nil}
  defp classify_reason({:blocked, :circuit_open}), do: {:circuit_open, nil, nil}
  defp classify_reason({:error, :rate_limited}), do: {:rate_limited, nil, nil}
  defp classify_reason({:error, :bulkhead_full}), do: {:bulkhead_full, nil, nil}
  defp classify_reason(code) when is_integer(code), do: {classify_exit(code), code, nil}
  defp classify_reason(other), do: {:unknown, nil, inspect(other)}

  @doc """
  Render the error as a one-line, human-readable string.
  """
  @spec message(t()) :: String.t()
  def message(%__MODULE__{} = err) do
    parts =
      ["Trebejo:" <> Atom.to_string(err.kind)]
      |> append_part("exit=#{err.exit_status}", err.exit_status != nil)
      |> append_part("cmd=#{err.cmd}", err.cmd not in [nil, ""])
      |> append_part("duration=#{err.duration_ms}ms", err.duration_ms != nil)

    Enum.join(parts, " ")
  end

  @doc """
  Classify a Unix exit code into a `kind/0`.
  """
  @spec classify_exit(non_neg_integer()) :: kind()
  def classify_exit(0), do: :unknown
  def classify_exit(127), do: :not_found
  def classify_exit(126), do: :permission_denied
  def classify_exit(2), do: :invalid_args
  def classify_exit(64), do: :invalid_args
  def classify_exit(65), do: :invalid_args
  def classify_exit(130), do: :signal
  def classify_exit(137), do: :signal
  def classify_exit(143), do: :signal
  def classify_exit(139), do: :signal
  def classify_exit(_), do: :exit_nonzero

  defp trim(nil), do: nil
  defp trim(""), do: nil
  defp trim(s) when is_binary(s), do: s |> String.trim() |> blank_to_nil()

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(s), do: s

  defp append_part(parts, _part, false), do: parts
  defp append_part(parts, part, true), do: parts ++ [part]
end
