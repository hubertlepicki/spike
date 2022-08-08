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

  def validation_context(struct) do
    struct
    |> Spike.FormData.ValidationContext.get_validation_context()
    |> case do
      list when list != [] > 0 ->
        list |> Enum.reverse() |> tl() |> Enum.reverse()

      otherwise ->
        otherwise
    end
  end
end
