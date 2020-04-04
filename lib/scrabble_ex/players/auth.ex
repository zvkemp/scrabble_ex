defmodule ScrabbleEx.Players.Auth do
  alias ScrabbleEx.Players.{Encryption, User}

  def login(params, repo) do
    user = repo.get_by(User, username: String.downcase(params["username"]))

    case authenticate(user, params["password"]) do
      true -> {:ok, user}
      _ -> :error
    end
  end

  defp authenticate(%User{} = user, password) do
    case Encryption.validate_password(user, password) do
      {:ok, validated_user} -> true
      {:error, _} -> false
    end
  end

  defp authenticate(_, _password), do: nil

  def signed_in?(conn) do
    conn.assigns[:current_user]
  end
end
