defmodule Spike.FormData.ETS do
  def ensure_initialized(table_name) do
    table_name
    |> get_ets_reference()
    |> case do
      nil ->
        table_reference = :ets.new(table_name, [:set, :private])
        Process.put(:"spike_ets_#{table_name}", table_reference)
        table_reference

      reference ->
        reference
    end
  end

  def purge_table(table_name) do
    table_name
    |> get_ets_reference()
    |> case do
      nil ->
        :ok

      table_reference ->
        :ets.delete(table_reference)
        Process.delete(:"spike_ets_#{table_name}")
        :ok
    end
  end

  defp get_ets_reference(table_name) do
    Process.get(:"spike_ets_#{table_name}")
  end
end
