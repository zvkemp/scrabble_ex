defmodule ScrabbleExWeb.DashboardLive do
  # FIXME: show 'leave' on pending games; destroy game if last player leaves
  # FIXME: show 'forfeit' on in-progress games;
  # FIXME: optionally show pending games to public
  # FIXME: invite user in game view
  use Phoenix.LiveView, layout: {ScrabbleExWeb.LayoutView, "live.html"}

  def mount(_params, %{"current_user_id" => user_id}, socket) do
    ScrabbleExWeb.Endpoint.subscribe("user_dashboard:#{user_id}")

    user = ScrabbleEx.Players.get_user!(user_id)
    socket =
      socket
      |> assign(:user, user)
      |> load_games()

    {:ok, socket}
  end

  defp load_games(socket) do
    user = socket.assigns.user
    games =
      ScrabbleEx.Persistence.list_games(user_id: user.id)
      |> Enum.reduce([[], [], [], []], fn
        game, [not_started, current, idle, over] ->
          cond do
            game.state.current_player == nil -> [[game|not_started], current, idle, over]
            game.state.game_over -> [not_started, current, idle, [game|over]]
            game.state.current_player == user.username -> [not_started, [game|current], idle, over]
            true -> [not_started, current, [game|idle], over]
          end
      end
      )
      |> Enum.map(&Enum.reverse/1)
    |> List.flatten
    |> Enum.map(&to_game_meta/1)

    for game <- games do
      ScrabbleExWeb.Endpoint.subscribe("user_dashboard:game:#{game.id}")
    end

    assign(socket, :games, games)
  end

  # present information meaningful to this template (try to keep LiveView's in-memory state as light as possible)
  defp to_game_meta(%ScrabbleEx.Persistence.Game{state: state, id: id} = game) do
    %{
      id: id,
      game_over: state.game_over,
      name: game.name,
      current_player: state.current_player,
      players: ScrabbleExWeb.PageView.show_players(state)
    }
  end

  def handle_info({:msg, str}, socket) do
    {:noreply, assign(socket, :str, str)}
  end

  def handle_info(%{event: "msg", payload: %{msg: str}, topic: topic}, socket) do
    {:noreply, assign(socket, :str, str)}
  end

  def handle_info(%{event: "game_updated"} = payload, socket) do
    {:noreply, load_games(socket)}
  end

  def handle_info(%{event: "game_joined"} = payload, socket) do
    {:noreply, load_games(socket)}
  end

  def handle_info(_, socket) do
    {:noreply, socket}
  end

  defp rand_str do
    :crypto.strong_rand_bytes(16) |> Base.encode64
  end
end
