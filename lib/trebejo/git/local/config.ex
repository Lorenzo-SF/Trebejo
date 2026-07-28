defmodule Trebejo.Git.Local.Config do
  @moduledoc """
  Git configuration operations — reading and writing config values,
  user info, system info and hostname.
  """

  alias Trebejo.Git.Local

  @doc """
  Gets a Git configuration value (local → global → system).

  Accepts an optional `cd:` option to scope the lookup to a specific
  repository directory.
  """
  @spec config(binary(), keyword()) :: binary()
  def config(attr, opts \\ []) do
    case Local.run_git(["config", "--get", attr], opts) do
      {:ok, %{exit_code: 0, stdout: output}} -> String.trim(output)
      _ -> ""
    end
  end

  @doc """
  Gets a Git configuration value from the global scope.

  Accepts an optional `cd:` option (kept for signature parity with
  `config/2`; ignored at the global scope).
  """
  @spec config_global(binary(), keyword()) :: binary()
  def config_global(attr, _opts \\ []) do
    case Local.run_git(["config", "--global", "--get", attr]) do
      {:ok, %{exit_code: 0, stdout: output}} -> String.trim(output)
      _ -> ""
    end
  end

  @doc """
  Gets a Git configuration value from the local (repo) scope.

  Accepts an optional `cd:` option to scope the lookup to a specific
  repository directory.
  """
  @spec config_local(binary(), keyword()) :: binary()
  def config_local(attr, opts \\ []) do
    case Local.run_git(["config", "--local", "--get", attr], opts) do
      {:ok, %{exit_code: 0, stdout: output}} -> String.trim(output)
      _ -> ""
    end
  end

  @doc """
  Returns a map with the current Git user information.

  Falls back to system user information if Git is not configured.
  """
  @spec get_user_info() :: map()
  def get_user_info do
    %{
      name: get_git_user_name() || get_system_user_name(),
      email: get_git_user_email() || get_system_user_email(),
      hostname: get_hostname()
    }
  end

  @doc """
  Sets Git user name, email, and URL rewrite rules globally.
  """
  @spec set_user_info(binary(), binary()) :: :ok | {:error, binary()}
  def set_user_info(name, email) do
    cmds = [
      ["config", "--global", "user.name", name],
      ["config", "--global", "user.email", email],
      ["config", "--global", "url.git@github.com:.insteadOf", "https://github.com/"],
      ["config", "--global", "url.git@gitlab.com:.insteadOf", "https://gitlab.com/"],
      ["config", "--global", "pull.rebase", "false"]
    ]

    Enum.reduce_while(cmds, :ok, fn args, _acc ->
      case Local.run_git(args) do
        {:ok, %{exit_code: 0}} -> {:cont, :ok}
        {:ok, %{stdout: out}} -> {:halt, {:error, String.trim(out)}}
        {:error, reason} -> {:halt, {:error, inspect(reason)}}
      end
    end)
  end

  @doc """
  Returns the configured Git user name, or `nil` if not set.
  """
  @spec get_git_user_name() :: binary() | nil
  def get_git_user_name do
    case Local.run_git(["config", "user.name"]) do
      {:ok, %{exit_code: 0, stdout: output}} ->
        trimmed = String.trim(output)

        if trimmed == "",
          do: nil,
          else:
            trimmed
            |> String.split()
            |> Enum.map_join(" ", &String.capitalize/1)

      _ ->
        nil
    end
  end

  @doc """
  Returns the configured Git user email, or `nil` if not set.
  """
  @spec get_git_user_email() :: binary() | nil
  def get_git_user_email do
    case Local.run_git(["config", "user.email"]) do
      {:ok, %{exit_code: 0, stdout: output}} ->
        trimmed = String.trim(output)
        if trimmed == "", do: nil, else: trimmed

      _ ->
        nil
    end
  end

  @doc """
  Returns the current system user name.
  """
  @spec get_system_user_name() :: binary()
  def get_system_user_name do
    case :os.type() do
      {:unix, _} ->
        (System.get_env("USER") || System.get_env("LOGNAME") || "")
        |> String.trim()
        |> String.split()
        |> Enum.map_join(" ", &String.capitalize/1)

      {:win32, _} ->
        (System.get_env("USERNAME") || "")
        |> String.trim()
        |> String.split()
        |> Enum.map_join(" ", &String.capitalize/1)
    end
  end

  @doc """
  Returns the current system user email from the `USER_EMAIL` env variable,
  falling back to `"user@domain.com"`.
  """
  @spec get_system_user_email() :: binary()
  def get_system_user_email do
    System.get_env("USER_EMAIL") || "user@domain.com"
  end

  @doc """
  Returns the machine's hostname.
  """
  @dialyzer {:nowarn_function, get_hostname: 0}
  @spec get_hostname() :: binary()
  def get_hostname do
    case :inet.gethostname() do
      {:ok, name} -> to_string(name)
      _ -> "localhost"
    end
  end
end
