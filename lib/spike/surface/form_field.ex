defmodule Spike.Surface.FormField do
  use Surface.Component

  prop(form_data, :struct, required: true)
  prop(key, :atom, required: true)
  prop(target, :any, required: false, default: nil)
  prop(submit_event, :string, required: false, default: "submit")

  slot(default)

  @impl true
  def render(assigns) do
    ~F"""
    <form phx-change="spike-form-event:set-value" phx-target={@target} phx-submit={@submit_event}>      
      <input name="ref" type="hidden" value={@form_data.ref} />
      <input name="key" type="hidden" value={@key} />
      <#slot />
    </form>
    """
  end
end
