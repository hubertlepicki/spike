defmodule Spike.Form.ValidationContext do
  @moduledoc false

  import Spike.Form.ETS

  @doc false
  def get_validation_context(%{ref: ref} = _struct) do
    get_validation_context(ref)
  end

  @doc false
  def get_validation_context(ref) do
    :validation_context
    |> ensure_initialized()
    |> :ets.lookup(ref)
    |> case do
      [{_ref, list}] -> list
      [] -> []
    end
  end

  @doc false
  def put_validation_context(%{ref: ref} = struct, validation_context) do
    put_validation_context(ref, validation_context)
    struct
  end

  @doc false
  def put_validation_context(ref, validation_context) do
    :validation_context
    |> ensure_initialized()
    |> :ets.insert({ref, validation_context})

    ref
  end

  @doc false
  def purge_validation_context() do
    :validation_context
    |> purge_table()
  end
end
