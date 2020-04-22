defmodule ScrabbleEx.GameServer do
  # FIXME: save game to DB

  use GenServer
  alias ScrabbleEx.Game
  alias ScrabbleEx.Persistence
  require Logger

  # After 30 minutes, this server will shut down.
  @game_timeout 1_800_000

  def find_or_start_game(id, opts \\ []) do
    case start({id, opts}, name: {:global, "game:#{id}"}) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
    end
  end

  def start_link([name: {:global, "game:" <> id}] = opts) do
    GenServer.start_link(__MODULE__, id, opts)
  end

  def start_link(id, opts) do
    GenServer.start_link(__MODULE__, id, opts)
  end

  def get(name) do
    GenServer.call({:global, "game:#{name}"}, :state)
  end

  def start([name: {:global, "game:" <> id}] = opts) do
    start(id, opts)
  end

  def start({id, game_opts}, opts \\ []) do
    opts = Keyword.put_new(opts, :name, {:global, "game:" <> id})
    GenServer.start(__MODULE__, {id, game_opts}, opts)
  end

  def set_rack(name, player, rack) do
    GenServer.call({:global, "game:#{name}"}, {:set_rack, player, rack})
  end

  def init(id) when is_binary(id) do
    init({id, []})
  end

  def init({id, opts}) do
    game = Persistence.get_game_by_name(id)

    case game do
      nil ->
        {:ok, game} =
          Persistence.create_game(%{
            name: id,
            state: Game.new(id, opts)
          })

        {:ok, %Game{game.state | pkid: game.id}, @game_timeout}

      %Persistence.Game{state: state, id: id} ->
        # FIXME: game timeout should be short for ended games; only needs to live long enough to serve state to the websocket.
        {:ok, %Game{state | pkid: id}, @game_timeout}
    end
  end

  # for test
  def handle_call({:set_state, game}, _from, _game) do
    {:reply, :ok, game, @game_timeout}
  end

  def handle_call(:state, _from, game) do
    {:reply, game, game, @game_timeout}
  end

  def handle_call({:set_rack, player, rack}, _from, game) do
    new_racks = game.racks |> Map.put(player, rack)
    {:reply, :ok, %Game{game | racks: new_racks}}
  end

  def handle_call({:add_player, user}, _from, game) do
    apply_game_fn(:add_player, [user.username], game, fn g ->
      add_player_assoc(g, user)
    end)
  end

  def handle_call(:start, _from, game) do
    apply_game_fn(:start, [], game)
  end

  def handle_call({:swap, player, letter_map}, _from, game) do
    apply_game_fn(:swap, [player, letter_map], game)
  end

  def handle_call({:pass, player}, _from, game) do
    apply_game_fn(:pass, [player], game)
  end

  def handle_call({:play, player, payload}, _from, game) do
    apply_game_fn(:play, [player, payload], game)
  end

  def handle_call({:game_fn, fn_name, args}, _from, game) do
    apply_game_fn(fn_name, args, game)
  end

  defp apply_game_fn(name, args, game) do
    apply_game_fn(name, args, game, & &1)
  end

  defp apply_game_fn(name, args, game, ok_callback) do
    case apply(Game, name, [game | args]) do
      {:ok, %Game{} = new_game} ->
        ok_callback.(new_game)
        {:reply, {:ok, new_game}, save_state(new_game), @game_timeout}

      {:ok, :rejoin} ->
        {:reply, {:ok, :rejoin}, game, @game_timeout}

      {:error, _msg} = e ->
        {:reply, e, game, @game_timeout}

      # error plus new state
      {:error, msg, new_game} ->
        {:reply, {:error, msg}, save_state(new_game), @game_timeout}

      {:error, :next_player, msg, new_game} ->
        {:reply, {:error, :next_player, msg, new_game}, save_state(new_game), @game_timeout}
    end
  end

  defp save_state(%Game{pkid: pkid, name: name} = game) do
    {:ok, _} = Persistence.update_game(%Persistence.Game{id: pkid, name: name}, %{state: game})

    game
  end

  defp add_player_assoc(%Game{pkid: pkid}, user) do
    Persistence.add_player_to_game(pkid, user.id)
  end

  def handle_info(:timeout, state) do
    {:stop, {:shutdown, :timeout}, state}
  end

  def terminate(reason, state) do
    Logger.warn("[timeout] GenServer for #{state.name} is terminating due to inactivity.")
  end
end
