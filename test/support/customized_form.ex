defmodule Test.CustomizedForm do
  use Spike.FormData do
    field(:name, :string)
  end

  @impl true
  def new(_params, meta) do
    super(%{jack: :black}, meta)
  end
end
