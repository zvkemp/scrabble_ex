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
end
