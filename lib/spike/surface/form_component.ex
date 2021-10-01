defmodule Spike.Surface.FormComponent do
  defmacro __using__(_opts) do
    quote do
      use Surface.LiveComponent

      data(form_data, :struct)
      data(dirty_fields, :map, default: %{})
      data(errors, :map, default: %{})

      @before_compile unquote(__MODULE__)
    end
  end

  defmacro __before_compile__(env) do
    [quoted_handle_event(env)]
  end

  defp quoted_handle_event(env) do
    if Module.defines?(env.module, {:handle_event, 3}) do
      quote do
        defoverridable handle_event: 3

        def handle_event("spike-form-event:" <> _ = event, args, socket) do
          try do
            super(event, args, socket)
          rescue
            _e in FunctionClauseError ->
              {:noreply, Spike.Surface.FormComponent.handle_event(event, args, socket)}
          end
        end

        def handle_event(event, args, socket) do
          super(event, args, socket)
        end
      end
    else
      quote do
        def handle_event(event, args, socket) do
          {:noreply, Spike.Surface.FormComponent.handle_event(event, args, socket)}
        end
      end
    end
  end

  def handle_event(
        "spike-form-event:set-value",
        %{"ref" => ref, "key" => key, "value" => value},
        socket
      ) do
    form =
      socket.assigns.form_data
      |> Spike.update(ref, %{key => value})

    socket
    |> Phoenix.LiveView.assign(%{
      form_data: form,
      errors: Spike.errors(form),
      dirty_fields: Spike.dirty_fields(form)
    })
  end
end
