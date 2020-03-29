defmodule ScrabbleEx.Board do
  defstruct [:state, :size]

  defimpl Jason.Encoder, for: [__MODULE__] do
    # encode map into indexed list of squares/tiles
    def encode(struct, opts) do
      max = struct.size * struct.size - 1

      Jason.Encode.list(
        0..max |> Enum.map(&map_term(struct.state[&1])),
        opts
      )
    end

    defp map_term(nil), do: %{}
    defp map_term(a) when is_atom(a), do: %{bonus: "#{a}"}
    defp map_term(c) when is_binary(c), do: %{character: c}
  end

  def standard_str do
    "3w .  .  2l .  .  .  3w .  .  .  2l .  .  3w " <>
      ".  2w .  .  .  3l .  .  .  3l .  .  .  2w .  " <>
      ".  .  2w .  .  .  2l .  2l .  .  .  2w .  .  " <>
      "2l .  .  2w .  .  .  2l .  .  .  2w .  .  2l " <>
      ".  .  .  .  2w .  .  .  .  .  2w .  .  .  .  " <>
      ".  3l .  .  .  3l .  .  .  3l .  .  .  3l .  " <>
      ".  .  2l .  .  .  2l .  2l .  .  .  2l .  .  " <>
      "3w .  .  2l .  .  .  2w .  .  .  2l .  .  3w " <>
      ".  .  2l .  .  .  2l .  2l .  .  .  2l .  .  " <>
      ".  3l .  .  .  3l .  .  .  3l .  .  .  3l .  " <>
      ".  .  .  .  2w .  .  .  .  .  2w .  .  .  .  " <>
      "2l .  .  2w .  .  .  2l .  .  .  2w .  .  2l " <>
      ".  .  2w .  .  .  2l .  2l .  .  .  2w .  .  " <>
      ".  2w .  .  .  3l .  .  .  3l .  .  .  2w .  " <>
      "3w .  .  2l .  .  .  3w .  .  .  2l .  .  3w"
  end

  def standard do
    parse(standard_str)
  end

  def parse(str) do
    str
    |> String.split(~r/\s+/)
    |> Enum.reject(&(&1 == ""))
    |> Enum.with_index()
    |> Enum.map(fn {a, b} -> {b, parse_fragment(a)} end)
    |> Enum.into(%{})
  end

  defp parse_fragment("2l"), do: :double_letter
  defp parse_fragment("3l"), do: :triple_letter
  defp parse_fragment("2w"), do: :double_word
  defp parse_fragment("3w"), do: :triple_word
  defp parse_fragment("."), do: nil
  # FIXME: match on length
  defp parse_fragment(f), do: f

  def new() do
    new(15, standard)
  end

  def new(size, map) do
    %__MODULE__{size: size, state: map}
  end

  # don't use this method to compare for uniqueness, use word_maps instead
  def words(board) do
    word_maps(board)
    |> Enum.map(fn word_map ->
      text_for(board, word_map)
    end)
  end

  def text_for(board, word_map) do
    word_map
    |> Enum.map(&board.state[&1])
    |> Enum.join()
  end

  def word_maps(board) do
    max = board.size * board.size - 1

    starts =
      0..max
      # words may start here
      |> Enum.filter(fn i -> is_binary(board.state[i]) end)
      |> Enum.reduce([], fn i, acc ->
        size = board.size
        x = rem(i, size)
        y = div(i, size)

        # _ _ _ _ _ _ _ _ _ a b c _ _ _
        # 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4
        col_offset_max = size - x - 1
        col_count_max = size - x

        acc =
          cond do
            x == 0 || (x > 0 && x < size - 1 && !is_binary(board.state[i - 1])) ->
              # IO.puts("finding horizontal i=#{i} x=#{x}")
              indexes =
                Stream.iterate(i, &(&1 + 1))
                |> Enum.take_while(fn ix ->
                  # IO.puts(" >> ix=#{ix} #{board.state[ix]}")
                  # same row, and is letter
                  div(ix, size) == y && is_binary(board.state[ix])
                end)

              [indexes | acc]

            true ->
              acc
          end

        overflow_index = size * size

        acc =
          cond do
            y == 0 || (y > 0 && y < size - 1 && !is_binary(board.state[i - size])) ->
              # IO.puts("finding vertical i=#{i} y=#{y}")
              indexes =
                Stream.iterate(i, &(&1 + 15))
                |> Enum.take_while(fn iy ->
                  y < overflow_index && is_binary(board.state[iy])
                end)

              [indexes | acc]

            true ->
              acc
          end

        acc
      end)
      |> Enum.filter(fn
        [x] -> false
        _ -> true
      end)
  end
end
