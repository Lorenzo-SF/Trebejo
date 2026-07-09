defmodule Trebejo.Conf do
  @moduledoc false

  alias Apero.Conf, as: A

  defdelegate detect_format(path), to: A
  defdelegate validate(config, schema), to: A
  defdelegate encode(data, format), to: A
  defdelegate load(path, opts), to: A
  defdelegate write(path, data, opts), to: A
  defdelegate merge(configs), to: A
  defdelegate print_summary(config, title), to: A
  defdelegate get(config, key), to: A
  defdelegate set(config, key, value), to: A
end
