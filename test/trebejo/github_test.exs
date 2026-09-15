defmodule Trebejo.GitHubTest do
  use ExUnit.Case, async: false

  alias Trebejo.GitHub
  alias Trebejo.Mox
  alias Trebejo.Runner

  setup do
    Mox.reset_stubs()
    previous = :persistent_term.get({Runner, :runner}, :unset)
    Runner.set_runner(Mox.Runner)
    on_exit(fn -> if previous == :unset, do: :ok, else: Runner.set_runner(previous) end)
    :ok
  end

  test "run/2 forwards --repo when :repo is set" do
    Mox.stub_cmd(
      "gh",
      ["--repo", "Lorenzo-SF/arrea", "pr", "list", "--state", "open"],
      {:ok, "12\tMigrate to arrea 3.0\n", 0}
    )

    assert {:ok, "12\tMigrate to arrea 3.0\n", 0} =
             GitHub.run(["pr", "list", "--state", "open"], repo: "Lorenzo-SF/arrea")
  end

  test "pr_view/2 with comments flag" do
    Mox.stub_cmd(
      "gh",
      ["pr", "view", "42", "--comments"],
      {:ok, "...", 0}
    )

    assert {:ok, "...", 0} = GitHub.pr_view(42, comments: true)
  end

  test "pr_create/1 builds --title, --body, --base flags" do
    Mox.stub_cmd(
      "gh",
      ["pr", "create", "--title", "FASE-3", "--body", "go", "--base", "main"],
      {:ok, "https://github.com/x/y/pull/1\n", 0}
    )

    assert {:ok, _, 0} = GitHub.pr_create(title: "FASE-3", body: "go", base: "main")
  end

  test "issue_create/1 with --title and --body" do
    Mox.stub_cmd(
      "gh",
      ["issue", "create", "--title", "Bug", "--body", "details"],
      {:ok, "https://github.com/x/y/issues/5\n", 0}
    )

    assert {:ok, _, 0} = GitHub.issue_create(title: "Bug", body: "details")
  end

  test "release_create/1 with notes and prerelease" do
    Mox.stub_cmd(
      "gh",
      ["release", "create", "v3.0.0", "--notes", "ship it", "--prerelease"],
      {:ok, "", 0}
    )

    assert {:ok, _, 0} = GitHub.release_create(tag: "v3.0.0", notes: "ship it", prerelease: true)
  end

  test "run/2 returns typed error on non-zero exit" do
    Mox.stub_cmd("gh", ["pr", "list"], {:ok, "GraphQL error\n", 1})
    assert {:error, %Trebejo.Error{kind: :exit_nonzero}} = GitHub.run(["pr", "list"])
  end
end
