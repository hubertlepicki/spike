defmodule Spike.FormData do
  @callback new(params :: map) :: map
  @callback new(params :: map, meta :: map) :: map
  @callback changeset(struct :: term, params :: map) :: term
  @callback to_params(form :: term) :: map
  @callback to_json(form :: term) :: binary

  @optional_callbacks new: 1, new: 2, changeset: 2, to_params: 1, to_json: 1

  defmacro __using__(do: block) do
    quote location: :keep do
      @behaviour Spike.FormData

      require Ecto.Schema

      # the below are done to avoid using Ecto.Schema.__using__
      @primary_key {:ref, :binary_id, autogenerate: false}
      @foreign_key_type :binary_id
      @timestamps_opts []
      @schema_prefix nil
      @schema_context nil
      @field_source_mapper fn x -> x end

      Module.register_attribute(__MODULE__, :ecto_primary_keys, accumulate: true)
      Module.register_attribute(__MODULE__, :ecto_fields, accumulate: true)
      Module.register_attribute(__MODULE__, :ecto_query_fields, accumulate: true)
      Module.register_attribute(__MODULE__, :ecto_field_sources, accumulate: true)
      Module.register_attribute(__MODULE__, :ecto_assocs, accumulate: true)
      Module.register_attribute(__MODULE__, :ecto_embeds, accumulate: true)
      Module.register_attribute(__MODULE__, :ecto_raw, accumulate: true)
      Module.register_attribute(__MODULE__, :ecto_autogenerate, accumulate: true)
      Module.register_attribute(__MODULE__, :ecto_autoupdate, accumulate: true)
      Module.register_attribute(__MODULE__, :ecto_redact_fields, accumulate: true)
      Module.put_attribute(__MODULE__, :ecto_derive_inspect_for_redacted_fields, true)
      Module.put_attribute(__MODULE__, :ecto_autogenerate_id, nil)

      require Spike.FormData
      use Vex.Struct

      Ecto.Schema.embedded_schema do
        unquote(block)
        field(:__dirty_fields__, {:array, :string}, default: [])
        field(:meta, :map, default: %{})
      end

      def new(params, meta \\ %{}) do
        %__MODULE__{}
        |> changeset(params)
        |> Ecto.Changeset.apply_changes()
        |> Map.put(:ref, Ecto.UUID.generate())
        |> Map.put(:meta, meta)
      end

      def changeset(struct, params) do
        Spike.FormData.changeset(struct, params)
      end

      def to_params(form) do
        Spike.FormData.Serialization.to_params(form)
      end

      def to_json(form) do
        form
        |> to_params()
        |> Spike.FormData.Serialization.to_json()
      end

      defoverridable new: 1, new: 2, changeset: 2, to_params: 1, to_json: 1
    end
  end

  def changeset(struct, params) do
    struct
    |> ensure_has_ref()
    |> Ecto.Changeset.cast(params, fields(struct) -- embeds(struct))
    |> cast_embeds(embeds(struct))
  end

  def update(struct, params) do
    changeset =
      struct
      |> Ecto.Changeset.cast(params, fields(struct) -- embeds(struct))

    dirty_fields = struct.__dirty_fields__ ++ (changeset.changes |> Map.keys())

    changeset
    |> Ecto.Changeset.put_change(:__dirty_fields__, Enum.uniq(dirty_fields))
    |> Ecto.Changeset.apply_changes()
  end

  def append(struct, field, params) do
    %{cardinality: :many, related: mod} = embed(struct, field)

    current_structs = Map.get(struct, field)
    dirty_fields = struct.__dirty_fields__ ++ [field]

    %{
      struct
      | field => current_structs ++ [mod.new(params)],
        :__dirty_fields__ => Enum.uniq(dirty_fields)
    }
  end

  def make_dirty(struct) do
    dirty_fields = (fields(struct) ++ embeds(struct)) |> Enum.uniq()

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

    %{struct | :__dirty_fields__ => (struct.__dirty_fields__ ++ dirty_embeds) |> Enum.uniq()}
  end

  def update(%{ref: ref} = struct, ref, params) do
    update(struct, params)
  end

  def update(struct, ref, params) do
    update_embeds(struct, ref, params, embeds(struct))
  end

  def append(%{ref: ref} = struct, ref, field, params) do
    append(struct, field, params)
  end

  def append(struct, ref, field, params) do
    append_embeds(struct, ref, field, params, embeds(struct))
  end

  defp fields(struct) when is_struct(struct) do
    fields(struct.__struct__)
  end

  defp fields(mod) when is_atom(mod) do
    mod.__schema__(:fields) -- [:__dirty_fields__, :ref, :meta]
  end

  defp embeds(struct) when is_struct(struct) do
    embeds(struct.__struct__)
  end

  defp embeds(mod) when is_atom(mod) do
    mod.__schema__(:embeds)
  end

  defp embed(struct, name) when is_struct(struct) do
    struct.__struct__.__schema__(:embed, name)
  end

  defp ensure_has_ref(%{ref: nil} = struct) do
    %{struct | ref: Ecto.UUID.generate()}
  end

  defp ensure_has_ref(struct), do: struct

  defp cast_embeds(changeset, []), do: changeset

  defp cast_embeds(changeset, [h | t]) do
    changeset
    |> Ecto.Changeset.cast_embed(h)
    |> cast_embeds(t)
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

  defp update_embeds(struct, _ref, _params, []), do: struct

  defp update_embeds(struct, ref, params, [embed | rest]) do
    embed_field = Map.get(struct, embed)

    case embed_field do
      nil ->
        update_embeds(struct, ref, params, rest)

      list when is_list(list) ->
        %{struct | embed => Enum.map(embed_field, &update(&1, ref, params))}
        |> update_embeds(ref, params, rest)
        |> maybe_mark_embed_as_dirty(struct, embed)

      _ ->
        %{struct | embed => update(embed_field, ref, params)}
        |> update_embeds(ref, params, rest)
        |> maybe_mark_embed_as_dirty(struct, embed)
    end
  end

  defp maybe_mark_embed_as_dirty(updated_struct, struct, embed) do
    if Map.get(updated_struct, embed) != Map.get(struct, embed) do
      dirty_fields = Enum.uniq(updated_struct.__dirty_fields__ ++ [embed])
      %{updated_struct | __dirty_fields__: dirty_fields}
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
