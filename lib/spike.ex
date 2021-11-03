defmodule Spike do
  def valid?(struct) do
    errors(struct) == %{}
  end

  defdelegate errors(struct), to: Spike.FormData
  defdelegate dirty_fields(struct), to: Spike.FormData
  defdelegate make_dirty(struct), to: Spike.FormData
  defdelegate make_pristine(struct), to: Spike.FormData
  defdelegate update(struct, ref, params), to: Spike.FormData
  defdelegate append(struct, ref, field, params), to: Spike.FormData
  defdelegate delete(struct, ref), to: Spike.FormData
  defdelegate to_params(struct), to: Spike.FormData.Serialization
  defdelegate to_json(struc), to: Spike.FormData.Serialization
end
