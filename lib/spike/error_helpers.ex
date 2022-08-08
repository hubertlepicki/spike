defmodule Spike.ErrorHelpers do
  @moduledoc false

  @doc false
  def has_errors?(struct, ref, field) do
    errors = Spike.errors(struct)
    errors[ref] && errors[ref][field] != nil
  end

  @doc false
  def has_errors?(struct, ref, field, message) do
    errors = Spike.errors(struct)

    errors[ref] && errors[ref][field] != nil &&
      message in Enum.map(errors[ref][field], fn {_k, v} -> v end)
  end
end
