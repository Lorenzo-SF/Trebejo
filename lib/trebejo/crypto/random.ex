defmodule Trebejo.Crypto.Random do
  @moduledoc false

  alias Apero.Crypto.Random, as: A
  defdelegate generate_key(), to: A
  defdelegate random_hex(bytes), to: A
  defdelegate random_hex(), to: A
  defdelegate random_token(bytes), to: A
end
