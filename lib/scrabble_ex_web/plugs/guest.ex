defmodule ScrabbleExWeb.Plugs.Guest do
  import Plug.Conn
  import Phoenix.Controller
  alias ScrabbleEx.Players

  def init(opts), do: opts

  def call(conn, _opts) do
    if user_id = Plug.Conn.get_session(conn, :current_user_id) do
      conn
      |> redirect(to: "/hello")
      |> halt()
    else
      conn
    end
  end
end
