defmodule ScrabbleEx.Persistence.Term do
  use Ecto.Type

  def type, do: :binary

  # def cast(bin) when is_binary(bin) do
  #   IO.puts("cast term")
  #   {:ok, bin |> :erlang.binary_to_term()}
  # end

  def cast(term) do
    {:ok, term}
  end

  def load(bin) do
    term = bin |> :erlang.binary_to_term()

    term =
      cond do
        is_struct(term) ->
          # Merge with an empty struct to get possibly-new fields
          Map.merge(struct(term.__struct__), term)

        true ->
          term
      end

    {:ok, term}
  end

  # FIXME: handle nested structs?
  # Better to just use a JSON encoder? If so, how to handle different serializers for DB and frontend?
  defp upgrade_struct(term) when is_struct(term) do
    term = struct(term.__struct__) |> Map.merge(term)
  end

  defp upgrade_struct(term), do: term

  def dump(term) do
    {:ok, :erlang.term_to_binary(term)}
  end
end
