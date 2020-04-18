defmodule ScrabbleExWeb.Router do
  use ScrabbleExWeb, :router
  import Phoenix.LiveDashboard.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", ScrabbleExWeb do
    pipe_through [:browser, ScrabbleExWeb.Plugs.Guest]

    get "/login", LoginController, :new
    post "/login", LoginController, :create
    resources "/register", UserController, only: [:create, :new]
  end

  scope "/", ScrabbleExWeb do
    pipe_through [:browser, ScrabbleExWeb.Plugs.Auth]

    get "/", PageController, :hello
    delete "/logout", LoginController, :delete
    get "/hello", PageController, :hello
    get "/play/:id", PageController, :show

    post "/play", PageController, :create
  end

  if Mix.env() == :dev do
    scope "/" do
      pipe_through :browser
      live_dashboard "/dashboard"
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", ScrabbleExWeb do
  #   pipe_through :api
  # end
end
