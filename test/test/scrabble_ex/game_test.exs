defmodule ScrabbleEx.GameTest do
  use ExUnit.Case, async: true
  alias ScrabbleEx.{Game, Board}

  setup do
    {:ok, game} = Game.new(players: ["zach", "kate"]) |> Game.start()
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

  test "first play with blanks" do
    bag = ~w[
      BLANK BLANK O E S X V O K E R S Q Z T N A L E B B
    ]

    {:ok, game} =
      Game.new(players: ["zach", "kate"], board: Board.new(), bag: bag)
      |> Game.start()

    result =
      Game.play(game, "zach", %{
        52 => ":J",
        67 => "O",
        82 => ":K",
        97 => "E",
        112 => "S"
      })

    assert {:ok, %Game{scores: scores, board: %{state: state} = board} = game} = result
    assert %{52 => ":J", 67 => "O", 82 => ":K", 97 => "E", 112 => "S"} = state
    assert %{"zach" => [[["JOKES", 6]]]} = scores
  end

  test "first play ok" do
    bag = ~w[
      J O K E S X V O K E R S Q Z T N A L E B B
    ]

    {:ok, game} =
      Game.new(players: ["zach", "kate"], board: Board.new(), bag: bag)
      |> Game.start()

    result =
      Game.play(game, "zach", %{
        52 => "J",
        67 => "O",
        82 => "K",
        97 => "E",
        112 => "S"
      })

    assert {:ok, %Game{scores: scores, board: %{state: state} = board} = game} = result
    # IO.puts inspect(ScrabbleEx.Board.words(board))
    assert %{52 => "J", 67 => "O", 82 => "K", 97 => "E", 112 => "S"} = state
    assert %{"zach" => [[["JOKES", 48]]]} = scores

    result =
      Game.play(game, "kate", %{
        53 => "O",
        54 => "K",
        55 => "E",
        56 => "R",
        57 => "S"
      })

    assert {:ok, %Game{scores: scores, board: %{state: state} = board} = game} = result
    # IO.puts inspect(ScrabbleEx.Board.words(board))
    assert %{52 => "J", 53 => "O", 54 => "K", 55 => "E", 56 => "R", 57 => "S"} = state
    assert %{"kate" => [[["JOKERS", 34]]]} = scores

    result =
      Game.play(game, "zach", %{
        38 => "T",
        68 => "N",
        83 => "A",
        98 => "L"
      })

    assert {:ok, %Game{scores: scores, board: %{state: state} = board} = game} = result
    # IO.puts inspect(ScrabbleEx.Board.words(board))
    assert %{38 => "T", 53 => "O", 68 => "N", 83 => "A", 98 => "L"} = state

    assert %{
             "zach" => [
               [["EL", 3], ["KA", 6], ["ON", 2], ["TONAL", 7]],
               [["JOKES", 48]]
             ]
           } = scores
  end
end
