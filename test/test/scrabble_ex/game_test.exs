defmodule ScrabbleEx.GameTest do
  use ExUnit.Case, async: true
  alias ScrabbleEx.{Game, Board}

  setup do
    game = Game.new(players: ["zach", "kate"])
    %{game: game}
  end

  test "new", %{game: _game} do
  end

  test "first play does not cross center", %{game: game} do
    result =
      Game.play(game, "zach", %{
        {0, 0} => "a",
        {0, 1} => "a",
        {0, 2} => "a"
      })

    assert {:error, "does not cross center"} = result
  end

  test "first play only one letter", %{game: game} do
    result =
      Game.play(game, "zach", %{
        112 => "a"
      })

    assert {:error, "not long enough"} = result
  end

  test "diagonal", %{game: game} do
    result =
      Game.play(game, "zach", %{
        112 => "a",
        128 => "b",
        144 => "c"
      })

    assert {:error, "word is not linear"} = result
  end

  test "discontinuous", %{game: game} do
    result =
      Game.play(game, "zach", %{
        112 => "a",
        127 => "b",
        157 => "c"
      })

    assert {:error, "word is not continuous"} = result
  end

  # FIXME: check real word
  test "first play ok" do
    letter_cache = ~w[
      j o k e s x v o k e r s q z t n a l e b b
    ]
    game = Game.new(players: ["zach", "kate"], board: Board.new(), letter_cache: letter_cache)

    result =
      Game.play(game, "zach", %{
        52 => "j",
        67 => "o",
        82 => "k",
        97 => "e",
        112 => "s"
      })

    assert {:ok, %Game{scores: scores, board: %{state: state} = board} = game} = result
    # IO.puts inspect(ScrabbleEx.Board.words(board))
    assert %{52 => "j", 67 => "o", 82 => "k", 97 => "e", 112 => "s"} = state
    assert %{"zach" => [[{"jokes", 48}]]} = scores

    result =
      Game.play(game, "kate", %{
        53 => "o",
        54 => "k",
        55 => "e",
        56 => "r",
        57 => "s"
      })

    assert {:ok, %Game{scores: scores, board: %{state: state} = board} = game} = result
    # IO.puts inspect(ScrabbleEx.Board.words(board))
    assert %{52 => "j", 53 => "o", 54 => "k", 55 => "e", 56 => "r", 57 => "s"} = state
    assert %{"kate" => [[{"jokers", 34}]]} = scores

    result =
      Game.play(game, "zach", %{
        38 => "t",
        68 => "n",
        83 => "a",
        98 => "l"
      })

    assert {:ok, %Game{scores: scores, board: %{state: state} = board} = game} = result
    # IO.puts inspect(ScrabbleEx.Board.words(board))
    assert %{38 => "t", 53 => "o", 68 => "n", 83 => "a", 98 => "l"} = state

    assert %{
             "zach" => [
               [{"el", 3}, {"ka", 6}, {"on", 2}, {"tonal", 7}],
               [{"jokes", 48}]
             ]
           } = scores
  end
end
