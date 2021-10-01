defmodule Spike.Surface.Errors do
  use Surface.Component

  prop(errors, :map, required: true)
  prop(dirty_fields, :map, required: true)
  prop(form_data, :struct, required: true)
  prop(key, :atom, required: true)

  slot(default, args: [:field_errors])

  def render(assigns) do
    if field_errors(assigns) != [] do
      ~F"""
        <#slot :args={field_errors: field_errors(assigns)} />
      """
    else
      ~F"""
      """
    end
  end

  defp field_errors(%{errors: errors, form_data: form_data, key: key, dirty_fields: dirty_fields}) do
    if errors[form_data.ref] && errors[form_data.ref] |> Map.get(key) &&
         dirty_fields[form_data.ref] && key in dirty_fields[form_data.ref] do
      errors[form_data.ref][key]
    else
      []
    end
  end
end
