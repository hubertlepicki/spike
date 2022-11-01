defmodule Spike.Form.Schema do
  @doc """
    Contains macros used to define fields and embeds.
  """

  defmacro field(name, type \\ :string, opts \\ []) do
    quote do
      Module.put_attribute(__MODULE__, :struct_fields, {unquote(name), unquote(opts)[:default]})

      Module.put_attribute(__MODULE__, :schema_fields, %{
        name: unquote(name),
        type: unquote(type),
        default: unquote(opts)[:default],
        private: unquote(opts)[:private] == true,
        cast_func: unquote(opts)[:cast_func]
      })
    end
  end

  defmacro embeds_one(name, type) do
    quote do
      Module.put_attribute(__MODULE__, :struct_fields, {unquote(name), nil})

      Module.put_attribute(__MODULE__, :schema_embeds, %{
        name: unquote(name),
        many: false,
        one: true,
        type: unquote(type)
      })
    end
  end

  defmacro embeds_many(name, type) do
    quote do
      Module.put_attribute(__MODULE__, :struct_fields, {unquote(name), []})

      Module.put_attribute(__MODULE__, :schema_embeds, %{
        name: unquote(name),
        many: true,
        one: false,
        type: unquote(type)
      })
    end
  end
end
