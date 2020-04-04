defmodule ScrabbleEx.GameServer do
  # FIXME: save game to DB

  use GenServer
  alias ScrabbleEx.Game
  alias ScrabbleEx.Persistence

  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def get(name) do
    GenServer.call({:global, "game:#{name}"}, :state)
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
        {:ok, game} = Persistence.create_game(%{
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
    # IO.inspect("add_player: #{player}")
    case Game.add_player(game, player) do
      {:ok, new_game} -> {:reply, {:ok, game}, save_state(new_game)}
      {:error, msg} -> {:reply, {:error, msg}, game}
    end
  end

  def handle_call(:start_game, _from, game) do
    case Game.start(game) do
      {:ok, new_game} -> {:reply, {:ok, new_game}, save_state(new_game)}
      {:error, msg} = e -> {:reply, e, game}
    end
  end

  def handle_call({:swap, player, string}, _from, game) do
    case Game.swap(game, player, string) do
      {:ok, new_game} -> {:reply, {:ok, new_game}, save_state(new_game)}
      {:error, msg} = e -> {:reply, e, game}
    end
  end

  def handle_call({:play, player, payload}, _from, game) do
    case Game.play(game, player, payload) do
      {:ok, new_game} -> {:reply, {:ok, new_game}, save_state(new_game)}
      {:error, e} -> {:reply, {:error, e}, game}
    end
  end

  defp save_state(%Game{pkid: pkid, name: name} = game) do
    {:ok, _} = Persistence.update_game(%Persistence.Game{ id: pkid, name: name }, %{ state: game })

    game
  end
end
