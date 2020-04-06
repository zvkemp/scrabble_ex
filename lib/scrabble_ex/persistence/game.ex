defmodule ScrabbleEx.Persistence.Game do
  use Ecto.Schema
  alias ScrabbleEx.Persistence.Term
  import Ecto.Changeset
  alias ScrabbleEx.Players.User

  schema "games" do
    field :name, :string
    field :state, Term

    many_to_many :users, User, join_through: "games_users"

    timestamps()
  end

  @doc false
  def changeset(game, attrs) do
    game
    |> cast(attrs, [:name, :state])
    |> validate_required([:name, :state])
  end
end
