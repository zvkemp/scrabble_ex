defmodule ScrabbleExWeb.PageView do
  use ScrabbleExWeb, :view

  def show_players(game) do
    game
    |> ScrabbleEx.Game.total_scores()
    |> Enum.map(fn {name, score} ->
      "#{name}: #{score}"
    end)
    |> Enum.join(", ")
  end

  def show_game_turn(_, %{game_over: true}), do: "game over"

  def show_game_turn(%{assigns: %{player: player}}, %{current_player: current_player}) do
    if player == current_player do
      raw("<span class='your-turn'>your turn</span>")
    else
      "#{current_player}'s turn"
    end
  end

  def show_game_turn(_, _), do: ""
end
