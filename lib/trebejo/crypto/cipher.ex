defmodule Trebejo.Crypto.Cipher do
  @moduledoc false

  alias Apero.Crypto.Cipher, as: A
  defdelegate encrypt(data, key \\ nil), to: A
  defdelegate decrypt(ciphertext, key), to: A
  defdelegate encrypt_chacha20(data, key), to: A
  defdelegate decrypt_chacha20(ciphertext, key), to: A
  defdelegate stream_init(key), to: A
  defdelegate stream_encrypt(state, data), to: A
  defdelegate stream_finalize(state), to: A
  defdelegate decrypt_ctr(ciphertext, key, iv), to: A
end
