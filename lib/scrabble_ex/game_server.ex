defmodule ScrabbleEx.GameServer do
  use GenServer
  alias ScrabbleEx.Game

  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def get(name) do
    GenServer.call({:global, "game:#{name}"}, :state)
  end

  def start(opts) do
    GenServer.start(__MODULE__, :ok, opts)
  end

  def init(:ok) do
    {:ok, Game.new(players: [])}
  end

  # for test
  def handle_call({:set_state, game}, _from, _game) do
    {:reply, :ok, game}
  end

  def handle_call(:state, _from, game) do
    {:reply, game, game}
  end

  def handle_call({:add_player, player}, _from, game) do
    # IO.inspect("add_player: #{player}")
    case Game.add_player(game, player) do
      {:ok, new_game} -> {:reply, {:ok, game}, new_game}
      {:error, msg} -> {:reply, {:error, msg}, game}
    end
  end

  def handle_call(:start_game, _from, game) do
    case Game.start(game) do
      {:ok, new_game} -> {:reply, {:ok, new_game}, new_game}
      {:error, msg} = e -> {:reply, e, game}
    end
  end

  def handle_call({:swap, player, string}, _from, game) do
    case Game.swap(game, player, string) do
      {:ok, new_game} -> {:reply, {:ok, new_game}, new_game}
      {:error, msg} = e -> {:reply, e, game}
    end
  end

  def handle_call({:play, player, payload}, _from, game) do
    case Game.play(game, player, payload) do
      {:ok, new_game} -> {:reply, {:ok, new_game}, new_game}
      {:error, e} -> {:reply, {:error, e}, game}
    end
  end
end
