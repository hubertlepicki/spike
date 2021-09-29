defmodule Test.ComplexFormData do
  defmodule CompanyForm do
    use Spike.FormData

    define_schema do
      field(:name, :string)
      field(:country, :string)
    end

    validates(:name, presence: true)
  end

  defmodule PartnerForm do
    use Spike.FormData

    define_schema do
      field(:name, :string)
    end
  end

  use Spike.FormData

  define_schema do
    field(:accepts_conditions, :boolean)
    embeds_one(:company, __MODULE__.CompanyForm)
    embeds_many(:partners, __MODULE__.PartnerForm)
  end

  validates(:company, presence: true)
  validates(:accepts_conditions, acceptance: true)
end
