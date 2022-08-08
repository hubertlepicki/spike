defmodule Spike.FormData.DirtyFields do
  import Spike.FormData.ETS

  def get_dirty_fields(%{ref: ref} = _struct) do
    get_dirty_fields(ref)
  end

  def get_dirty_fields(ref) do
    :dirty_fields
    |> ensure_initialized()
    |> :ets.lookup(ref)
    |> case do
      [{_ref, list}] -> list
      [] -> []
    end
  end

  def put_dirty_fields(%{ref: ref} = struct, dirty_fields) do
    put_dirty_fields(ref, dirty_fields)
    struct
  end

  def put_dirty_fields(ref, dirty_fields) do
    dirty_fields = dirty_fields |> Enum.uniq() |> Enum.sort()

    :dirty_fields
    |> ensure_initialized()
    |> :ets.insert({ref, dirty_fields})

    ref
  end
end
