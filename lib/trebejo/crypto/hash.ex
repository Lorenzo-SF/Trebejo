defmodule Trebejo.Crypto.Hash do
  @moduledoc false

  alias Apero.Crypto.Hash, as: A
  defdelegate sha256(data), to: A
  defdelegate sha512(data), to: A
  defdelegate md5(data), to: A
  defdelegate hmac(key, data), to: A
end
