defmodule ScrabbleExWeb.GameChannel do
  use Phoenix.Channel
  alias ScrabbleEx.Game
  require ScrabbleExWeb.Presence
  alias ScrabbleExWeb.Presence
  import ScrabbleExWeb.Endpoint, only: [signing_salt: 0]

  def join("game:lobby", _message, socket) do
    {:ok, socket}
  end

  def join("game:" <> game_id, %{"token" => token}, socket) do
    {:ok, user_id} =
      Phoenix.Token.verify(ScrabbleExWeb.Endpoint, signing_salt(), token, max_age: :infinity)

    user = ScrabbleEx.Players.get_user!(user_id)
    player = user.username

    {:ok, pid} = find_or_start_game(game_id)
    res = call(pid, {:add_player, user})

    case res do
      {:error, "game already started"} ->
        {:error, %{reason: "game already started"}}

      _ ->
        send(self(), :after_join)

        {:ok,
         socket
         # FIXME: assign game pid?
         |> assign(:game_id, game_id)
         |> assign(:player, player)
         |> assign(:user_id, user.id)}
    end
  end

  def handle_info(:after_join, socket) do
    game = call(socket, :state)
    broadcast!(socket, "player-state", %{game: game})
    # FIXME: how should this be used?
    {:ok, presence_ref} = Presence.track(socket, socket.assigns.user_id, socket.assigns)
    {:noreply, assign(socket, :presence_ref, presence_ref)}
  end

  def handle_in("proposed", payload, socket) do
    game = call(socket, :state)

    if game.current_player == socket.assigns.player do
      case ScrabbleEx.Game.propose(game, socket.assigns.player, payload) do
        {:ok, scores} ->
          # FIXME: make this broadcast a game option
          # broadcast!(socket, "new_proposed", payload)

          response = %{message: scores |> Enum.map(&Enum.join(&1, ": ")) |> Enum.join(", ")}
          {:reply, {:ok, response}, socket}

        {:error, m} ->
          {:reply, {:error, %{message: m}}, socket}
      end
    end
  end

  def handle_in("start", _payload, socket) do
    call(socket, :start_game)
    |> broadcast_call_result(socket, reply: :ok)
  end

  def handle_in("swap", payload, socket) do
    call(socket, {:swap, socket.assigns.player, payload})
    |> broadcast_call_result(
      socket,
      reply: :ok,
      success_msg: "#{socket.assigns.player} swapped #{payload |> Enum.count()} tiles."
    )
  end

  # FIXME: game could end here
  def handle_in("pass", payload, socket) do
    call(socket, {:pass, socket.assigns.player})
    |> broadcast_call_result(socket, reply: :ok, success_msg: "#{socket.assigns.player} passed.")
  end

  def handle_in("play", payload, socket) do
    call(socket, {:play, socket.assigns.player, payload})
    |> broadcast_call_result(
      socket,
      reply: :ok,
      additional_matches: fn
        {:error, :next_player, msg, game} ->
          broadcast_game_state(socket, game)
          broadcast_admonishment(socket, game)
          reply_error(socket, msg)
      end
    )
  end

  defp find_or_start_game(id, opts \\ []) do
    ScrabbleEx.GameServer.find_or_start_game(id, opts)
  end

  defp find_game_pid(socket) do
    {:ok, pid} = find_or_start_game(socket.assigns.game_id)
    pid
  end

  defp call(pid, term) when is_pid(pid), do: GenServer.call(pid, term)
  defp call(%Phoenix.Socket{} = socket, term), do: call(find_game_pid(socket), term)

  # player-specific payload.
  # The game serializer excludes the bag order and racks
  defp player_payload(socket, %{racks: racks} = game) do
    rack = racks[socket.assigns.player]

    %{
      rack: rack,
      remaining: Game.remaining_letters(game, socket.assigns.player),
      game: game,
      # mainly added for matching in tests
      join_ref: socket.join_ref
    }
  end

  defp broadcast_game_state(socket, game, additional_msg \\ nil) do
    letters_left = Enum.count(game.bag)
    player = game.current_player
    inflection = if letters_left == 1, do: "letter", else: "letters"
    msg = "#{letters_left} #{inflection} left in bag. #{player}'s turn."

    msg = if additional_msg, do: "#{additional_msg} #{msg}", else: msg

    broadcast!(socket, "player-state", game)
    broadcast!(socket, "info", %{message: msg})
  end

  defp broadcast_admonishment(socket, game) do
    broadcast!(socket, "info", %{
      message: "#{socket.assigns.player} lost a turn due to illegal maneuvers."
    })
  end

  defp broadcast_call_result(result, socket, opts \\ []) do
    case result do
      {:ok, %{racks: racks} = game} ->
        broadcast_game_state(
          socket,
          game,
          Keyword.get(opts, :success_msg)
        )

        case Keyword.get(opts, :reply) do
          nil -> {:noreply, socket}
          :ok -> {:reply, {:ok, %{}}, socket}
        end

      {:error, msg} ->
        reply_error(socket, msg)

      # If these patterns did not match, require a callback function to match the actual result.
      _ ->
        Keyword.fetch!(opts, :additional_matches).(result)
    end
  end

  defp reply_error(socket, msg) do
    {:reply, {:error, %{message: msg}}, socket}
  end

  intercept ["player-state", "presence_diff"]

  def handle_out("player-state", %Game{} = game, socket) do
    handle_out("player-state", %{game: game}, socket)
  end

  def handle_out("player-state", %{game: game}, socket) do
    push(socket, "player-state", player_payload(socket, game))
    {:noreply, socket}
  end

  def handle_out("presence_diff", payload, socket) do
    # It's less helpful to have the diff than a current list of
    # online clients sent at the time the diff was generated.
    presence =
      Presence.list(socket)
      |> Map.values()
      |> Enum.reduce([], fn
        %{metas: [%{player: username} | _]}, acc -> [username | acc]
        x, acc -> acc
      end)
      |> Enum.uniq()

    push(socket, "presence", %{online: presence})
    {:noreply, socket}
  end
end
