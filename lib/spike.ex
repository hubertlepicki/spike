defmodule Spike do
  def valid?(struct) do
    errors(struct) == %{}
  end

  defdelegate errors(struct), to: Spike.Struct
  defdelegate dirty_fields(struct), to: Spike.Struct
  defdelegate make_dirty(struct), to: Spike.Struct
  defdelegate make_pristine(struct), to: Spike.Struct
  defdelegate update(struct, ref, params), to: Spike.Struct
  defdelegate append(struct, ref, field, params), to: Spike.Struct
  defdelegate delete(struct, ref), to: Spike.Struct
end
