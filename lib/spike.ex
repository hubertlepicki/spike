defmodule Spike do
  def valid?(struct) do
    errors(struct) == %{}
  end

  def errors(struct) do
    struct
    |> traverse_validating_structs()
    |> List.flatten()
    |> Enum.filter(& &1)
    |> Enum.into(%{})
  end

  defp traverse_validating_structs(nil), do: []

  defp traverse_validating_structs(list) when is_list(list) do
    list
    |> Enum.map(&traverse_validating_structs(&1))
  end

  defp traverse_validating_structs(current_struct) do
    embeds = current_struct.__struct__.__schema__(:embeds)
    errors = get_errors(current_struct)

    if errors != %{} do
      [{current_struct.ref, errors}]
    else
      []
    end ++
      (embeds
       |> Enum.map(fn embed ->
         traverse_validating_structs(Map.get(current_struct, embed))
       end))
  end

  defp get_errors(struct) do
    struct
    |> Vex.errors()
    |> Enum.reduce(%{}, fn {:error, field, type, message}, acc ->
      list = acc[field] || []

      acc
      |> Map.put(field, list ++ [{type, message}])
    end)
  end

  def update(%{ref: ref} = struct, ref, params) do
    struct.__struct__.update(struct, params)
  end

  def update(struct, ref, params) do
    embeds = struct.__struct__.__schema__(:embeds)

    update_embeds(struct, ref, params, embeds)
  end

  defp update_embeds(struct, _ref, _params, []), do: struct

  defp update_embeds(struct, ref, params, [embed | rest]) do
    embed_field = Map.get(struct, embed)

    case embed_field do
      nil ->
        update_embeds(struct, ref, params, rest)

      list when is_list(list) ->
        %{struct | embed => Enum.map(embed_field, &update(&1, ref, params))}
        |> update_embeds(ref, params, rest)

      _ ->
        %{struct | embed => update(embed_field, ref, params)}
        |> update_embeds(ref, params, rest)
    end
  end

  def delete(%{ref: ref} = _struct, ref) do
    nil
  end

  def delete(struct, ref) do
    embeds = struct.__struct__.__schema__(:embeds)

    delete_embeds(struct, ref, embeds)
  end

  defp delete_embeds(struct, _ref, []), do: struct

  defp delete_embeds(struct, ref, [embed | rest]) do
    embed_field = Map.get(struct, embed)

    case embed_field do
      nil ->
        delete_embeds(struct, ref, rest)

      list when is_list(list) ->
        %{struct | embed => Enum.map(embed_field, &delete(&1, ref)) |> Enum.filter(& &1)}
        |> delete_embeds(ref, rest)

      _ ->
        %{struct | embed => delete(embed_field, ref)}
        |> delete_embeds(ref, rest)
    end
  end

  def append(%{ref: ref} = struct, ref, field, params) do
    struct.__struct__.append(struct, field, params)
  end

  def append(struct, ref, field, params) do
    embeds = struct.__struct__.__schema__(:embeds)

    append_embeds(struct, ref, field, params, embeds)
  end

  defp append_embeds(struct, _ref, _field, _params, []), do: struct

  defp append_embeds(struct, ref, field, params, [embed | rest]) do
    embed_field = Map.get(struct, embed)

    case embed_field do
      nil ->
        append_embeds(struct, ref, field, params, rest)

      list when is_list(list) ->
        %{struct | embed => Enum.map(embed_field, &append(&1, ref, field, params))}
        |> append_embeds(ref, field, params, rest)

      _ ->
        %{struct | embed => append(embed_field, ref, field, params)}
        |> append_embeds(ref, field, params, rest)
    end
  end
end
