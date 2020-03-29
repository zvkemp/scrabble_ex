defmodule ScrabbleExWeb.GameChannel do
  use Phoenix.Channel
  alias ScrabbleEx.Game

  # FIXME: don't serialize racks with a broadcast game state;
  # only send pushes to individual sockets.
  # FIXME: stop including the bag
  # FIXME: rename 'name' => 'player'
  def join("game:lobby", _message, socket) do
    {:ok, socket}
  end

  def join("game:" <> game_id, %{"name" => name}, socket) do
    {:ok, pid} = find_or_start_game(game_id)
    res = call(pid, {:add_player, name})

    case res do
      {:error, "game already started"} ->
        {:error, %{reason: "game already started"}}

      _ ->
        send(self(), :after_join)

        {:ok,
         socket
         # FIXME: assign game pid?
         |> assign(:game_id, game_id)
         |> assign(:name, name)}
    end
  end

  def handle_info(:after_join, socket) do
    game = call(socket, :state)
    push(socket, "state", game)
    push_rack(socket, game)
    {:noreply, socket}
  end

  # FIXME: this probably shouldn't be broadcast, as it can reveal letters
  # in a player's rack
  # or maybe that makes it more real?
  def handle_in("proposed", payload, socket) do
    if call(socket, :state).current_player == socket.assigns.name do
      nil
      # broadcast!(socket, "new_proposed", payload)
    end

    {:noreply, socket}
  end

  def handle_in("start", _payload, socket) do
    {:ok, player} = call(socket, :start_game)
    broadcast!(socket, "turn", %{player: player})
    {:noreply, socket}
  end

  # FIXME: rename "submit_payload" => "play"
  def handle_in("submit_payload", payload, socket) do
    payload = Enum.map(payload, fn {k, v} -> {String.to_integer(k), v} end) |> Enum.into(%{})

    case call(socket, {:play, socket.assigns.name, payload}) do
      {:ok, game} ->
        broadcast!(socket, "state", game)
        push_rack(socket, game)

      {:error, msg} ->
        push(socket, "error", %{reason: msg})
    end

    {:noreply, socket}
  end

  defp find_or_start_game(id) do
    # FIXME: I think start_link causes this to close
    # on duplicate joins (Phoenix closes the existing channel for new join)
    case ScrabbleEx.GameServer.start(name: {:global, "game:#{id}"}) do
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

  defp push_rack(socket, %Game{racks: racks} = game) do
    push(socket, "rack", %{rack: game.racks[socket.assigns.name]})
  end

  defp push_rack(socket) do
    push_rack(socket, call(socket, :state))
  end
end
