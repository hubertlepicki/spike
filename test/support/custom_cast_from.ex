defmodule Test.CustomCastForm do
  use Spike.Form do
    field(:age, :string, cast_func: {__MODULE__, :cast_age})
  end

  def cast_age(value) do
    {:ok, "#{value}"}
  end
end
