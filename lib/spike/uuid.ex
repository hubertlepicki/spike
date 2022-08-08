defmodule Spike.UUID do
  @moduledoc false
  @doc false
  def generate() do
    UUID.uuid4()
  end
end
