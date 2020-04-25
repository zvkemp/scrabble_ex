defmodule ScrabbleExWeb.UserSocket do
  use Phoenix.Socket
  import ScrabbleExWeb.Endpoint, only: [signing_salt: 0]
  require Logger

  ## Channels
  channel "game:*", ScrabbleExWeb.GameChannel

  # Socket params are passed from the client and can
  # be used to verify and authenticate a user. After
  # verification, you can put default assigns into
  # the socket that will be set for all channels, ie
  #
  #     {:ok, assign(socket, :user_id, verified_user_id)}
  #
  # To deny connection, return `:error`.
  #
  # See `Phoenix.Token` documentation for examples in
  # performing token verification on connect.
  def connect(%{"token" => token} = _params, socket, _connect_info) do
    # FIXME: reduce max_age
    {:ok, user_id} =
      Phoenix.Token.verify(ScrabbleExWeb.Endpoint, signing_salt(), token, max_age: :infinity)

    {:ok, assign(socket, :user_id, user_id)}
  end

  # Socket id's are topics that allow you to identify all sockets for a given user:
  #
  #     def id(socket), do: "user_socket:#{socket.assigns.user_id}"
  #
  # Would allow you to broadcast a "disconnect" event and terminate
  # all active sockets and channels for a given user:
  #
  #     ScrabbleExWeb.Endpoint.broadcast("user_socket:#{user.id}", "disconnect", %{})
  #
  # Returning `nil` makes this socket anonymous.
  def id(socket) do
    case socket.assigns do
      %{user_id: user_id} -> "user_socket:#{user_id}"
      _ -> nil
    end
  end
end
