defmodule Trebejo.Env do
  @moduledoc false

  alias Apero.Env, as: A

  defdelegate load(path), to: A
  defdelegate read(path), to: A
  defdelegate write(path, vars), to: A
  defdelegate get_as(key, type), to: A
  defdelegate require_keys(keys), to: A
end
