defmodule Test.ComplexFormDataWithCallbacks do
  defmodule CompanyFormData do
    use Spike.FormData do
      field(:name, :string)
      field(:country, :string)
    end

    validates(:name, presence: true)
  end

  defmodule PartnerFormData do
    use Spike.FormData do
      field(:name, :string)
    end

    def after_update(struct_before, struct_after, changed_fields) do
      if :name in changed_fields do
        IO.puts(
          "updated #{struct_before.ref}, name changed from #{struct_before.name} to #{struct_after.name}"
        )
      end

      struct_after
    end
  end

  use Spike.FormData do
    field(:accepts_conditions, :boolean)
    embeds_one(:company, __MODULE__.CompanyFormData)
    embeds_many(:partners, __MODULE__.PartnerFormData)
  end

  validates(:company, presence: true)
  validates(:accepts_conditions, acceptance: true)

  def after_update(struct_before, struct_after, changed_fields) do
    if :partners in changed_fields do
      IO.inspect("updated #{struct_before.ref}, changed partners")
    end

    struct_after
  end
end
