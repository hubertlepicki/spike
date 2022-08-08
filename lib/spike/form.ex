defmodule Spike.Form do
  @moduledoc """
  Use this module to define your Spike forms.

  ## Simple use cases

  Simple Spike form, with no validation and no nested structs will look like this:

      defmodule MyApp.RegistrationForm do
        use Spike.Form do
          field(:first_name, :string)
          field(:last_name, :string)
          field(:age, :integer)
          field(:email, :string)
          field(:accepts_conditions, :boolean)
        end
      end

      form = MyApp.RegistrationForm.new(%{first_name: "Spike"})
      form = Spike.update(form, form.ref, %{last_name: "Spiegel"})
      form.first_name
      => "Spike"
      form.last_name
      => "Spiegel"

  ## Adding validations

  Spike uses [Vex](https://github.com/cargosense/vex) as a validation library, so you can add
  form validations easily:

      defmodule MyApp.RegistrationForm do
        use Spike.Form do
          field(:first_name, :string)
          field(:last_name, :string)
          field(:age, :integer)
          field(:email, :string)
          field(:accepts_conditions, :boolean)
        end

        validates(:first_name, presence: true)
        validates(:accepts_conditions, acceptance: true)
      end

      form = MyApp.RegistrationForm.new(%{})
      Spike.valid?(form)
      => false
      Spike.errors(form)[form.ref]
      => %{accepts_conditions: [acceptance: "must be accepted"], first_name: [presence: "must be present"]}

  ## Nested forms with contextual validations

  You can have nested forms, supproting nested validations as well, where child item can
  access parent or sibling items by fetching validation context using `Spike.validation_context/1`.

      defmodule MyApp.BudgetPlanner do
        defmodule LineItem do
          use Spike.Form do
            field(:price, :integer)
            field(:name, :string)

            validates(:name, presence: true)
            validates(:price, presence: true, by: &__MODULE__.validate_price_within_budget/2)
          end

          def validate_price_within_budget(_price, this_line_item) do
            [parent, :line_items] = Spike.validation_context(this_line_item)

            sum =
              parent.line_items
              |> Enum.reduce_while(0, fn line_item, acc ->
                if line_item.ref == this_line_item.ref do
                  {:halt, acc + line_item.price}
                else
                  {:cont, acc + line_item.price}
                end
              end)

            if parent.max_budget && sum > parent.max_budget do
              {:error, "exceeds max budget of #\{parent.max_budget\}"}
            else
              :ok
            end
          end
        end

        use Spike.Form do
          field(:max_budget, :integer)
          embeds_many(:line_items, __MODULE__.LineItem)
        end
      end

  For functions useful to manipulate forms, see [Spike]. For schema definition look
  into `Spike.Form.Schema`.

  To initialize a Spike form, by casting a map to it's fields (recursively), you can use
  `new/1` callback.

      form = MyApp.BudgetPlanner.new(%{max_budget: 12, line_items: [%{name: "Cheap one", price: 1}]})
      Spike.valid?(form)
      => true
      form = Spike.append(form, form.ref, :line_items, %{name: "Expensive one", price: 9000})
      Spike.valid?(form)
      => false
      Spike.human_readable_errors(form)
      => %{"line_items.1.price" => ["exceeds max budget of 12"]}

  In case you need to cast fields marked as private, use `new/2` where second parameter
  is `[cast_private: true]`.
  """

  @callback new(params :: map) :: map
  @callback new(params :: map, options :: keyword) :: map
  @callback after_update(struct_before :: term, struct_after :: term, changed_fields :: list) ::
              term

  @optional_callbacks new: 1, new: 2, after_update: 3

  defmacro __using__(do: block) do
    quote location: :keep do
      @behaviour Spike.Form

      require Spike.Form
      use Vex.Struct

      import Spike.Form.Schema

      Module.register_attribute(__MODULE__, :struct_fields, accumulate: true)
      Module.register_attribute(__MODULE__, :schema_fields, accumulate: true)
      Module.register_attribute(__MODULE__, :schema_embeds, accumulate: true)

      unquote(block)

      field(:ref, :string, private: true)
      field(:__dirty_fields__, {:array, :atom}, private: true, default: [])

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

      def new(params, options \\ []) do
        %__MODULE__{}
        |> Spike.Form.cast(params, cast_private: Keyword.get(options, :cast_private, false))
        |> Map.put_new(:ref, Spike.UUID.generate())
      end

      def after_update(_struct_before, struct_after, _changed_fields) do
        struct_after
      end

      defoverridable new: 1, new: 2, after_update: 3
    end
  end

  import Spike.Form.{DirtyFields, ValidationContext}

  @doc false
  def cast(struct, params, options \\ []) do
    params =
      (params || %{})
      |> Mappable.to_map(keys: :strings, shallow: true)

    casted_params =
      params
      |> Tarams.cast!(
        tarams_schema_definition(
          struct.__struct__,
          Map.keys(params),
          Keyword.get(options, :cast_private, false)
        )
      )
      |> Mappable.to_map(keys: :atoms, shallow: true)

    struct
    |> ensure_has_ref()
    |> Map.merge(casted_params)
    |> cast_embeds(embeds(struct), params, options)
  end

  defp tarams_schema_definition(mod, param_fields, cast_private) do
    mod.__schema_fields__()
    |> Enum.filter(&(&1.private == false || cast_private))
    |> Enum.filter(&("#{&1.name}" in param_fields))
    |> Enum.map(fn definition ->
      {definition.name, [type: definition.type, default: definition.default]}
    end)
    |> Enum.into(%{})
  end

  @doc false
  def update(%{ref: ref} = struct, ref, params) do
    update(struct, params)
  end

  @doc false
  def update(struct, ref, params) do
    update_embeds(struct, ref, params, embeds(struct))
  end

  defp update(struct, params) do
    struct_before = struct

    struct_after =
      struct
      |> cast(params)

    updated_fields = updated_fields(struct_before, struct_after)
    dirty_fields = get_dirty_fields(struct) ++ updated_fields

    struct.__struct__.after_update(
      struct_before,
      put_dirty_fields(struct_after, dirty_fields),
      updated_fields
    )
  end

  defp updated_fields(struct_before, struct_after) do
    struct_before
    |> MapDiff.diff(struct_after)
    |> case do
      %{changed: :equal} ->
        []

      diff ->
        diff
        |> Map.get(:value)
        |> Enum.filter(fn {_k, %{changed: changed}} ->
          changed != :equal
        end)
        |> Enum.into(%{})
        |> Map.keys()
    end
  end

  @doc false
  def append(%{ref: ref} = struct, ref, field, params) do
    append(struct, field, params)
  end

  @doc false
  def append(struct, ref, field, params) do
    append_embeds(struct, ref, field, params, embeds(struct))
  end

  @doc false
  defp append(struct, field, params) do
    %{many: true, type: mod} = embed(struct, field)

    current_structs = Map.get(struct, field)
    dirty_fields = get_dirty_fields(struct) ++ [field]

    new_child =
      case params do
        %{ref: _ref} = fd when is_struct(fd) ->
          params

        _ ->
          mod.new(params)
      end

    put_dirty_fields(
      %{
        struct
        | field => current_structs ++ [new_child]
      },
      dirty_fields
    )
  end

  @doc false
  def make_dirty(struct) do
    dirty_fields = fields(struct) ++ embeds(struct)

    struct
    |> put_dirty_fields(dirty_fields)
    |> make_embeds_dirty(embeds(struct))
  end

  @doc false
  def make_pristine(struct) do
    struct
    |> put_dirty_fields([])
    |> make_embeds_pristine(embeds(struct))
  end

  @doc false
  def errors(struct) do
    struct
    |> traverse_structs(&get_errors/1, [])
    |> List.flatten()
    |> Enum.filter(& &1)
    |> Enum.into(%{})
  end

  @doc false
  def human_readable_errors(struct) do
    struct
    |> traverse_struct_paths([], &get_human_readable_errors/1, [])
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

  @doc false
  def dirty_fields(struct) do
    struct
    |> traverse_structs(&get_dirty_fields/1, [])
    |> List.flatten()
    |> Enum.filter(& &1)
    |> Enum.into(%{})
  end

  @doc false
  def delete(%{ref: ref} = _struct, ref) do
    nil
  end

  @doc false
  def delete(struct, ref) do
    {struct, dirty_embeds} = delete_embeds(struct, ref, embeds(struct), [])

    struct
    |> put_dirty_fields(get_dirty_fields(struct) ++ dirty_embeds)
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

  defp cast_embeds(form, [], _params, _options), do: form

  defp cast_embeds(form, [h | t], params, options) do
    if Map.keys(params) |> Enum.member?("#{h}") do
      form
      |> cast_embed(embed(form, h), params["#{h}"], options)
    else
      form
    end
    |> cast_embeds(t, params, options)
  end

  defp cast_embed(form, %{one: true} = embed, %{__struct__: _} = new_struct, _options) do
    form
    |> Map.put(embed.name, new_struct)
  end

  defp cast_embed(form, %{one: true} = embed, map, options) do
    form
    |> Map.put(embed.name, embed.type.new(map, options))
  end

  defp cast_embed(form, %{many: true} = _embed, nil, _options), do: form

  defp cast_embed(form, %{many: true} = embed, [], _options),
    do: form |> Map.put(embed.name, [])

  defp cast_embed(form, %{many: true} = embed, list, options) do
    form
    |> Map.put(
      embed.name,
      Enum.map(list, fn
        %{__struct__: _} = new_struct -> new_struct
        map -> embed.type.new(map, options)
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

  defp traverse_structs(nil, _callback, _context_so_far), do: []

  defp traverse_structs(list, callback, context_so_far) when is_list(list) do
    list
    |> Enum.map(&traverse_structs(&1, callback, context_so_far))
  end

  defp traverse_structs(current_struct, callback, context_so_far) do
    context_so_far = context_so_far ++ [current_struct]
    collected = callback.(put_validation_context(current_struct, context_so_far))

    ret =
      if Enum.count(collected) > 0 do
        [{current_struct.ref, collected}]
      else
        []
      end ++
        (embeds(current_struct)
         |> Enum.map(fn embed ->
           traverse_structs(Map.get(current_struct, embed), callback, context_so_far ++ [embed])
         end))

    if context_so_far == [current_struct] do
      purge_validation_context()
    end

    ret
  end

  defp traverse_struct_paths(nil, _, _callback, _context_so_far), do: []

  defp traverse_struct_paths(list, path, callback, context_so_far) when is_list(list) do
    list
    |> Enum.with_index()
    |> Enum.map(fn {val, index} ->
      traverse_struct_paths(val, path ++ ["#{index}"], callback, context_so_far)
    end)
  end

  defp traverse_struct_paths(current_struct, path, callback, context_so_far) do
    context_so_far = context_so_far ++ [current_struct]
    collected = callback.(put_validation_context(current_struct, context_so_far))

    if Enum.count(collected) > 0 do
      [{path, collected}]
    else
      []
    end ++
      (embeds(current_struct)
       |> Enum.map(fn embed ->
         traverse_struct_paths(
           Map.get(current_struct, embed),
           path ++ ["#{embed}"],
           callback,
           context_so_far ++ [embed]
         )
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
      dirty_fields = get_dirty_fields(updated_struct) ++ [embed]

      struct.__struct__.after_update(struct, put_dirty_fields(updated_struct, dirty_fields), [
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

  @doc false
  def set_private(%{ref: ref} = form, ref, field, value) do
    %{form | field => value}
  end

  @doc false
  def set_private(form, ref, field, value) do
    set_embeds_private(form, ref, field, value, embeds(form))
  end

  defp set_embeds_private(struct, _ref, _field, _value, []), do: struct

  defp set_embeds_private(struct, ref, field, value, [embed | rest]) do
    embed_field = Map.get(struct, embed)

    case embed_field do
      nil ->
        set_embeds_private(struct, ref, field, value, rest)

      list when is_list(list) ->
        %{struct | embed => Enum.map(embed_field, &set_private(&1, ref, field, value))}
        |> set_embeds_private(ref, field, value, rest)

      _ ->
        %{struct | embed => set_private(embed_field, ref, field, value)}
        |> set_embeds_private(ref, field, value, rest)
    end
  end
end
