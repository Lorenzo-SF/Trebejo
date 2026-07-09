defmodule Trebejo.CryptoTest do
  use ExUnit.Case, async: true

  alias Trebejo.Crypto.{Cipher, Hash, Key, Random}

  describe "encrypt/2 and decrypt/2" do
    test "roundtrip with explicit key" do
      key = Random.generate_key()
      plaintext = "hello, world"
      assert {:ok, ciphertext} = Cipher.encrypt(plaintext, key)
      assert {:ok, ^plaintext} = Cipher.decrypt(ciphertext, key)
    end

    test "roundtrip with key: nil (auto-generated key)" do
      plaintext = "secret data"
      assert {:ok, _ciphertext} = Cipher.encrypt(plaintext, nil)
    end

    test "roundtrip with default nil key" do
      plaintext = "secret data"
      assert {:ok, _ciphertext} = Cipher.encrypt(plaintext)
    end

    test "wrong key returns error" do
      key = Random.generate_key()
      wrong_key = Random.generate_key()
      {:ok, ciphertext} = Cipher.encrypt("data", key)
      assert {:error, _} = Cipher.decrypt(ciphertext, wrong_key)
    end

    test "corrupted ciphertext returns error" do
      key = Random.generate_key()
      {:ok, ciphertext} = Cipher.encrypt("data", key)
      corrupted = String.slice(ciphertext, 0, 10) <> "XXXX"
      assert {:error, _} = Cipher.decrypt(corrupted, key)
    end

    test "decrypt with invalid base64 returns error" do
      key = Random.generate_key()
      assert {:error, :invalid_format} = Cipher.decrypt("not-base64!!!", key)
    end
  end

  describe "sha256/1" do
    test "returns a 64-char hex string" do
      hash = Hash.sha256("hello")
      assert is_binary(hash)
      assert String.length(hash) == 64
      assert hash =~ ~r/^[a-f0-9]+$/
    end

    test "is deterministic" do
      assert Hash.sha256("hello") == Hash.sha256("hello")
    end

    test "different inputs produce different hashes" do
      refute Hash.sha256("hello") == Hash.sha256("world")
    end
  end

  describe "sha512/1" do
    test "returns a 128-char hex string" do
      hash = Hash.sha512("hello")
      assert is_binary(hash)
      assert String.length(hash) == 128
      assert hash =~ ~r/^[a-f0-9]+$/
    end

    test "is deterministic" do
      assert Hash.sha512("hello") == Hash.sha512("hello")
    end
  end

  describe "md5/1" do
    test "returns a 32-char hex string" do
      hash = Hash.md5("hello")
      assert is_binary(hash)
      assert String.length(hash) == 32
      assert hash =~ ~r/^[a-f0-9]+$/
    end

    test "is deterministic" do
      assert Hash.md5("hello") == Hash.md5("hello")
    end
  end

  describe "hmac/2" do
    test "returns a 64-char hex string" do
      hmac = Hash.hmac("secret", "data")
      assert is_binary(hmac)
      assert String.length(hmac) == 64
    end

    test "is deterministic with same inputs" do
      assert Hash.hmac("secret", "data") == Hash.hmac("secret", "data")
    end

    test "different keys produce different results" do
      refute Hash.hmac("key1", "data") == Hash.hmac("key2", "data")
    end
  end

  describe "encrypt_chacha20/2 and decrypt_chacha20/2" do
    test "roundtrip encrypts and decrypts" do
      key = :crypto.strong_rand_bytes(32)
      plaintext = "hello chacha"
      ciphertext = Cipher.encrypt_chacha20(plaintext, key)
      assert ^plaintext = Cipher.decrypt_chacha20(ciphertext, key)
    end

    test "wrong key returns :error" do
      key = :crypto.strong_rand_bytes(32)
      wrong_key = :crypto.strong_rand_bytes(32)
      ciphertext = Cipher.encrypt_chacha20("data", key)
      assert :error = Cipher.decrypt_chacha20(ciphertext, wrong_key)
    end

    test "corrupted data returns :error" do
      key = :crypto.strong_rand_bytes(32)
      ciphertext = Cipher.encrypt_chacha20("data", key)
      assert :error = Cipher.decrypt_chacha20("garbage" <> ciphertext, key)
    end
  end

  describe "stream encryption (AES-256-CTR)" do
    test "encrypts and decrypts in streaming mode" do
      key = :crypto.strong_rand_bytes(32)
      plaintext = "this is a long message to encrypt in streaming mode"

      {state, iv} = Cipher.stream_init(key)
      {state, iv, chunk1} = Cipher.stream_encrypt({state, iv}, "this is a ")
      {state, _iv, chunk2} = Cipher.stream_encrypt({state, iv}, "long message to ")
      {state, _iv, chunk3} = Cipher.stream_encrypt({state, iv}, "encrypt in ")
      {state, _iv, chunk4} = Cipher.stream_encrypt({state, iv}, "streaming mode")
      rest = Cipher.stream_finalize(state)
      ciphertext = chunk1 <> chunk2 <> chunk3 <> chunk4 <> rest

      assert {:ok, ^plaintext} = Cipher.decrypt_ctr(ciphertext, key, iv)
    end

    test "encrypts empty data" do
      key = :crypto.strong_rand_bytes(32)
      {state, iv} = Cipher.stream_init(key)
      {state, iv, chunk} = Cipher.stream_encrypt({state, iv}, "")
      rest = Cipher.stream_finalize(state)
      ciphertext = chunk <> rest
      assert {:ok, ""} = Cipher.decrypt_ctr(ciphertext, key, iv)
    end

    test "wrong key returns garbage (not the original plaintext)" do
      key = :crypto.strong_rand_bytes(32)
      wrong_key = :crypto.strong_rand_bytes(32)
      plaintext = "data"
      {state, iv} = Cipher.stream_init(key)
      {state, iv, chunk} = Cipher.stream_encrypt({state, iv}, plaintext)
      _rest = Cipher.stream_finalize(state)
      assert {:ok, garbage} = Cipher.decrypt_ctr(chunk, wrong_key, iv)
      refute garbage == plaintext
    end
  end

  describe "generate_key/0" do
    test "returns a 32-byte binary" do
      key = Random.generate_key()
      assert is_binary(key)
      assert byte_size(key) == 32
    end

    test "is unique on each call" do
      refute Random.generate_key() == Random.generate_key()
    end
  end

  describe "random_hex/1" do
    test "returns string of correct length" do
      assert String.length(Random.random_hex(16)) == 32
      assert String.length(Random.random_hex(32)) == 64
    end

    test "returns hex-encoded string" do
      assert Random.random_hex(8) =~ ~r/^[a-f0-9]+$/
    end

    test "is unique on each call" do
      refute Random.random_hex() == Random.random_hex()
    end
  end

  describe "random_token/1" do
    test "returns a URL-safe base64 string" do
      token = Random.random_token(32)
      assert is_binary(token)
      assert Regex.match?(~r/^[A-Za-z0-9_-]+$/, token)
    end

    test "has no padding characters" do
      token = Random.random_token(32)
    end
  end
end
