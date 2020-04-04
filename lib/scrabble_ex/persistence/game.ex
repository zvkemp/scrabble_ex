defmodule ScrabbleEx.Persistence.Game do
  use Ecto.Schema
  alias ScrabbleEx.Persistence.Term
  import Ecto.Changeset


  schema "games" do
    field :name, :string
    field :state, Term

    timestamps()
  end

  @doc false
  def changeset(game, attrs) do
    game
    |> cast(attrs, [:name, :state])
    |> validate_required([:name, :state])
  end
end
