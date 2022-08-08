defmodule Test.SimpleForm do
  use Spike.Form do
    field(:first_name, :string)
    field(:last_name, :string)
    field(:age, :integer)
    field(:email, :string)
    field(:accepts_conditions, :boolean)
  end

  validates(:first_name, presence: true)
  validates(:accepts_conditions, acceptance: true)
end
