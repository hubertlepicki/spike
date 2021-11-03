defmodule Spike.FormData.Serialization do
  def to_params(%{ref: _, __struct__: _, __dirty_fields__: _} = form_data) do
    fields =
      form_data
      |> Map.keys()
      |> Enum.filter(&(&1 not in [:__dirty_fields__, :__struct__, :ref]))

    form_data
    |> Map.take(fields)
    |> Enum.map(fn {k, v} ->
      {to_string(k), to_params(v)}
    end)
    |> Enum.into(%{})
  end

  def to_params(list) when is_list(list) do
    list
    |> Enum.map(&to_params(&1))
  end

  def to_params(otherwise), do: otherwise

  def to_json(form_data) do
    form_data
    |> to_params()
    |> Application.get_env(:phoenix, :json_library, Jason).encode!()
  end
end
