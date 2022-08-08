# Spike tutorial

In this chapter we will build a signup form, similar to one we would see
on any SAAS product. The new user will be able to provide their email address
and password, company name, choose subdomain (with autosuggestion) and invite a
number of colleagues to join at the same time.

This will demonstrate how to:

1. Install Spike and use it with LiveView
2. Test-drive your forms logic, entirely in Elixir
3. Build custom forms UI
4. Validate forms
5. Nested forms
6. Nested forms validations

## 1. Generate new Phoenix project

First, make sure you have recent version of Phoenix Framework generator
installed, and install it if you don't:

```
$ mix archive.install hex phx_new
```

We will generate new Phoenix project, that will not use Ecto, because our form
for this tutorial is going to be entirely memory-backed:

```
$ mix phx.new --no-ecto signup && cd signup
```

We also need to edit `mix.exs` to add `spike` and `spike_liveview` dependencies:

```
  defp deps do
    [
      {:phoenix, "~> 1.6.11"},
      {:phoenix_html, "~> 3.0"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 0.17.5"},
      ...
      {:spike_liveview, "~> 0.1"}, # <- add this line
      {:spike, "~> 0.1"} # <- add this line as well
    ]
  end
```

...and install the new dependencies:

```
$ mix deps.get
```

The last thing we need to do is to create a dedicated type of LiveView we will
use for LiveViews that use Spike forms, we'll need to add the following to `lib/signup_web.ex`:

```
  def form_live_view do
    quote do                                                                                  
      use Phoenix.LiveView,
        layout: {SignupWeb.LayoutView, "live.html"}
                                               
      unquote(view_helpers()) 
                                                                                              
      use Spike.LiveView.FormLiveView # <-- this line is important
    end
  end
```

## 2. Test drive your form

### Basic usage

We will start with a signup form that holds only one field: `:company_name`, and
for that we will need to crate the following `lib/signup/signup_form.ex` module:

```
defmodule Signup.SignupForm do
  use Spike.FormData do
    field(:company_name, :string)
  end
end
```

If you launch `iex -S mix` now, you will be able to see that the above created a
struct that is pretty useful already, that can be initialized to values using
it's `new/1` function and allows to retrieve the held values in it's struct keys:

```
$ iex -S mix
```

```
iex(1)> form = Signup.SignupForm.new(%{"company_name" => "ACME Corp."})
%Signup.SignupForm{
  __dirty_fields: [],
  company_name: "ACME Corp.",
  ref: "14b7dadb-8120-49a4-887f-f35350b377d0"
}
iex(2)> form.company_name                                              
"ACME Corp."
iex(3)> form.ref
"14b7dadb-8120-49a4-887f-f35350b377d0"
iex(4)>
```

The `company_name` key in the struct we all expected, but what is `ref`? Spike
autogenerates `ref` key for each and every struct, and it will be useful later
to reference nested structs - i.e. forms within forms, as we see later in this
chapter.

We will also use `ref` key to point LiveView components to appropriate field,
and use it whenever we have to manually update values from our LiveViews and
LiveComponents alike. From the terminal we can set the new value for
`:company_name` as well, using `Spike.update/3`:

```
iex(5)> form = Spike.update(form, form.ref, %{"company_name" => "Amazon"})
%Signup.SignupForm{
  __dirty_fields: [:company_name],
  company_name: "Amazon",
  ref: "975e0541-b978-4db3-8ea1-b3ac6fa461b6"
}
iex(6)> form.company_name
"Amazon"
```

You will *rarely* have to use `Spike.update/3` directly, for the most part this
is part of the `:form_live_view` variant we introduced earlier in our views, but
if you want to test the forms in isolation it will come in handy.

Note that `Spike.update/3` is also updates `:__dirty_fields__`, which is then
used by `Spike.dirty_fields/1` for dirty tracking.

Now that we know how to do basics, let's write a simple test in
`test/signup/signup_form_test.exs`:

```
defmodule Signup.SignupFormTest do
  use ExUnit.Case

  alias Signup.SignupForm

  describe "setting values" do
    setup do
      {:ok, [form: SignupForm.new(%{})]}
    end

    test "allows setting form values", %{form: form} do
      assert form.company_name == nil
      form = Spike.update(form, form.ref, %{company_name: "ACME Corp."})
      assert form.company_name == "ACME Corp."
    end
  end
end
```

Let's run it:

```
$ mix test
.

Finished in 0.06 seconds (0.00s async, 0.06s sync)
1 test, 0 failures

Randomized with seed 842063
```

Sweet.

### Default and private values

