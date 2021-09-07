defmodule Spike.Struct do
  defmacro define_schema(do: block) do
    quote do
      embedded_schema do
        unquote(block)
        field(:__dirty_fields__, {:array, :string}, default: [])
      end
    end
  end

  defmacro __using__(_opts) do
    quote do
      use Ecto.Schema
      require Spike.Struct
      import Spike.Struct, only: [define_schema: 1]
      use Vex.Struct

      @primary_key {:ref, :binary_id, autogenerate: false}
      @foreign_key_type :binary_id

      @before_compile Spike.Struct
    end
  end

  defmacro __before_compile__(_) do
    quote do
      def new(params) do
        %__MODULE__{}
        |> changeset(params)
        |> Ecto.Changeset.apply_changes()
        |> Map.put(:ref, Ecto.UUID.generate())
      end

      def changeset(struct, params) do
        fields = __MODULE__.__schema__(:fields) -- [:__dirty_fields__, :ref]
        embeds = __MODULE__.__schema__(:embeds)

        struct
        |> ensure_has_ref()
        |> Ecto.Changeset.cast(params, fields -- embeds)
        |> cast_embeds(embeds)
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

      def update(struct, params) do
        fields = __MODULE__.__schema__(:fields) -- [:__dirty_fields__, :ref]
        embeds = __MODULE__.__schema__(:embeds)

        changeset =
          struct
          |> Ecto.Changeset.cast(params, fields -- embeds)

        dirty_fields = struct.__dirty_fields__ ++ (changeset.changes |> Map.keys())

        changeset
        |> Ecto.Changeset.put_change(:__dirty_fields__, Enum.uniq(dirty_fields))
        |> Ecto.Changeset.apply_changes()
      end

      def append(struct, field, params) do
        %{cardinality: :many, related: mod} = __MODULE__.__schema__(:embed, field)

        current_structs = Map.get(struct, field)
        dirty_fields = struct.__dirty_fields__ ++ [field]

        %{
          struct
          | field => current_structs ++ [mod.new(params)],
            :__dirty_fields__ => Enum.uniq(dirty_fields)
        }
      end

      def make_dirty(struct) do
        fields = __MODULE__.__schema__(:fields) -- [:__dirty_fields__, :ref]
        embeds = __MODULE__.__schema__(:embeds)

        dirty_fields = (fields ++ embeds) |> Enum.uniq()

        %{struct | :__dirty_fields__ => dirty_fields}
        |> make_embeds_dirty(embeds)
      end

      defp make_embeds_dirty(struct, []), do: struct

      defp make_embeds_dirty(struct, [embed | rest]) do
        %{struct | embed => make_embed_dirty(Map.get(struct, embed))}
        |> make_embeds_dirty(rest)
      end

      defp make_embed_dirty(nil), do: nil

      defp make_embed_dirty(list) when is_list(list) do
        list
        |> Enum.map(& &1.__struct__.make_dirty(&1))
      end

      defp make_embed_dirty(struct) do
        struct.__struct__.make_dirty(struct)
      end

      def make_pristine(struct) do
        embeds = __MODULE__.__schema__(:embeds)

        %{struct | :__dirty_fields__ => []}
        |> make_embeds_pristine(embeds)
      end

      defp make_embeds_pristine(struct, []), do: struct

      defp make_embeds_pristine(struct, [embed | rest]) do
        %{struct | embed => make_embed_pristine(Map.get(struct, embed))}
        |> make_embeds_pristine(rest)
      end

      defp make_embed_pristine(nil), do: nil

      defp make_embed_pristine(list) when is_list(list) do
        list
        |> Enum.map(& &1.__struct__.make_pristine(&1))
      end

      defp make_embed_pristine(struct) do
        struct.__struct__.make_pristine(struct)
      end
    end
  end
end
