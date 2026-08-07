defmodule Trebejo.MixProject do
  use Mix.Project

  @version "2.0.0"
  @source_url "https://github.com/Lorenzo-SF/trebejo"

  def project do
    [
      app: :trebejo,
      version: @version,
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      name: "Trebejo",
      description:
        "System command wrappers for Elixir — safe Docker, Git, SSH, kubectl, " <>
          "process, network, compression and OS operations powered by Arrea.Command.",
      source_url: @source_url,
      homepage_url: @source_url,
      package: [
        name: :trebejo,
        licenses: ["MIT"],
        links: %{"GitHub" => @source_url},
        maintainers: ["Lorenzo Sánchez"]
      ],
      docs: docs(),
      # ExCoveralls for CI; `mix test --cover` also works natively
      test_coverage: [tool: ExCoveralls],
      dialyzer: dialyzer_config()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Trebejo.Application, []}
    ]
  end

  defp deps do
    [
      {:apero, path: "../apero"},
      # Local path override — CI/CD must set up the same path or use a
      # published version. See `../arrea/docs/AUDIT.md` for details.
      {:arrea, path: "../arrea", override: true},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, ">= 1.0.0", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:excoveralls, "~> 0.18", only: :test}
    ]
  end

  defp aliases do
    [
      qa: [
        "format",
        "compile",
        "dialyzer",
        "cmd sh -c 'MIX_ENV=test mix test --cover --exclude external_cmd'",
        "cmd sh -c 'alaja json \"$(mix credo --format=json)\"'"
      ],
      bench: ["cmd sh -c 'echo \"Trebejo has no benchmarks yet; see FASE-2 §TR-8.\"'"]
    ]
  end

  defp docs do
    [
      main: "readme",
      source_url: @source_url,
      homepage_url: @source_url,
      source_ref: @version,
      extras: ["README.md", "docs/README.es.md", "CHANGELOG.md", "LICENSE.md"],
      groups_for_modules: [
        Core: [Trebejo, Trebejo.Application],
        "System & Platform": [Trebejo.OS, Trebejo.Proc, Trebejo.Packages],
        Containers: [Trebejo.Docker],
        Network: [Trebejo.Network, Trebejo.SSH],
        Orchestration: [Trebejo.Kubernetes],
        "Source Control": [Trebejo.Git, Trebejo.Git.Local],
        "File System": [Trebejo.File, Trebejo.File.IO],
        Compression: [Trebejo.Compress]
      ]
    ]
  end

  defp dialyzer_config do
    [
      plt_file: {:no_warn, "priv/plts/trebejo"},
      plt_core_path: "priv/plts/core",
      plt_add_apps: [:mix],
      flags: [:error_handling, :no_opaque, :no_underspecs]
    ]
  end
end
