defmodule Test.CustomizedForm do
  use Spike.FormData do
    field(:name, :string)
  end

  @impl true
  def new(_params, meta) do
    super(%{jack: :black}, meta)
  end

  @impl true
  def to_params(_) do
    %{elo: :ziom}
  end
end
