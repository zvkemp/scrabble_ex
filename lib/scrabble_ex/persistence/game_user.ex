defmodule ScrabbleEx.Persistence.GameUser do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  schema "games_users" do
    field :game_id, :integer
    field :user_id, :integer
  end

  @doc false
  def changeset(game_user, attrs) do
    game_user
    |> cast(attrs, [:game_id, :user_id])
  end
end
