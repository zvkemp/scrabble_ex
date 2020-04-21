defmodule ScrabbleEx.InvitationBroker do
  use GenServer
  require Logger
  import ScrabbleExWeb.Endpoint, only: [broadcast: 3]

  def start_link(_opt) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    {:ok, MapSet.new()}
  end

  def invite_all(game_name) do
    invite_user(:all, game_name)
  end

  def get_all_invitations(key) do
    GenServer.call(__MODULE__, {:invitations, key})
    |> Enum.map(fn {key, name} -> name end)
  end

  def handle_call({:invitations, key}, _from, state) do
    {:reply,
     Enum.filter(
       state,
       fn
         {^key, _} -> true
         {:all, _} -> true
         _ -> false
       end
     ), state}
  end

  def invite_user(user_id_or_name, game_name) do
    GenServer.cast(__MODULE__, {:invite, user_id_or_name, game_name})
  end

  def handle_cast({:invite, key, game_name}, state) do
    case key do
      :all -> dispatch_invitation("user_dashboard_all", game_name)
      _ -> dispatch_invitation("user_dashboard:#{key}", game_name)
    end

    {:noreply, MapSet.put(state, {key, game_name})}
  end

  def game_started(game_name) do
    GenServer.cast(__MODULE__, {:game_started, game_name})
  end

  def handle_cast({:game_started, game_name}, state) do
    {:noreply,
     Enum.filter(state, fn
       {_, ^game_name} ->
         broadcast("user_dashboard_all", "remove_invitation", %{game_name: game_name})
         false

       _ ->
         true
     end)
     |> Enum.into(MapSet.new())}
  end

  def player_joined(game_name, player) do
    GenServer.cast(__MODULE__, {:player_joined, game_name, player})
  end

  def handle_cast({:player_joined, game_name, player}, state) do
    {:noreply,
     Enum.filter(state, fn
       {^player, ^game_name} ->
         broadcast("user_dashboard:#{player}", "remove_invitation", %{game_name: game_name})
         false

       _ ->
         true
     end)
     |> Enum.into(MapSet.new())}
  end

  defp dispatch_invitation(key, game_name) do
    broadcast(key, "new_invitation", %{game_name: game_name})
  end
end
