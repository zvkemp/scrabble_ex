defmodule ScrabbleEx.Persistence.Term do
  use Ecto.Type

  def type, do: :binary

  # def cast(bin) when is_binary(bin) do
  #   IO.puts("cast term")
  #   {:ok, bin |> :erlang.binary_to_term()}
  # end

  def cast(term) do
    IO.puts("cast term 2")
    {:ok, term}
  end

  def load(bin) do
    {:ok, bin |> :erlang.binary_to_term()}
  end

  def dump(term) do
    {:ok, :erlang.term_to_binary(term)}
  end
end
