defmodule Trebejo.Application do
  @moduledoc """
  OTP application entry point for Trebejo.

  Currently no supervision tree is needed — Trebejo modules are stateless
  wrappers around shell commands. The application starts only to satisfy
  OTP requirements.
  """

  use Application

  @impl true
  def start(_type, _args) do
    children = []
    opts = [strategy: :one_for_one, name: Trebejo.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
