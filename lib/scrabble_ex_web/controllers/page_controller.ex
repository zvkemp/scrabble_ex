defmodule ScrabbleExWeb.PageController do
  use ScrabbleExWeb, :controller

  def index(conn, _params) do
    if Map.has_key?(conn.cookies, "_scrabble_ex_identity") do
      redirect(conn, to: page_path(:hello)) |> halt()
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
      |> redirect(to: page_path(:index)) |> halt()
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

  # use the full path helper to ensure
  # a proper prefix when ScrabbleExWeb is mounted in another
  # endpoint.
  defp page_path(action) do
    ScrabbleExWeb.Router.Helpers.page_path(
      ScrabbleExWeb.Endpoint, action
    )
  end

end
