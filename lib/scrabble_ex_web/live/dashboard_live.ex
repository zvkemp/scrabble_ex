defmodule ScrabbleExWeb.DashboardLive do
  # FIXME: show 'leave' on pending games; destroy game if last player leaves
  # FIXME: show 'forfeit' on in-progress games;
  # FIXME: optionally show pending games to public
  # FIXME: invite user in game view
  use Phoenix.LiveView, layout: {ScrabbleExWeb.LayoutView, "live.html"}

  def mount(_params, %{"current_user_id" => user_id}, socket) do
    ScrabbleExWeb.Endpoint.subscribe("user_dashboard_all")
    ScrabbleExWeb.Endpoint.subscribe("user_dashboard:#{user_id}")

    user = ScrabbleEx.Players.get_user!(user_id)
    ScrabbleExWeb.Endpoint.subscribe("user_dashboard:#{user.username}")

    socket =
      socket
      |> assign(:user, user)
      |> load_games()
      |> get_all_invitations()

    {:ok, socket}
  end

  defp load_games(socket) do
    user = socket.assigns.user

    games =
      ScrabbleEx.Persistence.list_games(user_id: user.id)
      |> Enum.reduce([[], [], [], []], fn
        game, [not_started, current, idle, over] ->
          cond do
            game.state.current_player == nil ->
              [[game | not_started], current, idle, over]

            game.state.game_over ->
              [not_started, current, idle, [game | over]]

            game.state.current_player == user.username ->
              [not_started, [game | current], idle, over]

            true ->
              [not_started, current, [game | idle], over]
          end
      end)
      |> Enum.map(&Enum.reverse/1)
      |> List.flatten()
      |> Enum.map(&to_game_meta/1)

    for game <- games do
      ScrabbleExWeb.Endpoint.subscribe("user_dashboard:game:#{game.id}")
    end

    assign(socket, :games, games)
  end

  # present information meaningful to this template (try to keep LiveView's in-memory state as light as possible)
  defp to_game_meta(%ScrabbleEx.Persistence.Game{state: state}) do
    to_game_meta(state)
  end

  defp to_game_meta(%ScrabbleEx.Game{} = game) do
    %{
      id: game.pkid,
      game_over: game.game_over,
      name: game.name,
      current_player: game.current_player,
      players: ScrabbleExWeb.PageView.show_players(game)
    }
  end

  defp to_game_meta(game_name) when is_binary(game_name) do
    # FIXME: avoid doing two calls?
    ScrabbleEx.GameServer.find_or_start_game(game_name)
    ScrabbleEx.GameServer.get(game_name, &to_game_meta/1)
  end

  def handle_info(%{event: "new_invitation", payload: %{game_name: game_name}} = e, socket) do
    {:noreply, add_invitation(socket, game_name)}
  end

  def handle_info(%{event: "remove_invitation", payload: %{game_name: game_name}} = e, socket) do
    {:noreply, remove_invitation(socket, game_name)}
  end

  defp get_all_invitations(socket) do
    socket = assign(socket, :invitations, [])
    ScrabbleEx.InvitationBroker.get_all_invitations(socket.assigns.user.username)
    |> Enum.reduce(socket, fn name, s -> add_invitation(s, name) end)
  end

  defp add_invitation(socket, game_name) do
    if Enum.all?(socket.assigns.games, & &1.name != game_name) do
      existing = socket.assigns.invitations || []
      assign(socket, :invitations, [to_game_meta(game_name) | existing] |> Enum.uniq_by(& &1.id))
    else
      socket
    end
  end

  defp remove_invitation(socket, game_name) do
    invitations =
      Enum.filter(socket.assigns.invitations || [], fn
        %{name: ^game_name} -> false
        _ -> true
      end)

    assign(socket, :invitations, invitations)
  end

  def handle_info({:msg, str}, socket) do
    {:noreply, assign(socket, :str, str)}
  end

  def handle_info(%{event: "msg", payload: %{msg: str}, topic: topic}, socket) do
    {:noreply, assign(socket, :str, str)}
  end

  def handle_info(%{event: "game_updated"} = payload, socket) do
    # FIXME: avoid requerying DB for all updated games; we should be able to
    # get the new state from the event.
    {:noreply, load_games(socket)}
  end

  def handle_info(%{event: "game_joined", payload: payload}, socket) do
    # FIXME: avoid requerying DB for all updated games; we should be able to
    # get the new state from the event.
    socket = remove_invitation(socket, payload.game_name)
    {:noreply, load_games(socket)}
  end

  def handle_info(_, socket) do
    {:noreply, socket}
  end

  defp rand_str do
    :crypto.strong_rand_bytes(16) |> Base.encode64()
  end
end
