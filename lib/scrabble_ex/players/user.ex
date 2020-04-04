defmodule ScrabbleEx.Players.User do
  use Ecto.Schema
  import Ecto.Changeset
  alias ScrabbleEx.Players.{User, Encryption}

  schema "users" do
    field :encrypted_password, :string
    field :username, :string

    field :password, :string, virtual: true
    field :password_confirmation, :string, virtual: true

    timestamps()
  end

  @doc false
  def changeset(%User{} = user, attrs) do
    user
    |> cast(attrs, [:username, :password])
    |> validate_required([:username])
    |> validate_confirmation(:password)
    |> unique_constraint(:username)
    |> downcase_username
    |> encrypt_password
  end

  def encrypt_password(changeset) do
    password = get_change(changeset, :password)

    if password do
      encrypted_password = Encryption.hash_password(password)
      put_change(changeset, :encrypted_password, encrypted_password)
    else
      changeset
    end
  end

  def downcase_username(changeset) do
    update_change(changeset, :username, &String.downcase/1)
  end
end