Spike allows you to define default and private field values for your forms. We
will use both of these mechanisms now, while implementing a plan chooser on our
signup form.

We want to epose to the end user (via the future LiveView) list of available
plans, allow them to choose a plan, default it to first plan on the list *and
prevent updating the list of plans or modifying them in any way*.


The desired behavior of `form.available_plans` is as follows:

```
  describe "form.available_plans" do
    @available_plans [
      %{id: 1, name: "Starter", price: 0, max_users: 1},
      %{id: 2, name: "Growth", price: 1, max_users: 5},
      %{id: 3, name: "Enterprise", price: 9000, max_users: :infinity}
    ]

    setup do
      {:ok, form: SignupForm.new(%{available_plans: @available_plans}, cast_private: true)}
    end

    test "should be pre-filled with a list of available plans as found at given time", %{form: form} do
      assert form.available_plans == @available_plans
    end

    test "should be read-only and disallow updates", %{form: form} do
      form = Spike.update(form, form.ref, %{available_plans: [%{id: 1, name: "Hacked", price: 0, available_users: :infinity}]})
      assert form.available_plans == @available_plans
    end
  end
```

As you can see, we now initialize our form with `Spike.FormData.new/2` function,
and pass `cast_private: true` as options to it. This will allow us to set
private fields, because by default they are not being initialized from the first
argument - `params`.

If we run the tests now, they will complain the field is not there:

```
  1) test form.available_plans should be read-only and disallow updates (Signup.SignupFormTest)                                                                                              
     test/signup/signup_form_test.exs:33                                                                                                                                                     
     ** (KeyError) key :available_plans not found in: %Signup.SignupForm{company_name: nil, ref: "511b1719-e92c-4ae3-8177-d3f0f113f111"}
     code: assert form.available_plans == @available_plans
     stacktrace:
       test/signup/signup_form_test.exs:35: (test)



  2) test form.available_plans should be pre-filled with a list of available plans as found at given time (Signup.SignupFormTest)
     test/signup/signup_form_test.exs:29
     ** (KeyError) key :available_plans not found in: %Signup.SignupForm{company_name: nil, ref: "71fadb31-feaa-4e38-99f3-bcba3ec22622"}
     code: assert form.available_plans == @available_plans
     stacktrace:
       test/signup/signup_form_test.exs:30: (test)
```

Let's fix it by adding the key to our form struct:

```
defmodule Signup.SignupForm do
  use Spike.FormData do
    field(:company_name, :string)
    field(:available_plans, {:list, :map}, private: true) # <-- add this line
  end
end
```

What's the output of `mix test` now?

```
Compiling 1 file (.ex)
...

Finished in 0.03 seconds (0.00s async, 0.03s sync)
3 tests, 0 failures

Randomized with seed 216825
```

Nice. If you remove `private: true` attribute from the field definition above,
the second test will turn red, however. Remember that `private: true` is
*required on all fields that the end user should not be able to update*.
Everythign else is free for all.

Spike also comes with `default` option on field definitions, so, if the list of
plans is static and never changes, and doesn't come from the database, we could
have written our form this way:

```
defmodule Signup.SignupForm do
  @available_plans [
    %{id: 1, name: "Starter", price: 0, max_users: 1},
    %{id: 2, name: "Growth", price: 1, max_users: 5},
    %{id: 3, name: "Enterprise", price: 9000, max_users: :infinity}
  ]

  use Spike.FormData do
    field(:company_name, :string)
    field(:available_plans, {:array, :map}, default: @available_plans, private: true)
  end
end
```

and in `iex -S mix` we can test that it would need no initialization in `new/2`
callback:

```
%Signup.SignupForm{
  __dirty_fields: [],
  available_plans: [
    %{id: 1, max_users: 1, name: "Starter", price: 0},
    %{id: 2, max_users: 5, name: "Growth", price: 1},
    %{id: 3, max_users: :infinity, name: "Enterprise", price: 9000}
  ],
  company_name: nil,
  ref: "c9441ffb-7fea-4de6-8d85-8636a8d424c7"
}
```

But we will stick to the first version as, in reality, the plans would usually
come from database or external API.

Either way, we also need to allow the user to choose the plan, so we will need
`plan_id` field:

```
defmodule Signup.SignupForm do
  use Spike.FormData do
    field(:company_name, :string)
    field(:available_plans, {:array, :map}, private: true)
    field(:plan_id, :integer) # <-- add this line, note :integer
  end
end
```

Let's modify the test to make sure this key exists on our form struct and we can
actually use it:

