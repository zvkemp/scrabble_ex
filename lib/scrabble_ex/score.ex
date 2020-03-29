defmodule ScrabbleEx.Score do
  alias ScrabbleEx.{Game, Board}

  def score(board, new_board, letter_map) do
    words_to_score = Board.word_maps(new_board) -- Board.word_maps(board)

    scores =
      words_to_score
      |> Enum.map(fn word ->
        text = Board.text_for(new_board, word)

        letter_total =
          word
          |> Enum.reduce(0, fn idx, acc ->
            acc + letter_bonus(board.state[idx]) * value(new_board.state[idx])
          end)

        word_multiplier =
          word
          |> Enum.reduce(1, fn idx, acc ->
            acc * word_bonus(board.state[idx])
          end)

        [text, letter_total * word_multiplier]
      end)

    # BINGO
    scores =
      cond do
        Enum.count(letter_map) == 7 -> [["*", 50] | scores]
        true -> scores
      end

    {:ok, scores}
  end

  defp letter_bonus(:double_letter), do: 2
  defp letter_bonus(:triple_letter), do: 3
  defp letter_bonus(_), do: 1

  defp word_bonus(:double_word), do: 2
  defp word_bonus(:triple_word), do: 3
  defp word_bonus(_), do: 1

  defp value("A"), do: 1
  defp value("B"), do: 3
  defp value("C"), do: 3
  defp value("D"), do: 2
  defp value("E"), do: 1
  defp value("F"), do: 4
  defp value("G"), do: 2
  defp value("H"), do: 4
  defp value("I"), do: 1
  defp value("J"), do: 8
  defp value("K"), do: 5
  defp value("L"), do: 1
  defp value("M"), do: 3
  defp value("N"), do: 1
  defp value("O"), do: 1
  defp value("P"), do: 3
  defp value("Q"), do: 10
  defp value("R"), do: 1
  defp value("S"), do: 1
  defp value("T"), do: 1
  defp value("U"), do: 1
  defp value("V"), do: 4
  defp value("W"), do: 4
  defp value("X"), do: 8
  defp value("Y"), do: 4
  defp value("Z"), do: 10
end
