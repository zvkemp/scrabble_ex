defmodule ScrabbleExWeb.PageController do
  use ScrabbleExWeb, :controller

  def index(conn, _params) do
    if Map.has_key?(conn.cookies, "_scrabble_ex_identity") do
      redirect(conn, to: "/hello") |> halt()
    else
      render(conn, "index.html")
    end
  end

  # FIXME: redirect if not id
  def show(conn, %{"id" => game_id}) do
    token = conn.cookies["_scrabble_ex_identity"]

    if token do
      {:ok, {name, id}} = Phoenix.Token.verify(ScrabbleExWeb.Endpoint, "salt", token)

      conn
      |> assign(:player, name)
      |> assign(:token, token)
      |> assign(:game_id, game_id)
      |> render("show.html")
    else
      conn
      |> redirect(to: "/") |> halt()
    end
  end

  # FIXME: redirect if not id
  def hello(conn, _params) do
    token = conn.cookies["_scrabble_ex_identity"]
    {:ok, {name, id}} = Phoenix.Token.verify(ScrabbleExWeb.Endpoint, "salt", token)

    conn
    |> assign(:player, name)
    |> assign(:token, token)
    |> render("hello.html")
  end
end
