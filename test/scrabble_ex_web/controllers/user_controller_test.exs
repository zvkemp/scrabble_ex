defmodule ScrabbleExWeb.UserControllerTest do
  use ScrabbleExWeb.ConnCase

  alias ScrabbleEx.Players

  @create_attrs %{encrypted_password: "some encrypted_password", username: "some username"}
  @update_attrs %{encrypted_password: "some updated encrypted_password", username: "some updated username"}
  @invalid_attrs %{encrypted_password: nil, username: nil}

  def fixture(:user) do
    {:ok, user} = Players.create_user(@create_attrs)
    user
  end

  describe "new user" do
    test "renders form", %{conn: conn} do
      conn = get(conn, Routes.user_path(conn, :new))
      assert html_response(conn, 200) =~ "New User"
    end
  end

  describe "create user" do
    test "redirects to show when data is valid", %{conn: conn} do
      conn = post(conn, Routes.user_path(conn, :create), user: @create_attrs)

      assert %{} = redirected_params(conn)
      # assert redirected_to(conn) == Routes.hello_path(conn)

      conn = get(conn, "/hello")
      assert html_response(conn, 200) =~ "hello"
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.user_path(conn, :create), user: @invalid_attrs)
      assert html_response(conn, 200) =~ "New User"
    end
  end

  defp create_user(_) do
    user = fixture(:user)
    {:ok, user: user}
  end
end
