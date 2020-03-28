defmodule ScrabbleEx.Repo do
  use Ecto.Repo,
    otp_app: :scrabble_ex,
    adapter: Ecto.Adapters.Postgres
end
