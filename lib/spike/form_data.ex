defmodule Spike.FormData do
  @callback new(params :: map) :: map
  @callback new(params :: map, meta :: map) :: map
  @callback to_params(form :: term) :: map
  @callback to_json(form :: term) :: binary
  @callback after_update(struct_before :: term, struct_after :: term, changed_fields :: list) ::
              term

  @optional_callbacks new: 1, new: 2, to_params: 1, to_json: 1, after_update: 3

  defmacro __using__(do: block) do
    quote location: :keep do
      @behaviour Spike.FormData

      require Spike.FormData
      use Vex.Struct

      import Spike.FormData.Schema

      Module.register_attribute(__MODULE__, :struct_fields, accumulate: true)
      Module.register_attribute(__MODULE__, :schema_fields, accumulate: true)
      Module.register_attribute(__MODULE__, :schema_embeds, accumulate: true)

      unquote(block)

      field(:__dirty_fields__, {:array, :string}, default: [], private: true)
      field(:meta, :map, default: %{}, private: true)
      field(:ref, :string, private: true)

      defstruct @struct_fields

      def __struct_fields__() do
        @struct_fields
      end

      def __schema_fields__() do
        @schema_fields
      end

      def __schema_embeds__() do
        @schema_embeds
      end

      def new(params, meta \\ %{}) do
        %__MODULE__{}
        |> Spike.FormData.cast(params)
        |> Map.put(:ref, Spike.UUID.generate())
        |> Map.put(:meta, meta)
      end

      def to_params(form) do
        Spike.FormData.Serialization.to_params(form)
      end

      def to_json(form) do
        form
        |> to_params()
        |> Spike.FormData.Serialization.to_json()
      end

      def after_update(_struct_before, struct_after, _changed_fields) do
        struct_after
      end

      defoverridable new: 1, new: 2, to_params: 1, to_json: 1, after_update: 3
    end
  end

  def cast(struct, params) do
    params =
      (params || %{})
      |> Mappable.to_map(keys: :strings, shallow: true)

    casted_params =
      params
      |> Tarams.cast!(tarams_schema_definition(struct.__struct__, Map.keys(params)))
      |> Mappable.to_map(keys: :atoms)

    struct
    |> ensure_has_ref()
    |> Map.merge(casted_params)
    |> cast_embeds(embeds(struct), params)
  end

  defp tarams_schema_definition(mod, param_keys) do
    mod.__schema_fields__()
    |> Enum.filter(&(&1.private == false && "#{&1.name}" in param_keys))
    |> Enum.map(fn definition ->
      {definition.name, [type: definition.type, default: definition.default]}
    end)
    |> Enum.into(%{})
  end

  def update(%{ref: ref} = struct, ref, params) do
    update(struct, params)
  end

  def update(struct, ref, params) do
    update_embeds(struct, ref, params, embeds(struct))
  end

  defp update(struct, params) do
    struct_before = struct

    struct_after =
      struct
      |> cast(params)

    updated_fields = updated_fields(struct_before, struct_after)
    dirty_fields = (struct.__dirty_fields__ ++ updated_fields) |> Enum.uniq() |> Enum.sort()

    struct.__struct__.after_update(
      struct_before,
      %{struct_after | __dirty_fields__: dirty_fields},
      updated_fields
    )
  end

  defp updated_fields(struct_before, struct_after) do
    struct_before
    |> MapDiff.diff(struct_after)
    |> Map.get(:value)
    |> Enum.filter(fn {_k, %{changed: changed}} ->
      changed != :equal
    end)
    |> Enum.into(%{})
    |> Map.keys()
  end

  def append(%{ref: ref} = struct, ref, field, params) do
    append(struct, field, params)
  end

  def append(struct, ref, field, params) do
    append_embeds(struct, ref, field, params, embeds(struct))
  end

  defp append(struct, field, params) do
    %{many: true, type: mod} = embed(struct, field)

    current_structs = Map.get(struct, field)
    dirty_fields = (struct.__dirty_fields__ ++ [field]) |> Enum.uniq() |> Enum.sort()

    new_child =
      case params do
        %{ref: _ref} = fd when is_struct(fd) ->
          params

        _ ->
          mod.new(params)
      end

    %{
      struct
      | field => current_structs ++ [new_child],
        :__dirty_fields__ => dirty_fields
    }
  end

  def make_dirty(struct) do
    dirty_fields = (fields(struct) ++ embeds(struct)) |> Enum.uniq() |> Enum.sort()

    %{struct | :__dirty_fields__ => dirty_fields}
    |> make_embeds_dirty(embeds(struct))
  end

  def make_pristine(struct) do
    %{struct | :__dirty_fields__ => []}
    |> make_embeds_pristine(embeds(struct))
  end

  def errors(struct) do
    struct
    |> traverse_structs(&get_errors/1)
    |> List.flatten()
    |> Enum.filter(& &1)
    |> Enum.into(%{})
  end

  def human_readable_errors(struct) do
    struct
    |> traverse_struct_paths([], &get_human_readable_errors/1)
    |> List.flatten()
    |> Enum.filter(& &1)
    |> Enum.into(%{})
    |> Enum.map(fn {path, errors} ->
      Enum.map(errors, fn {k, msgs} ->
        {Enum.join(path ++ ["#{k}"], "."), msgs}
      end)
    end)
    |> List.flatten()
    |> Enum.into(%{})
  end

  def dirty_fields(struct) do
    struct
    |> traverse_structs(&get_dirty_fields/1)
    |> List.flatten()
    |> Enum.filter(& &1)
    |> Enum.into(%{})
  end

  def delete(%{ref: ref} = _struct, ref) do
    nil
  end

  def delete(struct, ref) do
    {struct, dirty_embeds} = delete_embeds(struct, ref, embeds(struct), [])

    %{
      struct
      | :__dirty_fields__ =>
          (struct.__dirty_fields__ ++ dirty_embeds) |> Enum.uniq() |> Enum.sort()
    }
  end

  defp fields(struct) when is_struct(struct) do
    fields(struct.__struct__)
  end

  defp fields(mod) when is_atom(mod) do
    mod.__schema_fields__()
    |> Enum.filter(&(&1[:private] == false))
    |> Enum.map(& &1[:name])
  end

  defp embeds(struct) when is_struct(struct) do
    embeds(struct.__struct__)
  end

  defp embeds(mod) when is_atom(mod) do
    mod.__schema_embeds__()
    |> Enum.map(& &1[:name])
  end

  defp embed(struct, name) when is_struct(struct) do
    struct.__struct__.__schema_embeds__()
    |> Enum.find(&(&1.name == name))
  end

  defp ensure_has_ref(%{ref: nil} = struct) do
    %{struct | ref: Spike.UUID.generate()}
  end

  defp ensure_has_ref(struct), do: struct

  defp cast_embeds(form_data, [], _params), do: form_data

  defp cast_embeds(form_data, [h | t], params) do
    if Map.keys(params) |> Enum.member?("#{h}") do
      form_data
      |> cast_embed(embed(form_data, h), params["#{h}"])
    else
      form_data
    end
    |> cast_embeds(t, params)
  end

  defp cast_embed(form_data, %{one: true} = embed, %{__struct__: _} = new_struct) do
    form_data
    |> Map.put(embed.name, new_struct)
  end

  defp cast_embed(form_data, %{one: true} = embed, map) do
    form_data
    |> Map.put(embed.name, embed.type.new(map))
  end

  defp cast_embed(form_data, %{many: true} = _embed, nil), do: form_data
  defp cast_embed(form_data, %{many: true} = embed, []), do: form_data |> Map.put(embed.name, [])

  defp cast_embed(form_data, %{many: true} = embed, list) do
    form_data
    |> Map.put(
      embed.name,
      Enum.map(list, fn
        %{__struct__: _} = new_struct -> new_struct
        map -> embed.type.new(map)
      end)
    )
  end

  defp make_embeds_dirty(struct, []), do: struct

  defp make_embeds_dirty(struct, [embed | rest]) do
    %{struct | embed => make_embed_dirty(Map.get(struct, embed))}
    |> make_embeds_dirty(rest)
  end

  defp make_embed_dirty(nil), do: nil

  defp make_embed_dirty(list) when is_list(list) do
    list
    |> Enum.map(&make_dirty(&1))
  end

  defp make_embed_dirty(struct) do
    make_dirty(struct)
  end

  defp make_embeds_pristine(struct, []), do: struct

  defp make_embeds_pristine(struct, [embed | rest]) do
    %{struct | embed => make_embed_pristine(Map.get(struct, embed))}
    |> make_embeds_pristine(rest)
  end

  defp make_embed_pristine(nil), do: nil

  defp make_embed_pristine(list) when is_list(list) do
    list
    |> Enum.map(&make_pristine(&1))
  end

  defp make_embed_pristine(struct) do
    make_pristine(struct)
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

  defp get_human_readable_errors(struct) do
    struct
    |> Vex.errors()
    |> Enum.reduce(%{}, fn {:error, field, _type, message}, acc ->
      list = acc[field] || []

      acc
      |> Map.put("#{field}", list ++ [message])
    end)
  end

  defp get_dirty_fields(struct) do
    struct.__dirty_fields__
  end

  defp traverse_structs(nil, _callback), do: []

  defp traverse_structs(list, callback) when is_list(list) do
    list
    |> Enum.map(&traverse_structs(&1, callback))
  end

  defp traverse_structs(current_struct, callback) do
    collected = callback.(current_struct)

    if Enum.count(collected) > 0 do
      [{current_struct.ref, collected}]
    else
      []
    end ++
      (embeds(current_struct)
       |> Enum.map(fn embed ->
         traverse_structs(Map.get(current_struct, embed), callback)
       end))
  end

  defp traverse_struct_paths(nil, _, _callback), do: []

  defp traverse_struct_paths(list, path, callback) when is_list(list) do
    list
    |> Enum.with_index()
    |> Enum.map(fn {val, index} -> traverse_struct_paths(val, path ++ ["#{index}"], callback) end)
  end

  defp traverse_struct_paths(current_struct, path, callback) do
    collected = callback.(current_struct)

    if Enum.count(collected) > 0 do
      [{path, collected}]
    else
      []
    end ++
      (embeds(current_struct)
       |> Enum.map(fn embed ->
         traverse_struct_paths(Map.get(current_struct, embed), path ++ ["#{embed}"], callback)
       end))
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
        |> maybe_mark_embed_as_dirty_and_run_callback(struct, embed)

      _ ->
        %{struct | embed => update(embed_field, ref, params)}
        |> update_embeds(ref, params, rest)
        |> maybe_mark_embed_as_dirty_and_run_callback(struct, embed)
    end
  end

  defp maybe_mark_embed_as_dirty_and_run_callback(updated_struct, struct, embed) do
    if Map.get(updated_struct, embed) != Map.get(struct, embed) do
      dirty_fields = (updated_struct.__dirty_fields__ ++ [embed]) |> Enum.uniq() |> Enum.sort()

      struct.__struct__.after_update(struct, %{updated_struct | __dirty_fields__: dirty_fields}, [
        embed
      ])
    else
      updated_struct
    end
  end

  defp delete_embeds(struct, _ref, [], dirty_embeds), do: {struct, dirty_embeds}

  defp delete_embeds(struct, ref, [embed | rest], dirty_embeds) do
    embed_field = Map.get(struct, embed)

    case embed_field do
      nil ->
        delete_embeds(struct, ref, rest, dirty_embeds)

      list when is_list(list) ->
        %{struct | embed => Enum.map(embed_field, &delete(&1, ref)) |> Enum.filter(& &1)}
        |> delete_embeds(ref, rest, dirty_embeds ++ [embed])

      _ ->
        %{struct | embed => delete(embed_field, ref)}
        |> delete_embeds(ref, rest, dirty_embeds ++ [embed])
    end
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

  def set_meta(%{ref: ref} = form, ref, value) do
    %{form | meta: value}
  end

  def set_meta(form, ref, value) do
    set_embeds_meta(form, ref, value, embeds(form))
  end

  defp set_embeds_meta(struct, _ref, _params, []), do: struct

  defp set_embeds_meta(struct, ref, value, [embed | rest]) do
    embed_field = Map.get(struct, embed)

    case embed_field do
      nil ->
        set_embeds_meta(struct, ref, value, rest)

      list when is_list(list) ->
        %{struct | embed => Enum.map(embed_field, &set_meta(&1, ref, value))}
        |> set_embeds_meta(ref, value, rest)

      _ ->
        %{struct | embed => set_meta(embed_field, ref, value)}
        |> set_embeds_meta(ref, value, rest)
    end
  end
end
