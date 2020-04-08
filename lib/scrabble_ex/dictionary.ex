defmodule ScrabbleEx.Dictionary do
  use GenServer

  def start_link(_opt) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    path = Path.expand("./priv/dictionary.json")
    {:ok, text} = File.read(path)
    state = Jason.decode!(text) |> Enum.into(MapSet.new())
    {:ok, state}
  end

  def word?(word) do
    GenServer.call(__MODULE__, {:member, word})
  end

  def handle_call({:member, word}, _from, state) do
    {:reply, MapSet.member?(state, String.downcase(word)), state}
  end

  def show_legal_words(words) do
    words
    |> Enum.reduce(%{}, fn (word, map) ->
      Map.put(map, word, word?(word))
    end)
  end
end
