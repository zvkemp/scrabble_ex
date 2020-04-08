defmodule ScrabbleEx.Repo.Migrations.CreateWords do
  use Ecto.Migration

  def change do
    create table(:words) do
      add :word, :string
      add :ospd, :boolean, default: false, null: false

      timestamps()
    end

    create unique_index(:words, [:word])
  end
end
