defmodule Test.ComplexFormData do
  defmodule CompanyFormData do
    use Spike.FormData

    form_fields do
      field(:name, :string)
      field(:country, :string)
    end

    validates(:name, presence: true)
  end

  defmodule PartnerFormData do
    use Spike.FormData

    form_fields do
      field(:name, :string)
    end
  end

  use Spike.FormData

  form_fields do
    field(:accepts_conditions, :boolean)
    embeds_one(:company, __MODULE__.CompanyFormData)
    embeds_many(:partners, __MODULE__.PartnerFormData)
  end

  validates(:company, presence: true)
  validates(:accepts_conditions, acceptance: true)
end
