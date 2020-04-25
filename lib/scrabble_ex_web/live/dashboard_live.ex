defmodule ScrabbleExWeb.DashboardLive do
  # FIXME: show 'leave' on pending games; destroy game if last player leaves
  # FIXME: show 'forfeit' on in-progress games;
  # FIXME: optionally show pending games to public
  # FIXME: invite user in game view
  # FIXME: look into LiveComponent and preload to split the games into multiple lists
  use Phoenix.LiveView, layout: {ScrabbleExWeb.LayoutView, "live.html"}
  require Logger

  def mount(_params, %{"current_user_id" => user_id}, socket) do
    ScrabbleEx.PubSub.subscribe("user_dashboard_all")
    ScrabbleEx.PubSub.subscribe("user_dashboard:#{user_id}")

    user = ScrabbleEx.Players.get_user!(user_id)
    ScrabbleEx.PubSub.subscribe("user_dashboard:#{user.username}")

    socket =
      socket
      |> Map.put(:game_subscriptions, MapSet.new())
      |> assign(:user, user)
      |> load_games()
      |> get_all_invitations()

    # FIXME: maybe this shouldn't be temporary assigns.
    # - it's difficult or impossible to sort the entire list of games.
    # It might be better to keep several lists:
    #
    # - active invites
    # - active games (still possible to sort this list?)
    # - inactive games (this can be in temporary assigns, as we likely dont
    #
    # maybe we *can* keep the list in temporary assigns, and have an 'invalidation key' on the wrapper element,
    # forcing a re-render when the list needs to be re-sorted?
    {:ok, socket}
       #, temporary_assigns: [games: []]}
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

    socket = Enum.reduce(games, socket, &subscribe_once/2)

    assign(socket, :games, games)
  end

  defp subscribe_once(%Phoenix.LiveView.Socket{} = socket, game) do
    subscribe_once(game, socket)
  end

  defp subscribe_once(%ScrabbleEx.Game{} = game, socket) do
    subscribe_once(to_game_meta(game), socket)
  end

  defp subscribe_once(%{id: id}, socket) do
    cond do
      MapSet.member?(socket.game_subscriptions, id) -> socket
      true ->
        Logger.debug("subscribing #{socket.id} to #{id}")
        ScrabbleEx.PubSub.subscribe("user_dashboard:game:#{id}")
        Map.update(socket, :game_subscriptions, MapSet.new(), &MapSet.put(&1, id))
    end
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
    # FIXME: don't need to start a game server for these
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

  def handle_info(%{event: "game_updated", payload: payload}, socket) do
    # IO.inspect({"game_updated #{socket.id}", payload})
    # FIXME: avoid requerying DB for all updated games; we should be able to
    # get the new state from the event.
    # socket = subscribe_once(payload.game, socket)
    # {:noreply, assign(socket, :games, [to_game_meta(payload.game)])}
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
