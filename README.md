# Readme

[Spike](https://github.com/hubertlepicki/spike) simplifies the process of creating and using forms in Elixir/Phoenix/LiveView/Surface UI that are not backed or not mapped directly to database tables.

If you are struggling with making deeply nested forms work with Ecto Changesets, this library may be for you.

## Installation

[Available in Hex](https://hex.pm/packages/spike), the package can be installed
by adding `spike` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:spike, "~> 0.3"}
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
rendered and displayed to user or validated on the server.

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

```
form = MyApp.RegistrationForm.new(%{})
Spike.valid?(form)
=> false
Spike.errors(form)[form.ref]
=> %{accepts_conditions: [acceptance: "must be accepted"], first_name: [presence: "must be present"]}
```

See the documentation for `Spike`, `Spike.Form`,
and `Spike.Form.Schema` modules for usage and examples.

For more complete example of usage with LiveView and Surface UI, have a look at our [example application](https://spikeexample.fly.dev/).

