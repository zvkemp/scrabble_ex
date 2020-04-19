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

  def show_game_turn(%{assigns: %{player: player}}, game) do
    show_game_turn(player, game)
  end

  def show_game_turn(%ScrabbleEx.Players.User{username: player}, game) do
    show_game_turn(player, game)
  end

  def show_game_turn(player, %{current_player: current_player}) when is_binary(player) do
    case current_player do
      ^player -> raw "<span class='your-turn'>your turn</span>"
      nil -> raw "<span class='not-started'>not started</span>"
      _ -> "#{current_player}'s turn"
    end
  end
  def show_game_turn(a, b), do: ""
end
