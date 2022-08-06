defmodule Spike do
  def valid?(struct) do
    errors(struct) == %{}
  end

  defdelegate errors(struct), to: Spike.FormData
  defdelegate human_readable_errors(struct), to: Spike.FormData
  defdelegate dirty_fields(struct), to: Spike.FormData
  defdelegate make_dirty(struct), to: Spike.FormData
  defdelegate make_pristine(struct), to: Spike.FormData
  defdelegate update(struct, ref, params), to: Spike.FormData
  defdelegate append(struct, ref, field, params), to: Spike.FormData
  defdelegate delete(struct, ref), to: Spike.FormData
  defdelegate set_private(struct, ref, key, value), to: Spike.FormData
  defdelegate has_errors?(struct, ref, key), to: Spike.ErrorHelpers
  defdelegate has_errors?(struct, ref, key, message), to: Spike.ErrorHelpers

  def context(struct), do: struct.__spike_context__ |> Enum.reverse() |> tl() |> Enum.reverse()
end
