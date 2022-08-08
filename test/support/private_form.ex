defmodule Test.PrivateForm do
  use Spike.Form do
    field(:public_field, :string)
    field(:private_field, :string, private: true)
    field(:meta, :map, private: true, default: %{})
    embeds_one(:subform, __MODULE__.Subform)
  end

  defmodule Subform do
    use Spike.Form do
      field(:public_field, :string)
      field(:private_field, :string, private: true)
    end
  end
end
