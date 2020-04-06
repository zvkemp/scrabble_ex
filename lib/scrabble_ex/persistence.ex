defmodule ScrabbleEx.Persistence do
  @moduledoc """
  The Persistence context.
  """

  import Ecto.Query, warn: false
  alias ScrabbleEx.Repo

  alias ScrabbleEx.Persistence.Game
  alias ScrabbleEx.Persistence.GameUser
  alias ScrabbleEx.Players.User

  @doc """
  Returns the list of games.

  ## Examples

      iex> list_games()
      [%Game{}, ...]

  """
  def list_games do
    Repo.all(Game)
  end

  @doc """
  Gets a single game.

  Raises `Ecto.NoResultsError` if the Game does not exist.

  ## Examples

      iex> get_game!(123)
      %Game{}

      iex> get_game!(456)
      ** (Ecto.NoResultsError)

  """
  def get_game!(id), do: Repo.get!(Game, id)

  def get_game_by_name(name) do
    Repo.one(from g in Game, where: g.name == ^name)
  end

  @doc """
  Creates a game.

  ## Examples

      iex> create_game(%{field: value})
      {:ok, %Game{}}

      iex> create_game(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_game(attrs \\ %{}) do
    %Game{}
    |> Game.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a game.

  ## Examples

      iex> update_game(game, %{field: new_value})
      {:ok, %Game{}}

      iex> update_game(game, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_game(%Game{} = game, attrs) do
    game
    |> Game.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a game.

  ## Examples

      iex> delete_game(game)
      {:ok, %Game{}}

      iex> delete_game(game)
      {:error, %Ecto.Changeset{}}

  """
  def delete_game(%Game{} = game) do
    Repo.delete_all(from p in GameUser, where: p.game_id == ^game.id)
    Repo.delete(game)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking game changes.

  ## Examples

      iex> change_game(game)
      %Ecto.Changeset{source: %Game{}}

  """
  def change_game(%Game{} = game) do
    Game.changeset(game, %{})
  end

  def add_player_to_game(game_id, user_id) do
    Repo.insert(
      ScrabbleEx.Persistence.GameUser.changeset(
        %ScrabbleEx.Persistence.GameUser{},
        %{game_id: game_id, user_id: user_id}
      ),
      on_conflict: :nothing
    )
  end

  def backfill_players(game) do
    game.players
    |> Enum.each(&backfill_player(game, &1))
  end

  def backfill_players() do
    list_games
    |> Enum.each(fn
      %Game{state: %ScrabbleEx.Game{players: players}} = game ->
        players
        |> Enum.each(&backfill_player(game, &1))

      a ->
        IO.inspect(a)
    end)
  end

  def backfill_player(game, name) do
    user = Repo.get_by(User, username: String.downcase(name))

    if user do
      add_player_to_game(game.id, user.id)
    end
  end
end