```
  describe "setting values" do
    setup do
      {:ok, form: SignupForm.new(%{available_plans: @available_plans}, cast_private: true)}
    end

    test "allows setting form values", %{form: form} do
      assert form.company_name == nil
      assert form.plan_id == nil
      form = Spike.update(form, form.ref, %{company_name: "ACME Corp."})
      assert form.company_name == "ACME Corp."
      form = Spike.update(form, form.ref, %{plan_id: "1"})
      assert form.plan_id == 1
    end
  end
```

Note that we're casting a `String` to `Integer` above. Spike currently uses
[tarams](https://github.com/bluzky/tarams) for data casting, and you can use any
of the [data types it
supports](https://github.com/bluzky/tarams/blob/master/lib/type.ex).

The test should pass now and we have a form with two fields that the user can
set, but no UI an no validations just yet. Let's fix these two problems.

## 3. Build custom forms UI

### Basic usage with LiveView

Spike comes with two very tiny bindings a
[spike_liveview](https://github.com/hubertlepicki/spike-liveview) and
[spike_surface](https://github.com/hubertlepicki/spike-surface). We will use the
first one, and use plain LiveView in this tutorial. The usage of Surface UI
bindings is analogous and do not require much changes.

Let's start by introducing a `lib/signup_web/signup_live.ex` LiveView.
`spike_liveview` expects the LiveViews to define `:form_data` and `:errors`
assigns. The first one holds our struct with data, the second one is used to
display validation errors, and can be initialized with `Spike.errors/1`:

```
defmodule SignupWeb.SignupLive do
  use SignupWeb, :form_live_view # <- note we defined it in signup_web.ex

  def mount(_params, _, socket) do
    form_data = init_form_data()

    {:ok,
     socket
     |> assign(%{
       success: false,
       form_data: form_data, # <- this is required by :form_live_view
       errors: Spike.errors(form_data) # <- this as well needs to be set
     })}
  end

  def render(assigns) do
    ~H"""
    <h2>Example signup form:</h2>
    <hr/>
    <h4>Debug info</h4>
    Form data:
    <pre>
      <%= inspect @form_data, pretty: true %>
    </pre>
    Errors:
    <pre>
      <%= inspect @errors, pretty: true %>
    </pre>
    Success:
    <pre>
      <%= inspect @success, pretty: true %>
    </pre>
    """
  end

  defp init_form_data do
    Signup.SignupForm.new(%{available_plans: find_plans()}, cast_private: true)
  end

  defp find_plans() do
    [
      %{id: 1, name: "Starter", price: 0, max_users: 1},
      %{id: 2, name: "Growth", price: 1, max_users: 5},
      %{id: 3, name: "Enterprise", price: 9000, max_users: :infinity}
    ]
  end
end

```

Now we only need to mount the LiveView in `lib/signup_web/router.ex`:

```
  scope "/", SignupWeb do
    pipe_through :browser

    get "/", PageController, :index
    live "/signup", SignupLive # <-- add this line
  end
```

Start the app with `iex -S mix phx.server` and point your browser to
`http://localhost:4000/signup`. You should see the following:

![Initial page with no form controls but debug information visible](3_1.png
"Initial page with no form controls but debug information visible")

### Creating form fields for data input

[spike_liveview](https://github.com/hubertlepicki/spike-liveview) does *not* come with
ready to use form builder, as this task seems futile with so many different
HTML structures you may require your form to comply to. Instead, we ship only with
high level
[Spike.Liveview.FormField](https://github.com/hubertlepicki/spike-liveview/blob/main/lib/spike/live_view/form_field.ex)
and
[Spike.LiveView.Erorrs](https://github.com/hubertlepicki/spike-liveview/blob/main/lib/spike/live_view/errors.ex)
and you should be a real programmer and build your own form helpers ;).

Let's do just that and add a couple of componnets and use them to display the
form input with label:

```
defmodule SignupWeb.SignupLive do
  ...

  def label_component(%{ref: _ref, text: _text, key: _key} = assigns) do
    ~H"""
    <label for={"#{@ref}_#{@key}"}><%= @text %></label>
    """
  end

  def input_component(%{type: "text", key: _, form_data: _, label: _} = assigns) do
    ~H"""
    <div>
      <.label_component text={@label} ref={@form_data.ref} key={@key} />

      <Spike.LiveView.FormField.form_field key={@key} form_data={@form_data}>
        <input id={"#{@form_data.ref}_#{@key}"} name="value" type="text" value={@form_data |> Map.get(@key)} />
      </Spike.LiveView.FormField.form_field>
    </div>
    """
  end

  ...

  def render(assigns) do
    ~H"""
    <h2>Example signup form:</h2>

    <.input_component type="text" key={:company_name} form_data={@form_data} label="Company name:" />

    <hr/>
    <h4>Debug info</h4>
    Form data:
  
  ...
```

This should give you a text input field, with label and when you enter some
value you will see the corresponding key in the form struct updated as well:

![Company name form input](3_1.png "Company name form input")

Similarly, we will need a `<select>` to be generated for `:plan_id` fields,
let's add appropriate helper component and use it:

```
  ...

  def input_component(%{type: "select", key: _, form_data: _, options: _} = assigns) do
    ~H"""
    <div>
      <.label_component text={@label} ref={@form_data.ref} key={@key} />

      <Spike.LiveView.FormField.form_field key={@key} form_data={@form_data}>
        <select id={"#{@form_data.ref}_#{@key}"} name="value">
          <%= for {value, text} <- @options do %>
            <option value={value || ""} selected={@form_data |> Map.get(@key) == value}><%= text %></option>
          <% end %>
        </select>
      </Spike.LiveView.FormField.form_field>
    </div>
    """
  end

  def render(assigns) do
    ~H"""
    <h2>Example signup form:</h2>

    <.input_component type="text" key={:company_name} form_data={@form_data} label="Company name:" />
    <.input_component type="select" key={:plan_id} form_data={@form_data} label="Choose your plan:" options={plan_options(@form_data)} />

    ...
    """
  end

  # returns a list of tuples that can be passed as options to component above
  defp plan_options(form_data) do
    [{nil, "Please select..."}] ++
      Enum.map(form_data.available_plans, fn plan ->
        {plan.id, "#{plan.name} (#{plan.price} USD / month)"}
      end)
  end
  ...
```

## 6. Validate forms

Spike uses currently [Vex](https://github.com/cargosense/vex) to add validations
to form structs. We expect the LiveView of LiveComponent to have `@errors`
assign set to result of `Spike.errors/1` call. If you remember, we are already
doing that in our `mount` function:

```
  def mount(_params, _, socket) do
    form_data = init_form_data()

    {:ok,
     socket
     |> assign(%{
       success: false,
       form_data: form_data,
       errors: Spike.errors(form_data) # <- this generates map with errors
     })}
  end
```

Spike will also automaticallhy generate new errors map after each user
interaction [by
stealth](https://github.com/hubertlepicki/spike-liveview/blob/main/lib/spike/live_view/form_live_view.ex#L51)
in `handle_event` callback it adds by default to LiveViews and LiveComponents.

If you are going to perform handling of custom events, or overwrite the default
callback, you will have to set `@errors` assign yourself.

Let's add validations to our form fields, starting with appropriate tests:

```
  describe "form validations" do
    setup do
      {:ok, form: SignupForm.new(%{available_plans: @available_plans}, cast_private: true)}
    end

    test "should require company_name and plan_id", %{form: form} do
      errors = Spike.errors(form)
      assert errors[form.ref][:company_name][:presence] == "must be present"
      assert errors[form.ref][:plan_id][:presence] == "must be present"
    end

    test "should validate plan_id is one of defined available_plans", %{form: form} do
      form = Spike.update(form, form.ref, %{plan_id: 1000})

      errors = Spike.errors(form)
      assert errors[form.ref][:plan_id][:by] == "is not an available plan"
    end
  end
```

As you can see, `Spike.errors/1` takes form struct as a parameter and returns
map of maps, where the top level keys are `refs` of structs that constitute our
form. In our case we just have one for now, but when we nest form structs, we
will have more and a need to quick assess to nested errors.

The validations using `Vex` need to be added to our form:

```
defmodule Signup.SignupForm do
  use Spike.FormData do
    field(:company_name, :string)
    field(:available_plans, {:array, :map}, private: true)
    field(:plan_id, :integer)
  end

  validates :company_name, presence: true
  validates(:plan_id, presence: true, by: &__MODULE__.validate_plan_id/2)

  def validate_plan_id(nil, _form_data), do: :ok

  def validate_plan_id(value, form_data) do
    form_data.available_plans
    |> Enum.map(& &1.id)
    |> Enum.member?(value)
    |> if do
      :ok
    else
      {:error, "is not an available plan"}
    end
  end
end
```

If we run our tests will pass, but we also need to alter our component helpers
to take another option: `:errors` from assigns, and render the errors to the
user *if and only if the field is considered dirty*.

Spike tracks user interactions, and marks fields touched by the user as "dirty".
The default `Errors` low-level component that we will now use, does only return
errors on `dirty` fields: https://github.com/hubertlepicki/spike-liveview/blob/main/lib/spike/live_view/errors.ex#L23

Let's start by passing `@erorrs` to components we already built:

```
    <.input_component type="text" key={:company_name} form_data={@form_data} label="Company name:" errors={@errors} />
    <.input_component type="select" key={:plan_id} form_data={@form_data} label="Choose your plan:" options={plan_options(@form_data)} errors={@errors} />
```

We also need to write our component helper to display field errors:

```
  def errors_component(%{form_data: _, key: _, errors: _} = assigns) do
    ~H"""
    <Spike.LiveView.Errors.errors let={field_errors} key={@key} form_data={@form_data} errors={@errors}>
      <span class="error">
        <%= field_errors |> Enum.map(fn {_k, v} -> v end) |> Enum.join(", ") %>
      </span>
    </Spike.LiveView.Errors.errors>
    """
  end
```

And finally use it:

```
  def input_component(%{type: "text", key: _, form_data: _, label: _, errors: _} = assigns) do
    ~H"""
    <div>
      <.label_component text={@label} ref={@form_data.ref} key={@key} />

      <Spike.LiveView.FormField.form_field key={@key} form_data={@form_data}>
        <input id={"#{@form_data.ref}_#{@key}"} name="value" type="text" value={@form_data |> Map.get(@key)} />
      </Spike.LiveView.FormField.form_field>

      <!-- Added the line below -->
      <.errors_component form_data={@form_data} key={@key} errors={@errors} />
    </div>
    """
  end

  def input_component(%{type: "select", key: _, form_data: _, options: _, errors: _} = assigns) do
    ~H"""
    <div>
      <.label_component text={@label} ref={@form_data.ref} key={@key} />

      <Spike.LiveView.FormField.form_field key={@key} form_data={@form_data}>
        <select id={"#{@form_data.ref}_#{@key}"} name="value">
          <%= for {value, text} <- @options do %>
            <option value={value || ""} selected={@form_data |> Map.get(@key) == value}><%= text %></option>
          <% end %>
        </select>
      </Spike.LiveView.FormField.form_field>

      <!-- Added the line below -->
      <.errors_component form_data={@form_data} key={@key} errors={@errors} />
    </div>
    """
  end
```

If we interact with the form now, you will see that if you edit text field for
company name, and then remove the value, you will get an error message now
displayed to the user. The same will happen if you select a plan and then
deselect it. But with all the excitement about building and validating the form,
we forgot about adding "Submit button". Let's fix it by adding a custom event to
our liveview, and making the whole form dirty if validation fails. If it passes,
we will set a success message instead.

Our rendering function needs addtional clause to handle successful form submit,
and also addition of mentioned button:

```
  # add this 
  def render(%{success: true} = assigns) do
    ~H"""
    <h2>Signup successful!</h2>
    """
  end

  def render(assigns) do
    ~H"""
    <h2>Signup form:</h2>
 
    <.input_component type="text" key={:company_name} form_data={@form_data} label="Company name:" errors={@errors} />
    <.input_component type="select" key={:plan_id} form_data={@form_data} label="Choose your plan:" options={plan_options(@form_data)} errors={@errors} />

    <!-- Add this button to submit form -->
    <a href="#" class="button" phx-click="submit">Submit</a>

    ...

    """
  end
```

We also need a callback to handle form submits:

```
  def handle_event("submit", _, socket) do
    if socket.assigns.errors == %{} do
      # perform business logic of signing up company here
      {:noreply, socket |> assign(:success, true)} # <-- settig to true to display success page
    else
      {:noreply, socket |> assign(:form_data, Spike.make_dirty(socket.assigns.form_data))} # <- note
    end
  end
```

Note that in case of validations failure, we're making the whole form, all
fields - including nested ones - dirty by calling `Spike.make_dirty/1`. This
will tell our default errors component to return the list of all validation
errors, no matter if user touched the form or not. You can use
`Spike.make_pristine/1` to mark all of the struct as pristine, clearing the
dirty tracking.

## 5. Nested forms

This section needs expanding.

Forms can be nested. Check out expanded version of the signup from from this
tutorial in
[spike_examples](https://github.com/hubertlepicki/spike_example/blob/main/lib/spike_example/signup_form.ex)
for reference.

## 6. Nested forms validations

This section needs expanding.

Nested form validations are supported, where one part of the form can access
other (parent, child or a sibling alike) using `Spike.validation_context/1`
function. For example check out the validation of email address fields on
[SpikeExample.SignupForm.Coworker
form](https://github.com/hubertlepicki/spike_example/blob/main/lib/spike_example/signup_form/coworker.ex#L18).

## 7. More comprehensive example

Check out [SpikeExample app](https://github.com/hubertlepicki/spike_example) for more complete usage.

