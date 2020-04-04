defmodule ScrabbleExWeb.LoginController do
  use ScrabbleExWeb, :controller

  alias ScrabbleEx.Players.Auth
  alias ScrabbleEx.Repo

  def new(conn, _params) do
    render(conn, "new.html")
  end

  def create(conn, %{"session" => auth_params}) do
    case Auth.login(auth_params, Repo) do
      {:ok, user} ->
        conn
        |> put_session(:current_user_id, user.id)
        |> put_flash(:info, "Signed in")
        # FIXME
        |> redirect(to: "/hello")

      :error ->
        conn
        |> put_flash(:error, "There was a problem signing you in.")
        |> render("new.html")
    end
  end

  def delete(conn, _paramS) do
    conn
    |> delete_session(:current_user_id)
    |> put_flash(:info, "Signed out")
    |> redirect(to: Routes.login_path(conn, :new))
  end

  def old_new(conn, %{"login" => %{"name" => name}} = params) do
    session_cookie = conn.cookies["_scrabble_ex_key"]

    token =
      Phoenix.Token.sign(ScrabbleExWeb.Endpoint, "salt", {name, session_cookie},
        max_age: :infinity
      )

    conn
    |> put_resp_cookie("_scrabble_ex_identity", token, max_age: 86400 * 6000)
    |> text("hello, #{name}")
  end
end
