defmodule ScrabbleEx.GameTest do
  use ExUnit.Case, async: true
  alias ScrabbleEx.Game

  setup do
    game = Game.new(players: ["zach", "kate"])
    %{game: game}
  end

  test "new", %{game: _game} do
  end

  test "first play does not cross center", %{game: game} do
    result = Game.play(game, "zach", %{
      {0, 0} => "a",
      {0, 1} => "a",
      {0, 2} => "a",
    })

    assert {:error, "does not cross center"} = result
  end

  test "first play only one letter", %{game: game} do
    result = Game.play(game, "zach", %{
      112 => "a",
    })

    assert {:error, "not long enough"} = result
  end

  test "diagonal", %{game: game} do
    result = Game.play(game, "zach", %{
      112 => "a",
      128 => "b",
      144 => "c",
    })

    assert {:error, "word is not linear"} = result
  end

  test "discontinuous", %{game: game} do
    result = Game.play(game, "zach", %{
      112 => "a",
      127 => "b",
      157 => "c",
    })

    assert {:error, "word is not continuous"} = result
  end

  # FIXME: check real word
  test "first play ok", %{game: game} do
    result = Game.play(game, "zach", %{
      112 => "a",
      113 => "b",
      114 => "c",
    })

    assert {:ok, %Game{scores: scores, board: %{state: state} = board}} = result
    # IO.puts inspect(ScrabbleEx.Board.words(board))
    assert %{112 => "a", 113 => "b", 114 => "c"} = state
    assert %{"zach" => [[{"abc", 14}]]} = scores
  end
end
