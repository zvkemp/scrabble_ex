defmodule ScrabbleEx.Referee do
  alias ScrabbleEx.Game
  defstruct tries_remaining: 3

  def prepare_turn(game) do
    game
    |> Map.put(:referee, %__MODULE__{})
  end

  def handle_miss(game) do
    tries_remaining = (game.referee || struct(__MODULE__)).tries_remaining - 1

    if tries_remaining > 0 do
      {:ok, %{game | referee: %__MODULE__{tries_remaining: tries_remaining}}}
    else
      {
        :ok,
        # FIXME: should this return error?
        :next_player,
        "You have exhausted three tries. Lose a turn!",
        Game.next_player(game)
      }
    end
  end
end
