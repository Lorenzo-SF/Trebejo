defmodule Trebejo.Packages do
  @moduledoc """
  Package installation and querying — via `Arrea.Command`.

  For package manager detection use `Apero.Packages` directly.
  All command execution is routed through `Arrea.Command.execute/2`
  giving real timeout cancellation, telemetry, and structured errors.

  ## Usage

      # Install packages using the preferred manager:
      Trebejo.Packages.install("nodejs")

      # Install using a specific manager:
      Trebejo.Packages.install(:apt, ["nodejs", "npm"])

      # Check if installed:
      Trebejo.Packages.installed?(:brew, "node")
  """

  alias Arrea.Command

  @type manager ::
          :apt | :apt_get | :brew | :pacman | :yum | :dnf | :apk | :zypper | :pkg | :winget | :choco | :port | :nix
  @type package :: String.t()

  @doc """
  Installs one or more packages using the specified manager.

  Returns `:ok` on success, `{:error, reason}` on failure.
  """
  @spec install(manager, [package] | package, keyword()) :: :ok | {:error, String.t()}
  def install(manager, packages, opts \\ [])

  def install(:apt, packages, opts) do
    sudo = if Keyword.get(opts, :sudo, true), do: "sudo ", else: ""
    quiet = if Keyword.get(opts, :quiet, true), do: " -qq", else: ""
    run_cmd("#{sudo}apt-get#{quiet} install -y #{Enum.join(List.wrap(packages), " ")}")
  end

  def install(:apt_get, packages, opts), do: install(:apt, packages, opts)

  def install(:brew, packages, opts) do
    quiet = if Keyword.get(opts, :quiet, true), do: " -q", else: ""
    run_cmd("brew#{quiet} install #{Enum.join(List.wrap(packages), " ")}")
  end

  def install(:pacman, packages, opts) do
    quiet = if Keyword.get(opts, :quiet, true), do: " --noconfirm", else: ""
    run_cmd("sudo pacman -S#{quiet} #{Enum.join(List.wrap(packages), " ")}")
  end

  def install(:dnf, packages, opts) do
    quiet = if Keyword.get(opts, :quiet, true), do: " -q", else: ""
    run_cmd("sudo dnf#{quiet} install -y #{Enum.join(List.wrap(packages), " ")}")
  end

  def install(:yum, packages, opts) do
    quiet = if Keyword.get(opts, :quiet, true), do: " -q", else: ""
    run_cmd("sudo yum#{quiet} install -y #{Enum.join(List.wrap(packages), " ")}")
  end

  def install(:zypper, packages, opts) do
    quiet = if Keyword.get(opts, :quiet, true), do: " -q", else: ""
    run_cmd("sudo zypper#{quiet} install -y #{Enum.join(List.wrap(packages), " ")}")
  end

  def install(:apk, packages, opts) do
    quiet = if Keyword.get(opts, :quiet, true), do: " -q", else: ""
    run_cmd("sudo apk add#{quiet} #{Enum.join(List.wrap(packages), " ")}")
  end

  def install(:pkg, packages, opts) do
    quiet = if Keyword.get(opts, :quiet, true), do: " -q", else: ""
    run_cmd("sudo pkg install#{quiet} -y #{Enum.join(List.wrap(packages), " ")}")
  end

  def install(:winget, packages, opts) do
    quiet = if Keyword.get(opts, :quiet, true), do: " --silent", else: ""
    run_cmd("winget install#{quiet} #{Enum.join(List.wrap(packages), " ")}")
  end

  def install(:choco, packages, opts) do
    quiet = if Keyword.get(opts, :quiet, true), do: " -y", else: ""
    run_cmd("choco install#{quiet} #{Enum.join(List.wrap(packages), " ")}")
  end

  def install(:port, packages, opts) do
    quiet = if Keyword.get(opts, :quiet, true), do: " -q", else: ""
    run_cmd("sudo port install#{quiet} #{Enum.join(List.wrap(packages), " ")}")
  end

  def install(:nix, packages, _opts) do
    run_cmd("nix-env -iA nixpkgs.#{Enum.join(List.wrap(packages), " nixpkgs.")}")
  end

  @doc """
  Installs packages using the preferred (auto-detected) package manager.
  """
  @spec install([package] | package) :: :ok | {:error, String.t()}
  def install(packages) when is_binary(packages) or is_list(packages) do
    case Apero.Packages.preferred() do
      nil -> {:error, "no package manager detected"}
      mgr -> install(mgr, packages)
    end
  end

  @doc """
  Checks if a package is installed via the given manager.

  Returns `true`, `false`, or `{:error, reason}`.
  """
  @spec installed?(manager, package) :: boolean | {:error, String.t()}
  def installed?(manager, package)

  def installed?(:apt, package) do
    case Command.execute("dpkg -l #{package}", validate: false) do
      {:ok, %{exit_code: 0, stdout: out}} -> String.contains?(out, "ii  #{package}")
      _ -> false
    end
  end

  def installed?(:apt_get, package), do: installed?(:apt, package)

  def installed?(:brew, package) do
    case Command.execute("brew list #{package}", validate: false) do
      {:ok, %{exit_code: 0}} -> true
      _ -> false
    end
  end

  def installed?(:pacman, package) do
    case Command.execute("pacman -Qi #{package}", validate: false) do
      {:ok, %{exit_code: 0}} -> true
      _ -> false
    end
  end

  def installed?(:dnf, package) do
    case Command.execute("rpm -q #{package}", validate: false) do
      {:ok, %{exit_code: 0}} -> true
      _ -> false
    end
  end

  def installed?(:yum, package), do: installed?(:dnf, package)

  def installed?(_manager, _package), do: false

  @doc """
  Convenience: checks if a package is installed using the preferred manager.
  """
  @spec installed?(package) :: boolean | {:error, String.t()}
  def installed?(package) when is_binary(package) do
    case Apero.Packages.preferred() do
      nil -> false
      mgr -> installed?(mgr, package)
    end
  end

  # ── Helpers ──────────────────────────────────────────────────────────

  defp run_cmd(cmd) do
    case Command.execute(cmd, validate: false, stderr_to_stdout: true) do
      {:ok, %{exit_code: 0}} -> :ok
      {:ok, %{stdout: out}} -> {:error, String.trim(out)}
      {:error, reason} -> {:error, inspect(reason)}
    end
  end
end
