defmodule ScrabbleExWeb.PageController do
  use ScrabbleExWeb, :controller

  def index(conn, _params) do
    if Map.has_key?(conn.cookies, "_scrabble_ex_identity") do
      redirect(conn, to: page_path(:hello)) |> halt()
    else
      render(conn, "index.html")
    end
  end

  def show(conn, %{"id" => game_id}) do
    user = conn.assigns.current_user
    name = user.username
    token = Phoenix.Token.sign(ScrabbleExWeb.Endpoint, "salt", {name, "FIXME-REMOVE-THIS-ARG"})

    conn
    |> assign(:player, name)
    |> assign(:token, token)
    |> assign(:game_id, game_id)
    |> render("show.html")
  end

  def hello(conn, _params) do
    user = conn.assigns.current_user

    conn
    |> assign(:player, user.username)
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
