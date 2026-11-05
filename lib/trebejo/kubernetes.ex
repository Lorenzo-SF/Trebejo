defmodule Trebejo.Kubernetes do
  @moduledoc """
  Thin wrapper over `kubectl` for common operations.

  All `kubectl` invocations are routed through `Trebejo.Util.run_cmd_legacy/3`
  with arg lists — never interpolated into shell strings — to prevent
  shell injection.

  For richer Kubernetes integration (CRUD, watchers, label selectors)
  consider using `:k8s` or the official client libraries.
  """

  alias Trebejo.Util

  @doc """
  Checks if `kubectl` is available and the cluster responds.
  """
  @spec available?() :: boolean()
  def available? do
    case run(["cluster-info"]) do
      {_, 0} -> true
      _ -> false
    end
  end

  @doc """
  Lists the pods in a namespace.

  Returns `{:ok, output}` or `{:error, reason}`.
  """
  @spec pods(String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def pods(namespace, opts \\ []) do
    output = Keyword.get(opts, :output, "json")

    case run(["get", "pods", "-n", namespace, "-o", output]) do
      {out, 0} -> {:ok, out}
      {out, code} -> {:error, {:pods_failed, code, out}}
    end
  end

  @doc """
  Applies a Kubernetes manifest YAML.
  """
  @spec apply(String.t(), keyword()) :: :ok | {:error, term()}
  def apply(manifest_path, _opts \\ []) do
    case run(["apply", "-f", manifest_path]) do
      {_, 0} -> :ok
      {output, code} -> {:error, {:apply_failed, code, output}}
    end
  end

  @doc """
  Deletes a Kubernetes resource by name and kind.
  """
  @spec delete(String.t(), String.t(), String.t(), keyword()) :: :ok | {:error, term()}
  def delete(kind, name, namespace, _opts \\ []) do
    case run(["delete", kind, name, "-n", namespace]) do
      {_, 0} -> :ok
      {output, code} -> {:error, {:delete_failed, code, output}}
    end
  end

  # Routes kubectl through Util.run_cmd_legacy which gives real timeout
  # cancellation, telemetry, and structured errors. On Arrea failure
  # (timeout, missing binary) returns {"", 1}.
  defp run(args) do
    Util.run_cmd_legacy("kubectl", args)
  end
end
