defmodule ScrabbleExWeb.GameChannelTest do
  use ScrabbleExWeb.ChannelCase
  alias ScrabbleExWeb.GameChannel
  alias ScrabbleEx.GameServer
  alias ScrabbleEx.Game
  alias ScrabbleEx.Players
  import ScrabbleExWeb.Endpoint, only: [signing_salt: 0]

  def rand_token do
    :crypto.strong_rand_bytes(16)
    |> Base.encode64()
  end

  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> Enum.into(%{})
      |> Players.create_user()

    user
  end

  def build_user_and_token(attrs \\ %{}) do
    user = user_fixture(attrs)
    token = Phoenix.Token.sign(ScrabbleExWeb.Endpoint, signing_salt(), user.id)
    {:ok, user, token}
  end

  def build_and_join(channel_id, %{username: _} = attrs) do
    {:ok, _user, token} = build_user_and_token(attrs)

    socket(ScrabbleExWeb.UserSocket)
    |> subscribe_and_join(GameChannel, channel_id, %{"token" => token})
  end

  setup do
    start_game_server()

    {:ok, _, zach} = build_and_join("game:default", %{username: "zach"})
    {:ok, _, kate} = build_and_join("game:default", %{username: "kate"})
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

    game = %Game{game_state() | bag: bag, opts: [start_at: 0]}
    GenServer.call({:global, "game:default"}, {:set_state, game})
  end

  def game_state() do
    GenServer.call({:global, "game:default"}, :state)
  end

  def start_game do
    GenServer.call({:global, "game:default"}, :start_game)
  end

  # def assert_player_state_push(to_socket, term) do
  #   term = Map.put(term, :join_ref, to_socket.join_ref)
  #   assert_push("player-state", )
  # end
  def assert_player_state_push(join_ref, rack, current_player) do
    assert_push("player-state", %{
      rack: ^rack,
      game: %{current_player: ^current_player},
      join_ref: ^join_ref
    })
  end

  def assert_player_state_push(join_ref, current_player) do
    assert_push("player-state", %{game: %{current_player: ^current_player}, join_ref: ^join_ref})
  end

  test "both members belong to the game", %{zach: zach, kate: kate} do
    z_ref = zach.join_ref
    k_ref = kate.join_ref
    game = game_state()
    z_rack = game.racks["zach"]
    k_rack = game.racks["kate"]

    # pushed to both clients on each player join
    assert_player_state_push(z_ref, z_rack, nil)
    assert_player_state_push(z_ref, z_rack, nil)
    assert_player_state_push(k_ref, k_rack, nil)

    assert {:ok, rt} = Jason.decode(Jason.encode!(game))

    assert %{"board" => board, "scores" => scores} = rt
    assert Map.has_key?(rt, "bag") == false
    assert Map.has_key?(rt, "racks") == false

    game = game_state()

    assert %Game{current_player: nil} = game_state()

    ref = push(zach, "start")
    assert_reply(ref, :ok, %{})

    assert_player_state_push(z_ref, z_rack, "zach")
    assert_player_state_push(k_ref, k_rack, "zach")
  end

  def assert_intercepted_broadcast(sockets, game) do
    current_player = game.current_player

    for socket <- sockets do
      rack = game.racks[socket.assigns.player]
      join_ref = socket.join_ref

      assert_push("player-state", %{
        rack: ^rack,
        game: %{current_player: ^current_player},
        join_ref: ^join_ref
      })
    end
  end

  @tag :focus
  test "full game", %{zach: %{join_ref: z_ref} = zach, kate: %{join_ref: k_ref} = kate} do
    game = game_state()
    # pushed to both clients on join
    assert_intercepted_broadcast([zach], game)
    assert_intercepted_broadcast([zach, kate], game)

    ref = push(kate, "start")
    assert_reply(ref, :ok, %{})

    assert %{current_player: "zach"} = game = game_state()

    assert_intercepted_broadcast([zach, kate], game)

    ref = push(zach, "start")
    assert_reply(ref, :error, %{message: "game already started"})

    ref = push(zach, "pass")
    assert_reply(ref, :error, %{message: "you shall not pass"})

    ref =
      push(zach, "submit_payload", %{
        "52" => "J",
        "67" => "O",
        "82" => "K",
        "97" => "E",
        "112" => "S"
      })

    # asserting the rack message ensures state is resolved before getting
    # game_state() here
    # assert_push("rack", %{rack: ["T", "N", "A", "L", "E", "X", "V"]})

    assert_reply(ref, :ok, %{})
    assert %{scores: scores, current_player: "kate"} = game = game_state()
    assert_intercepted_broadcast([zach, kate], game)
    # ensure this works
    Jason.encode!(game)

    assert %{"zach" => [[["JOKES", 48]]]} = scores

    ref = push(kate, "proposed", %{})
    assert_reply(ref, :error, %{message: "not long enough"})

    ref = push(kate, "proposed", %{"0" => "K", "1" => "E"})
    assert_reply(ref, :error, %{message: "word is not connected"})

    payload = %{
      "53" => "O",
      "54" => "K",
      "55" => "E",
      "56" => "R",
      "57" => "S"
    }

    ref = push(kate, "proposed", payload)
    assert_reply(ref, :ok, %{message: "JOKERS,34"})

    ref = push(kate, "submit_payload", payload)
    assert_reply(ref, :ok, %{})

    %Game{scores: scores} = game = game_state()
    assert_intercepted_broadcast([zach, kate], game)
    Jason.encode!(game)

    assert %{
             "zach" => [[["JOKES", 48]]],
             "kate" => [[["JOKERS", 34]]]
           } = scores

    ref =
      push(zach, "submit_payload", %{
        "38" => "T",
        "68" => "N",
        "83" => "A",
        "98" => "L"
      })

    assert_reply(ref, :ok, %{})

    %Game{scores: scores} = game = game_state()
    assert_intercepted_broadcast([zach, kate], game)
    # ensure this works
    Jason.encode!(game)

    assert %{
             "zach" => [
               [["EL", 3], ["KA", 6], ["ON", 2], ["TONAL", 7]],
               [["JOKES", 48]]
             ]
           } = scores

    _game = game_state()

    ref = push(kate, "swap", %{"112" => "A"})
    assert_reply(ref, :error, %{message: "player does not have [\"A\"]"})

    ref = push(kate, "pass")
    assert_reply(ref, :ok, %{})

    assert %{current_player: "zach"} = game = game_state()
    assert_intercepted_broadcast([zach, kate], game)
  end

  test "error handling", %{zach: zach} do
    start_game()
    game = game_state()

    assert game.current_player == "zach"
    ref = push(zach, "submit_payload", %{"112" => "Z", "113" => "O", "114" => "T"})

    # assert_broadcast("state", %Game{})
    assert_reply(ref, :error, %{message: "player does not have the goods" <> _})
    assert game_state().current_player == "zach"
  end

  test "swap", %{zach: zach} do
    start_game()
    game_at_start = game_state()

    ref = push(zach, "swap", %{"112" => "J"})
    assert_reply(ref, :ok, %{})
    assert game_at_start.racks["zach"] != game_state().racks["zach"]
  end

  test "joining after start", %{zach: zach} do
    ref = push(zach, "start")

    assert_reply(ref, :ok, %{})
    assert %{current_player: "zach"} = game_state()

    assert {:error, %{reason: "game already started"}} =
             build_and_join("game:default", %{username: "frances"})
  end

  test "lose a turn", %{zach: zach, kate: kate} do
    game = game_state()
    # pushed to both clients on join
    # only one is pinned bc the state of the 'bag' at
    assert_intercepted_broadcast([zach], game)
    assert_intercepted_broadcast([zach, kate], game)
    assert %Game{current_player: nil} = game

    ref = push(kate, "start")
    assert_reply(ref, :ok, %{})

    assert %{current_player: "zach"} = game = game_state()
    assert_intercepted_broadcast([zach, kate], game)

    ref =
      push(zach, "submit_payload", %{
        "52" => "J",
        "67" => "O",
        "82" => "K",
        "97" => "E",
        "112" => "X"
      })

    assert_reply(ref, :error, %{message: "these are not words: JOKEX"})

    assert game_state().current_player == "zach"
    assert game_state().referee.tries_remaining == 2

    ref =
      push(zach, "submit_payload", %{
        "52" => "J",
        "67" => "O",
        "82" => "X",
        "97" => "E",
        "112" => "S"
      })

    assert_reply(ref, :error, %{message: "these are not words: JOXES"})

    assert game_state().current_player == "zach"
    assert game_state().referee.tries_remaining == 1

    ref =
      push(zach, "submit_payload", %{
        "52" => "J",
        "67" => "O",
        "82" => "K",
        "97" => "E",
        "112" => "X"
      })

    assert_reply(ref, :error, %{
      message: "these are not words: JOKEX; You have exhausted three tries. Lose a turn!"
    })

    game = game_state()

    z_rack = game.racks["zach"]
    assert(game.current_player == "kate")
    assert(game.referee.tries_remaining == 3)

    assert_intercepted_broadcast([zach, kate], game)
    assert_broadcast("info", %{message: "zach lost a turn due to illegal maneuvers."})
  end

  def flush_messages(timeout \\ 100) do
    receive do
      %Phoenix.Socket.Message{} ->
        flush_messages()

      %Phoenix.Socket.Broadcast{} ->
        flush_messages()
    after
      timeout -> nil
    end
  end
end
