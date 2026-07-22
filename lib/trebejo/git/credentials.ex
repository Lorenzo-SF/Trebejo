defmodule Trebejo.Git.Credentials do
  @moduledoc """
  Git credential and SSH key configuration helpers.

  Splits out the credential setup helpers from `Trebejo.Git.Local` so
  the local git operations module remains focused on clone/sync/branch
  workflows.

  Not part of the public API — used only by `Trebejo.Git.Local`.

  Note: Uses `System.cmd/3` directly via `Trebejo.Util.run_cmd_legacy/3`
  to avoid a circular dependency with `Trebejo.Git.Local.run_git/1` (which
  is private).
  """

  alias Trebejo.Util

  @doc """
  Configures git's `core.sshCommand` to use the given SSH key path.

  Returns `:ok` on success or `{:error, reason}` if the key doesn't
  exist or git config fails.
  """
  @spec setup_ssh_key(Path.t()) :: :ok | {:error, term()}
  def setup_ssh_key(ssh_key) do
    if File.exists?(ssh_key) do
      safe_ssh_cmd = "ssh -i '#{ssh_key}'"

      case Util.run_cmd_legacy("git", ["config", "--global", "core.sshCommand", safe_ssh_cmd]) do
        {_, 0} -> :ok
        {err, _} -> {:error, String.trim(err)}
      end
    else
      {:error, "SSH key not found: #{ssh_key}"}
    end
  end

  @doc """
  Configures git's `credential.helper` to the given helper string.
  """
  @spec setup_credential_helper(String.t()) :: :ok | {:error, term()}
  def setup_credential_helper(credential_helper) do
    case Util.run_cmd_legacy("git", ["config", "--global", "credential.helper", credential_helper]) do
      {_, 0} -> :ok
      {err, _} -> {:error, String.trim(err)}
    end
  end
end
