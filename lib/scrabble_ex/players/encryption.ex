defmodule ScrabbleEx.Players.Encryption do
  alias ScrabbleEx.Players.User

  def hash_password(password) do
    Bcrypt.hash_pwd_salt(password)
  end

  def validate_password(%User{} = user, password) do
    Bcrypt.check_pass(user, password)
  end
end
