defmodule ScrabbleExWeb.LoginController do
  use ScrabbleExWeb, :controller

  def new(conn, %{ "login" => %{ "name" => name }} = params) do
    session_cookie = conn.cookies["_scrabble_ex_key"]
    token = Phoenix.Token.sign(ScrabbleExWeb.Endpoint, "salt", {name, session_cookie}, max_age: :infinity)

    conn
    |> put_resp_cookie("_scrabble_ex_identity", token, max_age: 86400 * 6000)
    |> text("hello, #{name}")
  end
end
