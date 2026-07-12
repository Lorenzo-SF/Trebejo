defmodule Trebejo.Network do
  @moduledoc """
  Network operations: TCP port checks and ICMP ping.

  TCP operations (`port_open?/3`, `scan_ports/3`) use `:gen_tcp` directly.
  ICMP ping uses `Trebejo.Util.run_cmd/3` with arg lists — never
  interpolated into shell strings — to prevent shell injection.
  For DNS resolution use `Apero.Network.resolve/1` directly.
  """

  alias Trebejo.Util

  @type tcp_port :: 0..65_535

  @doc """
  Sends ICMP ping to a host.

  Returns `:ok` on success or `{:error, reason}` on failure.

  ## Options

    * `:count` — number of echo requests (default: 3)
    * `:timeout` — timeout in ms (default: 5_000)
  """
  @spec ping(String.t(), keyword()) :: :ok | {:error, term()}
  def ping(host, opts \\ []) do
    count = Keyword.get(opts, :count, 3)
    timeout = Keyword.get(opts, :timeout, 5_000)

    case Util.run_cmd("ping", ["-c", to_string(count), "-W", to_string(div(timeout, 1000)), host]) do
      {:ok, _out, 0} -> :ok
      {:ok, out, code} -> {:error, {:ping_failed, code, out}}
      {:error, reason} -> {:error, {:ping_failed, -1, reason}}
    end
  end

  @doc """
  Checks if a TCP port is open on a host.

  ## Options

    * `:timeout` — connection timeout in ms (default: 5_000)
  """
  @spec port_open?(String.t(), tcp_port(), keyword()) :: boolean()
  def port_open?(host, port, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 5_000)

    case :gen_tcp.connect(
           String.to_charlist(host),
           port,
           [:binary, active: false, packet: 0],
           timeout
         ) do
      {:ok, socket} ->
        :gen_tcp.close(socket)
        true

      {:error, _} ->
        false
    end
  end

  @doc """
  Scans a list of TCP ports on a host.

  Returns a map of port → `:open | :closed`.
  """
  @spec scan_ports(String.t(), [tcp_port()], keyword()) :: %{tcp_port() => :open | :closed}
  def scan_ports(host, ports, opts \\ []) do
    Enum.into(ports, %{}, fn port ->
      {port, if(port_open?(host, port, opts), do: :open, else: :closed)}
    end)
  end
end
