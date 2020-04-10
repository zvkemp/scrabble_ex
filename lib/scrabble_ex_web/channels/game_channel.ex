defmodule ScrabbleExWeb.GameChannel do
  use Phoenix.Channel
  alias ScrabbleEx.Game
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
    # broadcast!(socket, "info", %{message: "#{socket.assigns.player} joined"})
    broadcast!(socket, "state", game)
    push(socket, "rack", rack_payload(socket, game))
    {:noreply, socket}
  end

  def handle_in("proposed", payload, socket) do
    game = call(socket, :state)

    if game.current_player == socket.assigns.player do
      case ScrabbleEx.Game.propose(game, socket.assigns.player, payload) do
        {:ok, scores} ->
          # FIXME: make this broadcast a game option
          # broadcast!(socket, "new_proposed", payload)

          response = %{message: scores |> Enum.map(&Enum.join(&1, ",")) |> Enum.join(" ")}

          {:reply, {:ok, response}, socket}

        {:error, m} ->
          {:reply, {:error, %{message: m}}, socket}
      end
    end
  end

  def handle_in("start", _payload, socket) do
    case call(socket, :start_game) do
      {:ok, game} ->
        broadcast_game_state(socket, game)
        {:noreply, socket}

      {:error, msg} ->
        reply_error(socket, msg)
    end
  end

  def handle_in("swap", payload, socket) do
    case call(socket, {:swap, socket.assigns.player, payload}) do
      {:ok, %{racks: racks} = game} ->
        broadcast_game_state(
          socket,
          game,
          "#{socket.assigns.player} swapped #{payload |> Enum.count()} tiles."
        )

        {:reply, {:ok, %{rack: racks[socket.assigns.player]}}, socket}

      {:error, msg} ->
        {:reply, {:error, %{message: msg}}, socket}
    end
  end

  def handle_in("pass", payload, socket) do
    case call(socket, {:pass, socket.assigns.player}) do
      {:ok, game} ->
        broadcast_game_state(
          socket,
          game,
          "#{socket.assigns.player} passed."
        )

        {:noreply, socket}

      {:error, msg} ->
        {:reply, {:error, %{message: msg}}, socket}
    end
  end

  # FIXME: rename "submit_payload" => "play"
  def handle_in("submit_payload", payload, socket) do
    payload = Enum.map(payload, fn {k, v} -> {String.to_integer(k), v} end) |> Enum.into(%{})

    case call(socket, {:play, socket.assigns.player, payload}) do
      {:ok, game} ->
        broadcast_game_state(socket, game)
        reply_with_rack(socket, game)

      {:error, msg} ->
        reply_error(socket, msg)
      {:error, :next_player, msg, game} ->
        broadcast_game_state(socket, game)
        broadcast_admonishment(socket, game)
        push(socket, "rack", rack_payload(socket, game))
        reply_error(socket, msg)
    end
  end

  defp find_or_start_game(id) do
    case ScrabbleEx.GameServer.start(id, name: {:global, "game:#{id}"}) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
    end
  end

  defp find_game_pid(socket) do
    {:ok, pid} = find_or_start_game(socket.assigns.game_id)
    pid
  end

  defp call(pid, term) when is_pid(pid), do: GenServer.call(pid, term)
  defp call(%Phoenix.Socket{} = socket, term), do: call(find_game_pid(socket), term)

  defp reply_with_rack(socket, %Game{} = game) do
    {:reply, {:ok, rack_payload(socket, game)}, socket}
  end

  defp rack_payload(socket, %{racks: racks} = game) do
    %{
      rack: racks[socket.assigns.player],
      remaining: Game.remaining_letters(game, socket.assigns.player)
    }
  end

  defp broadcast_game_state(socket, game, additional_msg \\ nil) do
    letters_left = Enum.count(game.bag)
    player = game.current_player
    inflection = if letters_left == 1, do: "letter", else: "letters"
    msg = "#{letters_left} #{inflection} left in bag. #{player}'s turn."

    msg = if additional_msg, do: "#{additional_msg} #{msg}", else: msg

    broadcast!(socket, "state", game)
    broadcast!(socket, "info", %{message: msg})
  end

  defp broadcast_admonishment(socket, game) do
    broadcast!(socket, "info", %{message: "#{socket.assigns.player} lost a turn due to illegal maneuvers."})
  end

  defp reply_error(socket, msg) do
    {:reply, {:error, %{message: msg}}, socket}
  end
end
