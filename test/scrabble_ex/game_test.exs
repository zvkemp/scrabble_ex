defmodule ScrabbleEx.GameTest do
  use ExUnit.Case, async: true
  alias ScrabbleEx.{Game, Repo}
  import Enum, only: [sort: 1, map: 2]

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    id = :crypto.strong_rand_bytes(6) |> Base.encode64()

    {:ok, game} =
      Game.new(id, players: ["zach", "kate"], start_at: 0)
      |> Game.start()

    %{game: game}
  end

  test "first play does not cross center", %{game: game} do
    rack = game.racks["zach"]

    result = Game.play(game, "zach", Enum.zip([1, 2, 3], rack) |> Enum.into(%{}))

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

  @tag :focus
  test "first play after swap" do
    bag = ~w[
      J O K E S X V O K E R S Q Z T N A L E B B
    ]

    {:ok, game} =
      Game.new("foo", players: ["zach", "kate"], bag: bag, start_at: 1)
      |> Game.start()

    {:ok, game} = Game.swap(game, "kate", %{"1" => "O", "2" => "K"})

    assert(game.current_player == "zach")

    assert {:ok, game} =
             result =
             Game.play(game, "zach", %{
               52 => "J",
               67 => "O",
               82 => "K",
               97 => "E",
               112 => "S"
             })

    # assert result.current_player == "kate"
  end

  test "first play with blanks" do
    bag = ~w[
      BLANK BLANK O E S X V O K E R S Q Z T N A L E B B
    ]

    {:ok, game} =
      Game.new("id", players: ["zach", "kate"], bag: bag, start_at: 0)
      |> Game.start()

    Game.propose(game, "zach", %{
      "52" => ":J",
      "67" => "O",
      "82" => ":K",
      "97" => "E",
      "112" => "S"
    })

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
      Game.new("foo", players: ["zach", "kate"], bag: bag, start_at: 0)
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

  test "lose a turn" do
    bag = ~w[
      J O K E S X V O K E R S Q Z T N A L E B B
    ]

    {:ok, game} =
      Game.new("foo", players: ["zach", "kate"], bag: bag, start_at: 0)
      |> Game.start()

    result =
      Game.play(game, "zach", %{
        52 => "J",
        67 => "O",
        82 => "K",
        97 => "E",
        112 => "X"
      })

    assert {:error, "these are not words: JOKEX",
            %Game{scores: scores, board: %{state: state} = board} = game} = result

    assert game.current_player == "zach"
    assert game.referee.tries_remaining == 2

    result =
      Game.play(game, "zach", %{
        52 => "J",
        67 => "O",
        82 => "X",
        97 => "E",
        112 => "S"
      })

    assert {:error, "these are not words: JOXES",
            %Game{scores: scores, board: %{state: state} = board} = game} = result

    assert game.current_player == "zach"
    assert game.referee.tries_remaining == 1

    result =
      Game.play(game, "zach", %{
        52 => "S",
        67 => "O",
        82 => "X",
        97 => "E",
        112 => "J"
      })

    assert {:error, :next_player,
            "these are not words: SOXEJ; You have exhausted three tries. Lose a turn!",
            %Game{scores: scores, board: %{state: state} = board} = game} = result

    assert game.current_player == "kate"
    assert game.referee.tries_remaining == 3
  end

  test "remaining letters", %{game: game} do
    remaining_letters = Game.remaining_letters(game) |> sort
    standard = Game.counts(:standard) |> map(&Tuple.to_list/1) |> sort
    assert remaining_letters == standard

    expected =
      Enum.reduce(game.racks["zach"], Game.counts(:standard), fn char, acc ->
        Map.update!(acc, char, &(&1 - 1))
      end)
      |> map(&Tuple.to_list/1)
      |> sort
      |> Enum.filter(fn
        [_, 0] -> false
        _ -> true
      end)

    assert sort(Game.remaining_letters(game, "zach")) == expected
  end
end
