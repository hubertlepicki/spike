defmodule Spike.Form.DirtyFields do
  @moduledoc false

  def get_dirty_fields(%{ref: _ref, __dirty_fields__: dirty_fields} = _struct) do
    dirty_fields
  end

  def put_dirty_fields(%{ref: _ref} = struct, dirty_fields) do
    dirty_fields = dirty_fields |> Enum.uniq() |> Enum.sort()
    %{struct | __dirty_fields__: dirty_fields}
  end
end
