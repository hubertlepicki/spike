defmodule Test.TypeTestForm do
  use Spike.Form do
    field(:name, :string)
    field(:age, :integer)
    field(:accepts_conditions, :boolean)
    field(:dob, :date)
    field(:inserted_at, :utc_datetime)
  end
end
