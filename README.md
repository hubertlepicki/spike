# Readme

[Spike](https://github.com/hubertlepicki/spike) helps you build stateul,
server-memory backed forms in Elixir.

If you are struggling with making deep nested Ecto changesets back your forms
the way you like it, you may have ended up in a right place.

## Installation

[Available in Hex](https://hex.pm/packages/spike), the package can be installed
by adding `spike` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:spike, "~> 0.2"}
  ]
end
```

Documentation can be found on [HexDocs](https://hexdocs.pm/spike).

## Usage

Spike can be used on it's own, or with
[Phoenix LiveView](https://github.com/phoenixframework/phoenix_live_view) /
[Surface UI](https://surface-ui.org/).

Basic usage consists on creating an Elixir module, which represents your form
and stores both: data, that the user can manipulate using UI controls
(via LiveView or otherwise), and data that is necessary for the form to be
rendered and displayed to user.

Spike's [LiveView bindings](https://github.com/hubertlepicki/spike-liveview) or
[Surface UI bindings](https://github.com/hubertlepicki/spike-surface) can be
used together with this core library to extend live views or components with
out-of-the box support for `@form` and `@errors`, as well as default
implementation of events handling, to build

Spike forms are based on Elixir structs, that declare fields, associations and
validations - similar to Ecto schemas or ActiveRecord models. These forms,
however, live entirely in the memory. Let's consider a registration form. We
have to define a module, with fields and validations:

```
defmodule MyApp.RegistrationForm do
  use Spike.Form do
    field(:first_name, :string)
    field(:last_name, :string)
    field(:age, :integer)
    field(:email, :string)
    field(:accepts_conditions, :boolean, default: false)
  end

  validates(:first_name, presence: true)
  validates(:accepts_conditions, acceptance: true)
end
```


form = MyApp.RegistrationForm.new(%{})
Spike.valid?(form)
=> false
Spike.errors(form)[form.ref]
=> %{accepts_conditions: [acceptance: "must be accepted"], first_name: [presence: "must be present"]}

See the documentation to `Spike`, `Spike.Form`
and `Spike.Form.Schema` modules for API usage and examples.

For more complete example have a look at the tutorial available on [spike-liveview documentation](https://hexdocs.pm/spike-liveview/tutorial.html).

