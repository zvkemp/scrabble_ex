defmodule ScrabbleEx.NullReferee do
  defstruct []

  def prepare_turn(game) do
    {:ok, game}
  end

  def handle_miss(game) do
    {:ok, game}
  end
end
