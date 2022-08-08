defmodule Test.ContextualValidationsForm do
  def items() do
    [%{id: 1, price: 1}, %{id: 2, price: 10}, %{id: 3, price: 3}]
  end

  defmodule LineItem do
    use Spike.Form do
      field(:price, :integer)

      validates(:price, by: &__MODULE__.validate_price_within_budget/2)
    end

    def validate_price_within_budget(_price, this_line_item) do
      [parent, :line_items] = Spike.validation_context(this_line_item)

      sum =
        parent.line_items
        |> Enum.reduce_while(0, fn line_item, acc ->
          if line_item.ref == this_line_item.ref do
            {:halt, acc + line_item.price}
          else
            {:cont, acc + line_item.price}
          end
        end)

      if parent.max_budget && sum > parent.max_budget do
        {:error, "exceeds max budget of #{parent.max_budget}"}
      else
        :ok
      end
    end
  end

  use Spike.Form do
    field(:max_budget, :integer)
    embeds_many(:line_items, __MODULE__.LineItem)
  end
end
