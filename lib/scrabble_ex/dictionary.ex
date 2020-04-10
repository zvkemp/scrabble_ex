defmodule ScrabbleEx.Dictionary do
  use GenServer
  require Logger

  def start_link(_opt) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    [fun, args] = Application.get_env(:scrabble_ex, __MODULE__)
    apply(__MODULE__, fun, args)
  end

  def word?(word) do
    GenServer.call(__MODULE__, {:member, word})
  end

  def handle_call({:member, word}, _from, state) do
    {:reply, MapSet.member?(state, String.downcase(word)), state}
  end

  def show_legal_words(words) do
    words
    |> Enum.reduce(%{}, fn word, map ->
      Map.put(map, word, word?(word))
    end)
  end

  def load_words_from_file(path) do
    path = Path.expand("./priv/dictionary.json")
    {:ok, text} = File.read(path)
    state = Jason.decode!(text) |> Enum.into(MapSet.new())
    {:ok, state}
  end

  def load_words_from_url(url) do
    Logger.info("loading words from remote...")
    {:ok, resp} = Tesla.get(url)
    {:ok, stream} = StringIO.open(resp.body)

    set =
      stream
      |> IO.binstream(:line)
      |> Stream.map(&String.trim/1)
      |> Enum.into(MapSet.new())

    StringIO.close(stream)

    Logger.info("...done")
    {:ok, set}
  end
end
