# Spike

[Spike](https://github.com/hubertlepicki/spike) is a data casting and
validation library that can make building complex and long-living
server-memory backed forms in Elixir easier.

If you are struggling with making deep nested Ecto changesets back your forms
the way you like it, you may have ended up in a right place.

## Installation

[Available in Hex](https://hex.pm/packages/spike), the package can be installed
by adding `spike` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:spike, "~> 0.1.0"}
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
out-of-the box support for `@form_data` and `@errors`, as well as default
implementation of events handling, to build

See [our tutorial](tutorial.md) for a complete walkthrough of adding and using
Spike, including more advanced features.

