defmodule ScrabbleEx.Repo.Migrations.CreateGamesUsers do
  use Ecto.Migration

  def change do
    create table(:games_users) do
      add :game_id, references(:games)
      add :user_id, references(:users)
    end

    create unique_index(:games_users, [:game_id, :user_id])
  end
end
