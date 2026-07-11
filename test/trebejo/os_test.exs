defmodule Trebejo.OSTest do
  use ExUnit.Case, async: true

  alias Trebejo.OS

  # ── Pure functions moved to Apero.OS ─────────────────────────────────

  describe "type/0 (via Apero.OS)" do
    test "returns a known atom" do
      assert Apero.OS.type() in [:linux, :macos, :windows, :unknown]
    end
  end

  describe "hostname/0 (via Apero.OS)" do
    test "returns a non-empty binary" do
      hostname = Apero.OS.hostname()
      assert is_binary(hostname)
      assert byte_size(hostname) > 0
    end
  end

  describe "distro/0 (via Apero.OS)" do
    test "returns a non-empty binary" do
      distro = Apero.OS.distro()
      assert is_binary(distro)
      assert byte_size(distro) > 0
    end
  end

  describe "wsl?/0 (via Apero.OS)" do
    test "returns a boolean" do
      assert is_boolean(Apero.OS.wsl?())
    end
  end

  describe "container?/0 (via Apero.OS)" do
    test "returns a boolean" do
      assert is_boolean(Apero.OS.container?())
    end
  end

  # ── Shell-based operations in Trebejo.OS ──────────────────────────────

  describe "arch/0" do
    test "returns a known atom" do
      assert OS.arch() in [:x86_64, :arm64, :arm, :i386, :unknown]
    end
  end

  describe "kernel_version/0" do
    test "returns a binary" do
      assert is_binary(OS.kernel_version())
    end
  end

  describe "cpu_count/0" do
    test "returns a positive integer" do
      count = OS.cpu_count()
      assert is_integer(count)
      assert count >= 1
    end
  end

  describe "total_memory_mb/0" do
    test "returns a non-negative integer" do
      mem = OS.total_memory_mb()
      assert is_integer(mem)
      assert mem >= 0
    end
  end

  describe "info/0" do
    test "returns a map with shell-based keys" do
      info = OS.info()
      assert is_map(info)

      # Note: type, hostname, distro are now in Apero.OS, not in Trebejo.OS.info/0
      for key <- [:arch, :kernel_version, :cpu_count, :total_memory_mb] do
        assert Map.has_key?(info, key), "Missing key: #{key}"
      end
    end
  end

  describe "root?/0" do
    test "returns a boolean" do
      assert is_boolean(OS.root?())
    end
  end
end
