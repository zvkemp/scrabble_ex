defmodule ScrabbleEx.PlayersTest do
  use ScrabbleEx.DataCase

  alias ScrabbleEx.Players

  describe "users" do
    alias ScrabbleEx.Players.User

    @valid_attrs %{password: "some password", username: "some username"}
    @update_attrs %{password: "some updated password", username: "some updated username"}
    @invalid_attrs %{encrypted_password: nil, username: nil}

    def user_fixture(attrs \\ %{}) do
      {:ok, user} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Players.create_user()

      user
    end

    @tag :pending
    test "list_users/0 returns all users" do
      user = user_fixture()
      assert Players.list_users() == [user]
    end

    @tag :pending
    test "get_user!/1 returns the user with given id" do
      user = user_fixture()
      assert Players.get_user!(user.id) == user
    end

    @tag :pending
    test "create_user/1 with valid data creates a user" do
      assert {:ok, %User{} = user} = Players.create_user(@valid_attrs)
      assert user.encrypted_password == "some encrypted_password"
      assert user.username == "some username"
    end

    test "create_user/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Players.create_user(@invalid_attrs)
    end

    @tag :pending
    test "update_user/2 with valid data updates the user" do
      user = user_fixture()
      assert {:ok, %User{} = user} = Players.update_user(user, @update_attrs)
      assert user.encrypted_password == "some updated encrypted_password"
      assert user.username == "some updated username"
    end

    @tag :pending
    test "update_user/2 with invalid data returns error changeset" do
      user = user_fixture()
      assert {:error, %Ecto.Changeset{}} = Players.update_user(user, @invalid_attrs)
      assert user == Players.get_user!(user.id)
    end

    test "delete_user/1 deletes the user" do
      user = user_fixture()
      assert {:ok, %User{}} = Players.delete_user(user)
      assert_raise Ecto.NoResultsError, fn -> Players.get_user!(user.id) end
    end

    test "change_user/1 returns a user changeset" do
      user = user_fixture()
      assert %Ecto.Changeset{} = Players.change_user(user)
    end
  end
end
