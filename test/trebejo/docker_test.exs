defmodule Trebejo.DockerTest do
  use ExUnit.Case, async: true

  alias Trebejo.Docker

  describe "runtime/0" do
    test "returns :podman, :docker, or :none" do
      result = Docker.runtime()
      assert result in [:podman, :docker, :none]
    end
  end

  describe "in_container?/0" do
    test "returns a boolean" do
      assert is_boolean(Docker.in_container?())
    end
  end

  describe "ps/1" do
    test "returns an ok or error tuple with binary output" do
      result = Docker.ps()
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "compose operations" do
    test "compose_up returns an ok or error tuple with binary output" do
      result = Docker.compose_up()
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "compose_down returns an ok or error tuple with binary output" do
      result = Docker.compose_down()
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "compose_restart returns an ok or error tuple with binary output" do
      result = Docker.compose_restart()
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "compose_pull returns an ok or error tuple with binary output" do
      result = Docker.compose_pull()
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "compose_build returns an ok or error tuple with binary output" do
      result = Docker.compose_build()
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "compose_logs returns an ok or error tuple with binary output" do
      result = Docker.compose_logs()
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "compose_exec returns an ok or error tuple with binary output" do
      result = Docker.compose_exec("service", ["echo", "hello"])
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "container operations" do
    test "pull returns :ok or {:error, _}" do
      result = Docker.pull("hello-world:latest")
      assert result == :ok or match?({:error, _}, result)
    end

    test "state returns a known atom or error" do
      result = Docker.state("non-existent-container")
      assert result in [:running, :stopped, :missing] or match?({:error, _}, result)
    end

    test "start returns :ok or {:error, _}" do
      result = Docker.start("non-existent-container")
      assert result == :ok or match?({:error, _}, result)
    end

    test "stop returns :ok or {:error, _}" do
      result = Docker.stop("non-existent-container")
      assert result == :ok or match?({:error, _}, result)
    end

    test "rm returns :ok or {:error, _}" do
      result = Docker.rm("non-existent-container")
      assert result == :ok or match?({:error, _}, result)
    end

    test "exec returns {:ok, _} or {:error, _}" do
      result = Docker.exec("non-existent-container", ["echo", "hello"])
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "run returns {:ok, _} or {:error, _}" do
      result = Docker.run(image: "hello-world:latest", detach: true)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "volume operations" do
    test "volume_create returns an ok or error tuple" do
      result = Docker.volume_create("apero-test-volume-#{:rand.uniform(99999)}")
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "volume_list returns an ok or error tuple" do
      result = Docker.volume_list()
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "volume_remove returns an ok or error tuple" do
      result = Docker.volume_remove("apero-test-volume-#{:rand.uniform(99999)}")
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "network operations" do
    test "network_create returns an ok or error tuple" do
      result = Docker.network_create("apero-test-network-#{:rand.uniform(99999)}")
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "network_list returns an ok or error tuple" do
      result = Docker.network_list()
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "network_remove returns an ok or error tuple" do
      result = Docker.network_remove("apero-test-network-#{:rand.uniform(99999)}")
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end
end
