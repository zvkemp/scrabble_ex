defmodule ScrabbleEx.PersistenceTest do
  use ScrabbleEx.DataCase

  alias ScrabbleEx.Persistence

  describe "games" do
    alias ScrabbleEx.Persistence.Game

    @valid_attrs %{name: "some name", state: "some state"}
    @update_attrs %{name: "some updated name", state: "some updated state"}
    @invalid_attrs %{name: nil, state: nil}

    def game_fixture(attrs \\ %{}) do
      {:ok, game} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Persistence.create_game()

      game
    end

    test "list_games/0 returns all games" do
      game = game_fixture()
      assert Persistence.list_games() == [game]
    end

    test "get_game!/1 returns the game with given id" do
      game = game_fixture()
      assert Persistence.get_game!(game.id) == game
    end

    test "create_game/1 with valid data creates a game" do
      assert {:ok, %Game{} = game} = Persistence.create_game(@valid_attrs)
      assert game.name == "some name"
      assert game.state == "some state"
    end

    test "create_game/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Persistence.create_game(@invalid_attrs)
    end

    test "update_game/2 with valid data updates the game" do
      game = game_fixture()
      assert {:ok, %Game{} = game} = Persistence.update_game(game, @update_attrs)
      assert game.name == "some updated name"
      assert game.state == "some updated state"
    end

    test "update_game/2 with invalid data returns error changeset" do
      game = game_fixture()
      assert {:error, %Ecto.Changeset{}} = Persistence.update_game(game, @invalid_attrs)
      assert game == Persistence.get_game!(game.id)
    end

    test "delete_game/1 deletes the game" do
      game = game_fixture()
      assert {:ok, %Game{}} = Persistence.delete_game(game)
      assert_raise Ecto.NoResultsError, fn -> Persistence.get_game!(game.id) end
    end

    test "change_game/1 returns a game changeset" do
      game = game_fixture()
      assert %Ecto.Changeset{} = Persistence.change_game(game)
    end
  end
end
