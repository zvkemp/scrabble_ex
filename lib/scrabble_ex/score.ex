defmodule ScrabbleEx.Score do
  alias ScrabbleEx.Board

  import Enum, only: [count: 1, at: 2]

  def score(board, new_board, letter_map) do
    words_to_score = Board.word_maps(new_board) -- Board.word_maps(board)

    # if there's only 1 word, it must be longer than the letters played (validate connected)
    word_count = Enum.count(words_to_score)

    crosses_center = Board.crosses_center?(board, letter_map)

    if word_count == 0 ||
         (!crosses_center && word_count == 1 &&
            count(at(words_to_score, 0)) <= count(letter_map)) do
      {:error, "word is not connected"}
    else
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
        if Enum.count(letter_map) == 7 do
          [["*", 50] | scores]
        else
          scores
        end

      {:ok, scores}
    end
  end

  def valid_score(board, new_board, letter_map) do
    case score(board, new_board, letter_map) do
      {:ok, _} = scores -> validate_words(scores)
      {:error, _} = e -> e
    end
  end

  def score_rack(rack) do
    Enum.reduce(rack, 0, &(&2 + value(&1)))
  end

  defp validate_words({:ok, words_with_scores}) do
    real_words =
      Enum.map(words_with_scores, fn [word, _] -> word end)
      |> ScrabbleEx.Dictionary.show_legal_words()

    # real_words =
    #   Enum.reduce(words_with_scores, %{}, fn [word, _], acc ->
    #     Map.put(acc, word, ScrabbleEx.Dictionary.word?(word))
    #   end)

    if Enum.all?(real_words, fn
         # BINGO
         {"*", _} -> true
         {_, x} -> x
       end) do
      {:ok, words_with_scores}
    else
      not_words =
        real_words
        |> Enum.filter(fn {_, x} -> !x end)
        |> Enum.map(fn {w, _} -> String.upcase(w) end)
        |> Enum.join(", ")

      {:miss, "these are not words: #{not_words}"}
    end
  end

  defp letter_bonus(:double_letter), do: 2
  defp letter_bonus(:triple_letter), do: 3
  defp letter_bonus(:quad_letter), do: 4
  defp letter_bonus(_), do: 1

  defp word_bonus(:double_word), do: 2
  defp word_bonus(:triple_word), do: 3
  defp word_bonus(:quad_word), do: 4
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
  defp value(":" <> _c), do: 0
end
