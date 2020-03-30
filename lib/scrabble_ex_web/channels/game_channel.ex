defmodule ScrabbleExWeb.GameChannel do
  use Phoenix.Channel
  alias ScrabbleEx.Game

  def join("game:lobby", _message, socket) do
    {:ok, socket}
  end

  def join("game:" <> game_id, %{"token" => token}, socket) do
    # FIXME: use id to prevent name collisions
    {:ok, {player, id}} =
      Phoenix.Token.verify(ScrabbleExWeb.Endpoint, "salt", token, max_age: :infinity)

    {:ok, pid} = find_or_start_game(game_id)
    res = call(pid, {:add_player, player})

    case res do
      {:error, "game already started"} ->
        {:error, %{reason: "game already started"}}

      _ ->
        send(self(), :after_join)

        {:ok,
         socket
         # FIXME: assign game pid?
         |> assign(:game_id, game_id)
         |> assign(:player, player)}
    end
  end

  def handle_info(:after_join, socket) do
    game = call(socket, :state)
    broadcast!(socket, "info", %{message: "#{socket.assigns.player} joined"})
    broadcast!(socket, "state", game)
    push_rack(socket, game)
    {:noreply, socket}
  end

  # FIXME: this probably shouldn't be broadcast, as it can reveal letters
  # in a player's rack
  # or maybe that makes it more real?
  def handle_in("proposed", payload, socket) do
    if call(socket, :state).current_player == socket.assigns.player do
      nil
      # broadcast!(socket, "new_proposed", payload)
    end

    {:noreply, socket}
  end

  def handle_in("start", _payload, socket) do
    case call(socket, :start_game) do
      {:ok, game} -> broadcast!(socket, "state", game)
      {:error, msg} -> push(socket, "error", %{reason: msg})
    end

    {:noreply, socket}
  end

  def handle_in("swap", payload, socket) when is_binary(payload) do
    case call(socket, {:swap, socket.assigns.player, payload}) do
      {:ok, game} ->
        push_rack(socket, game)
        broadcast!(socket, "state", game)
      {:error, msg} = e ->
        push(socket, "error", %{reason: msg})
    end
    {:noreply, socket}
  end

  # FIXME: rename "submit_payload" => "play"
  def handle_in("submit_payload", payload, socket) do
    payload = Enum.map(payload, fn {k, v} -> {String.to_integer(k), v} end) |> Enum.into(%{})

    case call(socket, {:play, socket.assigns.player, payload}) do
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

  defp push_rack(socket, %Game{racks: racks} = game) do
    push(socket, "rack", %{rack: game.racks[socket.assigns.player]})
  end

  defp push_rack(socket) do
    push_rack(socket, call(socket, :state))
  end
end
