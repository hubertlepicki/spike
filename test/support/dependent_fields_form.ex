defmodule Test.DependentForm do
  use Spike.Form do
    field(:accept_all, :boolean, default: false)
    field(:accept_one, :boolean, default: false)
    field(:accept_two, :boolean, default: false)
    field(:accept_three, :boolean, default: false)
  end

  def after_update(_form_before, form_after, _fields) do
    form_after
    |> maybe_toggle_accept_all()
  end

  defp maybe_toggle_accept_all(form) do
    if form.accept_one && form.accept_two && form.accept_three && !form.accept_all do
      form
      |> Map.put(:accept_all, true)
    else
      if form.accept_all && (!form.accept_one || !form.accept_two || !form.accept_three) do
        form
        |> Map.merge(%{accept_one: true, accept_two: true, accept_three: true})
      else
        form
        |> Map.put(:accept_all, false)
      end
    end
  end
end
