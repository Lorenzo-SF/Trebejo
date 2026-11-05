defmodule Trebejo.Git do
  @moduledoc """
  Git utilities for repository management, configuration and synchronisation.

  The implementation lives in `Trebejo.Git.Local`. Use that module for
  all Git operations (clone, commit, pull, push, branch, stash, merge, etc.).

  ## CLI availability

  This module provides helpers to check for Git-related CLI tools.

  ## Security

  All user-supplied values (commit messages, branch names, file paths)
  are passed as argument lists — never interpolated into shell strings —
  to prevent shell injection attacks.
  """

  @doc "Checks if the GitHub CLI (gh) is available."
  @spec gh_available?() :: boolean()
  def gh_available?, do: System.find_executable("gh") != nil

  @doc "Checks if the GitLab CLI (glab) is available."
  @spec glab_available?() :: boolean()
  def glab_available?, do: System.find_executable("glab") != nil
end
