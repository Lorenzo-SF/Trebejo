defmodule Trebejo.Retry do
  @moduledoc false

  alias Apero.Retry, as: A
  defdelegate with(fun, opts \\ []), to: A
end
