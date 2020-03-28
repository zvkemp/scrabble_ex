use Mix.Config

# Configure your database
config :scrabble_ex, ScrabbleEx.Repo,
  username: "postgres",
  password: "postgres",
  database: "scrabble_ex_test",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :scrabble_ex, ScrabbleExWeb.Endpoint,
  http: [port: 4002],
  server: false

# Print only warnings and errors during test
config :logger, level: :warn
