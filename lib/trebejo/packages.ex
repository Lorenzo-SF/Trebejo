defmodule Trebejo.Packages do
  @moduledoc """
  Package installation and querying — via `Arrea.Command`.

  For package manager detection use `Apero.Packages` directly.
  All command execution is routed through `Trebejo.Util` with arg lists
  — never interpolated into shell strings — to prevent shell injection.

  ## Usage

      # Install packages using the preferred manager:
      Trebejo.Packages.install("nodejs")

      # Install using a specific manager:
      Trebejo.Packages.install(:apt, ["nodejs", "npm"])

      # Check if installed:
      Trebejo.Packages.installed?(:brew, "node")
  """

  alias Trebejo.Util

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
    sudo = if Keyword.get(opts, :sudo, true), do: ["sudo"], else: []
    quiet = if Keyword.get(opts, :quiet, true), do: ["-qq"], else: []
    Util.run_ok("apt-get", sudo ++ quiet ++ ["install", "-y"] ++ List.wrap(packages))
  end

  def install(:apt_get, packages, opts), do: install(:apt, packages, opts)

  def install(:brew, packages, opts) do
    quiet = if Keyword.get(opts, :quiet, true), do: ["-q"], else: []
    Util.run_ok("brew", quiet ++ ["install"] ++ List.wrap(packages))
  end

  def install(:pacman, packages, opts) do
    quiet = if Keyword.get(opts, :quiet, true), do: ["--noconfirm"], else: []
    Util.run_ok("sudo", ["pacman", "-S"] ++ quiet ++ List.wrap(packages))
  end

  def install(:dnf, packages, opts) do
    quiet = if Keyword.get(opts, :quiet, true), do: ["-q"], else: []
    Util.run_ok("sudo", ["dnf"] ++ quiet ++ ["install", "-y"] ++ List.wrap(packages))
  end

  def install(:yum, packages, opts) do
    quiet = if Keyword.get(opts, :quiet, true), do: ["-q"], else: []
    Util.run_ok("sudo", ["yum"] ++ quiet ++ ["install", "-y"] ++ List.wrap(packages))
  end

  def install(:zypper, packages, opts) do
    quiet = if Keyword.get(opts, :quiet, true), do: ["-q"], else: []
    Util.run_ok("sudo", ["zypper"] ++ quiet ++ ["install", "-y"] ++ List.wrap(packages))
  end

  def install(:apk, packages, opts) do
    quiet = if Keyword.get(opts, :quiet, true), do: ["-q"], else: []
    Util.run_ok("sudo", ["apk", "add"] ++ quiet ++ List.wrap(packages))
  end

  def install(:pkg, packages, opts) do
    quiet = if Keyword.get(opts, :quiet, true), do: ["-q"], else: []
    Util.run_ok("sudo", ["pkg", "install"] ++ quiet ++ ["-y"] ++ List.wrap(packages))
  end

  def install(:winget, packages, opts) do
    quiet = if Keyword.get(opts, :quiet, true), do: ["--silent"], else: []
    Util.run_ok("winget", ["install"] ++ quiet ++ List.wrap(packages))
  end

  def install(:choco, packages, opts) do
    quiet = if Keyword.get(opts, :quiet, true), do: ["-y"], else: []
    Util.run_ok("choco", ["install"] ++ quiet ++ List.wrap(packages))
  end

  def install(:port, packages, opts) do
    quiet = if Keyword.get(opts, :quiet, true), do: ["-q"], else: []
    Util.run_ok("sudo", ["port", "install"] ++ quiet ++ List.wrap(packages))
  end

  def install(:nix, packages, _opts) do
    nix_args = Enum.flat_map(List.wrap(packages), &["nixpkgs.#{&1}"])
    Util.run_ok("nix-env", ["-iA"] ++ nix_args)
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
    case Util.run_cmd("dpkg", ["-l", package]) do
      {:ok, out, 0} -> String.contains?(out, "ii  #{package}")
      _ -> false
    end
  end

  def installed?(:apt_get, package), do: installed?(:apt, package)

  def installed?(:brew, package) do
    case Util.run_cmd("brew", ["list", package]) do
      {:ok, _out, 0} -> true
      _ -> false
    end
  end

  def installed?(:pacman, package) do
    case Util.run_cmd("pacman", ["-Qi", package]) do
      {:ok, _out, 0} -> true
      _ -> false
    end
  end

  def installed?(:dnf, package) do
    case Util.run_cmd("rpm", ["-q", package]) do
      {:ok, _out, 0} -> true
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
end
