defmodule ScrabbleExWeb.GameChannelTest do
  use ScrabbleExWeb.ChannelCase
  alias ScrabbleExWeb.GameChannel
  alias ScrabbleEx.GameServer
  alias ScrabbleEx.Game
  import ScrabbleExWeb.Endpoint, only: [signing_salt: 0]

  def rand_token do
    :crypto.strong_rand_bytes(16)
    |> Base.encode64()
  end

  setup do
    start_game_server()

    z_token = Phoenix.Token.sign(ScrabbleExWeb.Endpoint, signing_salt, {"zach", rand_token()})
    k_token = Phoenix.Token.sign(ScrabbleExWeb.Endpoint, signing_salt, {"kate", rand_token()})

    {:ok, _, zach} =
      socket(ScrabbleExWeb.UserSocket)
      |> subscribe_and_join(GameChannel, "game:default", %{"token" => z_token})

    {:ok, _, kate} =
      socket(ScrabbleExWeb.UserSocket)
      |> subscribe_and_join(GameChannel, "game:default", %{"token" => k_token})

    {:ok, %{zach: zach, kate: kate}}
  end

  def start_game_server do
    case GameServer.start_link(name: {:global, "game:default"}) do
      {:ok, pid} -> pid
      {:error, {:already_started, pid}} -> pid
    end

    bag = ~w[
      J O K E S X V O K E R S Q Z T N A L E B B
    ]

    game = %Game{game_state() | bag: bag}
    GenServer.call({:global, "game:default"}, {:set_state, game})
  end

  def game_state() do
    GenServer.call({:global, "game:default"}, :state)
  end

  def start_game do
    GenServer.call({:global, "game:default"}, :start_game)
  end

  test "both members belong to the game", %{zach: zach, kate: _kate} do
    game = game_state()
    # pushed to both clients on join
    assert_push("state", ^game)
    assert_push("state", k_game)

    {:ok, rt} = Jason.decode(Jason.encode!(k_game))

    assert %{"board" => board, "scores" => scores} = rt
    assert Map.has_key?(rt, "bag") == false
    assert Map.has_key?(rt, "racks") == false

    game = game_state()
    z_rack = %{rack: game.racks["zach"]}
    k_rack = %{rack: game.racks["kate"]}
    assert_push("rack", ^z_rack)
    assert_push("rack", ^k_rack)
    assert %Game{current_player: nil} = game_state()

    push(zach, "start")
    assert_broadcast("state", %Game{current_player: nil})
    assert_broadcast("state", %Game{current_player: "zach"})
  end

  test "first turn", %{zach: zach, kate: kate} do
    game = game_state()
    # pushed to both clients on join
    # only one is pinned bc the state of the 'bag' at
    # either push is different. Which means: FIXME: don't serialize the bag
    assert_push("state", ^game)
    assert_push("state", game)
    assert %Game{current_player: nil} = game

    push(kate, "start")

    assert_broadcast("state", %Game{current_player: nil})
    assert_broadcast("state", %Game{current_player: "zach"})

    push(zach, "submit_payload", %{
      "52" => "J",
      "67" => "O",
      "82" => "K",
      "97" => "E",
      "112" => "S"
    })

    assert_broadcast("state", %Game{})
    assert_broadcast("state", %Game{})

    # asserting the rack message ensures state is resolved before getting
    # game_state() here
    assert_push("rack", %{rack: ["T", "N", "A", "L", "E", "X", "V"]})

    game = game_state()
    assert %Game{scores: scores} = game
    # ensure this works
    Jason.encode!(game)

    assert %{"zach" => [[["JOKES", 48]]]} = scores

    push(kate, "submit_payload", %{
      "53" => "O",
      "54" => "K",
      "55" => "E",
      "56" => "R",
      "57" => "S"
    })

    assert_broadcast("state", %Game{})
    assert_broadcast("state", %Game{})
    assert_push("rack", %{rack: ["B", "B", "Q", "Z"]})
    game = game_state()
    assert %Game{scores: scores} = game
    # ensure this works
    Jason.encode!(game)

    assert %{
             "zach" => [[["JOKES", 48]]],
             "kate" => [[["JOKERS", 34]]]
           } = scores

    push(zach, "submit_payload", %{
      "38" => "T",
      "68" => "N",
      "83" => "A",
      "98" => "L"
    })

    assert_broadcast("state", %Game{})
    assert_broadcast("state", %Game{})
    assert_push("rack", %{rack: ["E", "X", "V"]})
    game = game_state()
    assert %Game{scores: scores} = game
    # ensure this works
    Jason.encode!(game)

    assert %{
             "zach" => [
               [["EL", 3], ["KA", 6], ["ON", 2], ["TONAL", 7]],
               [["JOKES", 48]]
             ]
           } = scores
  end

  test "error handling", %{zach: zach} do
    start_game()
    game = game_state()

    assert game.current_player == "zach"
    push(zach, "submit_payload", %{"112" => "Z", "113" => "O", "114" => "T"})

    # assert_broadcast("state", %Game{})
    assert_push("error", %{message: "player does not have the goods" <> _})
    assert game_state().current_player == "zach"
  end
end
