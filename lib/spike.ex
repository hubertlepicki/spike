defmodule Spike do
  @moduledoc """
  This module contains top-level functions useful to validate, manipulate and inspect
  Spike forms.

  To learn about how to create Spike forms, see `Spike.Form`.
  """

  @doc """
  Given a Spike form, returns a map of errors, where fields are refs of all
  forms that build the form, and each field is a list of errors.

  Returns empty map in case the form is valid.

      iex> form = Test.SimpleForm.new(%{})
      iex> Spike.errors(form)[form.ref]
      %{accepts_conditions: [acceptance: "must be accepted"], first_name: [presence: "must be present"]}
      iex> form = Spike.update(form, form.ref, %{first_name: "Spike", last_name: "Spiegel", accepts_conditions: "1"})
      iex> Spike.errors(form)
      %{}
      iex> form = Test.ComplexForm.new(%{company: %{}, partners: []})
      iex> Spike.errors(form)
      %{form.company.ref => %{name: [presence: "must be present"]}, form.ref => %{accepts_conditions: [acceptance: "must be accepted"]}}

  """
  defdelegate errors(form), to: Spike.Form

  @doc """
  Returns true if given form has no errors.

      iex> form = Test.SimpleForm.new(%{})
      iex> Spike.valid?(form)
      false
      iex> form = Spike.update(form, form.ref, %{first_name: "Spike", last_name: "Spiegel", accepts_conditions: "1"})
      iex> Spike.valid?(form)
      true

  """
  def valid?(form) do
    errors(form) == %{}
  end


  @doc """
  Given a Spike form, returns a map of errors, where fields are Strings
  representing where in nested set of forms errors happened and values are errors.

  Returns empty map in case the form is valid.

      iex> form = Test.ComplexForm.new(%{company: %{}, partners: [%{}]})
      iex> Spike.human_readable_errors(form)
      %{"accepts_conditions" => ["must be accepted"], "company.name" => ["must be present"]}

  """
  defdelegate human_readable_errors(form), to: Spike.Form


  @doc """
  Given a Spike form, returns a map of fields that have been updated since the
  form form was created, or since the last time `Spike.make_pristine/1` was
  called.

      iex> form = Test.SimpleForm.new(%{first_name: "Spike", last_name: "Spiegel"})
      iex> Spike.dirty_fields(form)
      %{}
      iex> form = Spike.update(form, form.ref, %{first_name: "Jet", last_name: "Black"})
      iex> Spike.dirty_fields(form)
      %{form.ref => [:first_name, :last_name]}
      iex> form = Spike.make_pristine(form)
      iex>  Spike.dirty_fields(form)
      %{}

  """
  defdelegate dirty_fields(form), to: Spike.Form

  @doc """
  Given Spike form, marks all of it's fields as dirty, recursively.

      iex> form = Test.ComplexForm.new(%{company: %{}, partners: [%{}]})
      iex> form = Spike.make_dirty(form)
      iex> Spike.dirty_fields(form)
      %{
         form.ref => [:accepts_conditions, :company, :partners],
         form.company.ref => [:country, :name],
         hd(form.partners).ref => [:name]
       }

  """
  defdelegate make_dirty(form), to: Spike.Form

  @doc """
  Given a dirty Spike form, makes it pristine, recursively.

      iex> form = Test.ComplexForm.new(%{company: %{}, partners: [%{}]})
      iex> form = Spike.make_dirty(form)
      iex> form = Spike.make_pristine(form)
      iex> Spike.dirty_fields(form)
      %{}

  """
  defdelegate make_pristine(form), to: Spike.Form

  @doc """
  Updates a Spike form, by finding a nested form by it's `ref` field, with given params.
  Marks updated fields as dirty.

      iex> form = Test.ComplexForm.new(%{company: %{name: "ACME Corp."}, partners: [%{}]})
      iex> form.company.name
      "ACME Corp."
      iex> form = Spike.update(form, form.company.ref, %{name: "Amazon"})
      iex> form.company.name
      "Amazon"
      iex> Spike.dirty_fields(form)
      %{form.company.ref => [:name], form.ref => [:company]}

  """
  defdelegate update(form, ref, params), to: Spike.Form

  @doc """
  Updates `embeds_many` association on given Spike form, appending the new item at the end
  of the existing list.

      iex> form = Test.ComplexForm.new(%{company: %{name: "ACME Corp."}, partners: []})
      iex> form.partners
      []
      iex> form = Spike.append(form, form.ref, :partners, %{name: "Hubert"})
      iex> form.partners |> Enum.map(& &1.name)
      ["Hubert"]
      iex> form = Spike.append(form, form.ref, :partners, %{name: "Wojciech"})
      iex> form.partners |> Enum.map(& &1.name)
      ["Hubert", "Wojciech"]

  """
  defdelegate append(form, ref, field, params), to: Spike.Form

  @doc """
  Deletes a form from a Spike form by it's `ref`. Useful to remove items from `embeds_many` or `embeds_one`.

      iex> form = Test.ComplexForm.new(%{company: %{name: "ACME Corp."}, partners: [%{name: "John"}]})
      iex> form = Spike.delete(form, form.company.ref)
      iex> form = Spike.delete(form, form.partners |> hd() |> Map.get(:ref))
      iex> form.company
      nil
      iex> form.partners
      []

  """
  defdelegate delete(form, ref), to: Spike.Form

  @doc """
  Allows you to update fields in a Spike form that were marked as private.

      iex> form = Test.PrivateForm.new(%{private_field: "foo"}, cast_private: true)
      iex> form = Spike.update(form, form.ref, %{private_field: "bar"})
      iex> form.private_field
      "foo"
      iex> form = Spike.set_private(form, form.ref, :private_field, "bar")
      iex> form.private_field
      "bar"

  """
  defdelegate set_private(form, ref, field, value), to: Spike.Form


  @doc """
  Returns `true` if given form, identified by `ref` has error on given `field`.

      iex> form = Test.SimpleForm.new(%{first_name: "Jet", accepts_conditions: "0"})
      iex> Spike.has_errors?(form, form.ref, :first_name)
      false
      iex> Spike.has_errors?(form, form.ref, :accepts_conditions)
      true

  """
  defdelegate has_errors?(form, ref, field), to: Spike.ErrorHelpers

  @doc """
  Returns `true` if given form, identified by `ref` has specified error message
  on given `field`.

      iex> form = Test.SimpleForm.new(%{first_name: "Jet", accepts_conditions: "0"})
      iex> Spike.has_errors?(form, form.ref, :accepts_conditions, "must be accepted")
      true
      iex> Spike.has_errors?(form, form.ref, :accepts_conditions, "is invalid")
      false

  """
  defdelegate has_errors?(form, ref, field, message), to: Spike.ErrorHelpers

  @doc """
  This function should only be used from within "by" validations, where context
  of parent forms is required. The first element of returned list will be
  the top-level form, followed by association name, and another form (if present)
  followed by assciation name etc.

  This is useful when in a child form you want to perform a validation that relies
  on value that lives in a parent form or a sibling in `embeds_many`.
  """
  def validation_context(form) do
    form
    |> Spike.Form.ValidationContext.get_validation_context()
    |> case do
      list when list != [] > 0 ->
        list |> Enum.reverse() |> tl() |> Enum.reverse()

      otherwise ->
        otherwise
    end
  end
end
