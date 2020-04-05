defmodule ScrabbleEx.GameServer do
  # FIXME: save game to DB

  use GenServer
  alias ScrabbleEx.Game
  alias ScrabbleEx.Persistence

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

  def start(id, opts) do
    GenServer.start(__MODULE__, id, opts)
  end

  def set_rack(name, player, rack) do
    GenServer.call({:global, "game:#{name}"}, {:set_rack, player, rack})
  end

  def init(id) do
    game = Persistence.get_game_by_name(id)

    case game do
      nil ->
        IO.puts("game #{id} not found, creating new")

        {:ok, game} =
          Persistence.create_game(%{
            name: id,
            state: Game.new(id, players: [])
          })

        {:ok, %Game{game.state | pkid: game.id}}

      %Persistence.Game{state: state} ->
        IO.puts("game #{id} rehydrated")
        {:ok, state}
    end
  end

  # for test
  def handle_call({:set_state, game}, _from, _game) do
    {:reply, :ok, game}
  end

  def handle_call(:state, _from, game) do
    {:reply, game, game}
  end

  def handle_call({:set_rack, player, rack}, _from, game) do
    new_racks = game.racks |> Map.put(player, rack)
    {:reply, :ok, %Game{game | racks: new_racks}}
  end

  def handle_call({:add_player, player}, _from, game) do
    apply_game_fn(:add_player, [player], game)
  end

  def handle_call(:start_game, _from, game) do
    apply_game_fn(:start, [], game) # FIXME: standardize name of fn
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
    case apply(Game, name, [game|args]) do
      {:ok, new_game} -> {:reply, {:ok, new_game}, save_state(new_game)}
      {:error, _msg} = e -> {:reply, e, game}
    end
  end

  defp save_state(%Game{pkid: pkid, name: name} = game) do
    {:ok, _} = Persistence.update_game(%Persistence.Game{id: pkid, name: name}, %{state: game})

    game
  end
end
