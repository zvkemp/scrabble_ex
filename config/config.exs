# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

config :scrabble_ex,
  ecto_repos: [ScrabbleEx.Repo]

# Configures the endpoint
config :scrabble_ex, ScrabbleExWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "Cfan9jVmRCwMTUfOygrhMAIlXUUXAwcBRkmUIggYUETiq6Tb1O0hTNqJl3Qe0+hh",
  render_errors: [view: ScrabbleExWeb.ErrorView, accepts: ~w(html json)],
  pubsub_server: ScrabbleEx.PubSub,
  live_view: [signing_salt: "Q5UT3WNP"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :scrabble_ex, ScrabbleEx.Dictionary, [
  :load_words_from_file,
  ["./priv/dictionary.json"]
]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
