defmodule ScrabbleExWeb.PageController do
  use ScrabbleExWeb, :controller
  import ScrabbleExWeb.Endpoint, only: [signing_salt: 0]
  import Map, only: [get: 2]

  def index(conn, _params) do
    render(conn, "index.html")
  end

  def show(conn, %{"id" => game_id} = params) do
    user = conn.assigns.current_user
    name = user.username
    token = Phoenix.Token.sign(ScrabbleExWeb.Endpoint, signing_salt(), user.id)

    conn
    |> assign(:player, name)
    |> assign(:token, token)
    |> assign(:game_id, game_id)
    |> render("show.html")
  end

  def hello(conn, _params) do
    user = conn.assigns.current_user
    user = ScrabbleEx.Repo.preload(user, :games)

    games =
      user.games
      |> Enum.sort_by(fn
        %{state: %{current_player: cp, game_over: go}} ->
          cond do
            go -> "zzz"
            cp == user.username -> "aaa"
            true -> "bbb #{cp}"
          end
      end)

    conn
    |> assign(:games, games)
    |> assign(:player, user.username)
    |> render("hello.html")
  end

  # use the full path helper to ensure
  # a proper prefix when ScrabbleExWeb is mounted in another
  # endpoint.
  defp page_path(action) do
    ScrabbleExWeb.Router.Helpers.page_path(
      ScrabbleExWeb.Endpoint,
      action
    )
  end

  def create(conn, %{"game" => %{"name" => name, "board" => board}} = params) do
    :ok =
      case board do
        "standard" -> :ok
        "super" -> :ok
        "mini" -> :ok
        _ -> :error
      end

    name =
      case name do
        "" -> Stream.repeatedly(&Faker.Nato.letter_code_word/0) |> Enum.take(5) |> Enum.join("-")
        _ -> name
      end

    name = Inflex.parameterize_to_ascii(name)
    opts = [
      board_type: String.to_atom(board)
    ]

    opts = if params |> get("game") |> get("scramble"), do: Keyword.put(opts, :scramble, true), else: opts

    ScrabbleEx.GameServer.start({name, opts})

    conn
    |> redirect(to: Routes.page_path(conn, :show, name))
  end
end
