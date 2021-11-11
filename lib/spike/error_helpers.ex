defmodule Spike.ErrorHelpers do
  def has_errors?(struct, ref, key) do
    errors = Spike.errors(struct)
    errors[ref] && errors[ref][key] != nil
  end

  def has_errors?(struct, ref, key, message) do
    errors = Spike.errors(struct)

    errors[ref] && errors[ref][key] != nil &&
      message in Enum.map(errors[ref][key], fn {_k, v} -> v end)
  end
end
