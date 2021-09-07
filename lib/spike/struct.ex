defmodule Spike.Struct do
  defmacro __using__(_opts) do
    quote do
      use Ecto.Schema
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
        fields = __MODULE__.__schema__(:fields)
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
        fields = __MODULE__.__schema__(:fields)
        embeds = __MODULE__.__schema__(:embeds)

        struct
        |> Ecto.Changeset.cast(params, fields -- embeds)
        |> Ecto.Changeset.apply_changes()
      end

      def append(struct, field, params) do
        %{cardinality: :many, related: mod} = __MODULE__.__schema__(:embed, field)

        current_structs = Map.get(struct, field)

        %{struct | field => current_structs ++ [mod.new(params)]}
      end
    end
  end
end
