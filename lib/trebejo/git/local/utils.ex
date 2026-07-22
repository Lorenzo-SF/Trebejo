defmodule Trebejo.Git.Local.Utils do
  @moduledoc """
  Utility functions for Git operations — command execution, shell quoting,
  CLI availability checks, and credential setup.
  """

  alias Arrea.Command
  alias Trebejo.Util

  @doc """
  Runs a git command with options.

  Builds a shell-quoted command line from `git_args` and dispatches it via
  `run_system_cmd/3`.
  """
  @spec run_git([binary()], keyword()) :: {:ok, map()} | {:error, any()}
  def run_git(git_args, opts \\ []) do
    cmd_line =
      ["git" | Enum.map(git_args, &shell_quote/1)]
      |> Enum.map_join(" ", & &1)

    extra =
      if(cd = opts[:cd], do: [cd: cd], else: []) ++
        if(t = opts[:timeout], do: [timeout: t], else: [])

    forwarded = Keyword.drop(opts, [:cd, :timeout])
    run_system_cmd("git", cmd_line, Keyword.merge(extra, forwarded))
  end

  @doc """
  Runs a system command with telemetry instrumentation.

  Emits `[:apero, :git, :command, :start|:stop|:error]` telemetry events.
  """
  @spec run_system_cmd(binary(), binary(), keyword()) :: {:ok, map()} | {:error, any()}
  def run_system_cmd(_cmd, telemetry_cmd_line, opts) do
    start = System.monotonic_time()

    :telemetry.execute([:apero, :git, :command, :start], %{}, %{
      args: telemetry_cmd_line
    })

    base_opts = [validate: false, stderr_to_stdout: true]
    full_opts = Keyword.merge(base_opts, opts)

    result =
      case Command.execute(telemetry_cmd_line, full_opts) do
        {:ok, %{stdout: out, exit_code: code}} -> {:ok, %{stdout: out, exit_code: code}}
        {:error, reason} -> {:error, reason}
      end

    duration = System.monotonic_time() - start

    case result do
      {:ok, _} ->
        :telemetry.execute([:apero, :git, :command, :stop], %{duration: duration}, %{
          args: telemetry_cmd_line
        })

      {:error, reason} ->
        :telemetry.execute([:apero, :git, :command, :error], %{duration: duration}, %{
          args: telemetry_cmd_line,
          reason: inspect(reason)
        })
    end

    result
  end

  @doc """
  Quotes a binary string for safe shell use.
  """
  @spec shell_quote(binary()) :: binary()
  def shell_quote(str) when is_binary(str), do: Util.shell_quote(str)

  @doc """
  Builds git options for a repository path and optional timeout.
  """
  @spec build_git_opts(binary(), integer() | nil) :: keyword()
  def build_git_opts(repo_path, nil), do: [cd: repo_path]
  def build_git_opts(repo_path, timeout), do: [cd: repo_path, timeout: timeout]

  @doc """
  Checks if `gh` is available.
  """
  @spec gh_available?() :: boolean()
  def gh_available?, do: System.find_executable("gh") != nil

  @doc """
  Checks if `glab` is available.
  """
  @spec glab_available?() :: boolean()
  def glab_available?, do: System.find_executable("glab") != nil

  @doc """
  Checks if a repository has uncommitted changes.
  """
  @spec has_uncommitted_changes?(binary()) :: boolean()
  def has_uncommitted_changes?(repo_path) do
    case run_git(["status", "--porcelain"], cd: repo_path) do
      {:ok, %{exit_code: 0, stdout: output}} -> String.trim(output) != ""
      _ -> false
    end
  end

  @doc """
  Configures Git credentials (SSH key path or credential helper).
  """
  @spec setup_credentials(keyword()) :: :ok | {:error, binary()}
  def setup_credentials(opts \\ []) do
    ssh_key = Keyword.get(opts, :ssh_key)
    credential_helper = Keyword.get(opts, :credential_helper, "cache")

    if ssh_key do
      setup_ssh_key(ssh_key)
    else
      setup_credential_helper(credential_helper)
    end
  end

  @doc """
  Sets up an SSH key for git.
  """
  @spec setup_ssh_key(binary()) :: :ok | {:error, binary()}
  def setup_ssh_key(ssh_key) do
    if File.exists?(ssh_key) do
      safe_ssh_cmd = "ssh -i '#{ssh_key}'"

      case run_git(["config", "--global", "core.sshCommand", safe_ssh_cmd]) do
        {:ok, %{exit_code: 0}} -> :ok
        {:ok, %{stdout: err}} -> {:error, String.trim(err)}
        {:error, reason} -> {:error, inspect(reason)}
      end
    else
      {:error, "SSH key not found: #{ssh_key}"}
    end
  end

  @doc """
  Sets up a credential helper for git.
  """
  @spec setup_credential_helper(binary()) :: :ok | {:error, binary()}
  def setup_credential_helper(credential_helper) do
    case run_git(["config", "--global", "credential.helper", credential_helper]) do
      {:ok, %{exit_code: 0}} -> :ok
      {:ok, %{stdout: err}} -> {:error, String.trim(err)}
      {:error, reason} -> {:error, inspect(reason)}
    end
  end
end
