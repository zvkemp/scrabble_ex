defmodule ScrabbleEx.Score do
  alias ScrabbleEx.{Game, Board}

  def score(board, new_board) do
    words_to_score = Board.word_maps(new_board) -- Board.word_maps(board)
    words_to_score |> Enum.map(fn word ->
      text = Board.text_for(new_board, word)
      letter_total = word
                     |> Enum.reduce(0, fn idx, acc ->
                       acc + (letter_bonus(board.state[idx]) * value(new_board.state[idx]))
                     end)

      word_multiplier = word
                        |> Enum.reduce(1, fn (idx, acc) ->
                          acc * word_bonus(board.state[idx])
                        end)

      {text, letter_total * word_multiplier}
    end)
  end

  defp letter_bonus(:double_letter), do: 2
  defp letter_bonus(:triple_letter), do: 3
  defp letter_bonus(_), do: 1

  defp word_bonus(:double_word), do: 2
  defp word_bonus(:triple_word), do: 3
  defp word_bonus(_), do: 1

  defp value("a"), do: 1
  defp value("b"), do: 3
  defp value("c"), do: 3
  defp value("d"), do: 2
  defp value("e"), do: 1
  defp value("f"), do: 4
  defp value("g"), do: 2
  defp value("h"), do: 4
  defp value("i"), do: 1
  defp value("j"), do: 8
  defp value("k"), do: 5
  defp value("l"), do: 1
  defp value("m"), do: 3
  defp value("n"), do: 1
  defp value("o"), do: 1
  defp value("p"), do: 3
  defp value("q"), do: 10
  defp value("r"), do: 1
  defp value("s"), do: 1
  defp value("t"), do: 1
  defp value("u"), do: 1
  defp value("v"), do: 4
  defp value("w"), do: 4
  defp value("x"), do: 8
  defp value("y"), do: 4
  defp value("z"), do: 10
end
