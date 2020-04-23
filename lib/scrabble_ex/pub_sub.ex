defmodule ScrabbleEx.PubSub do
  def subscribe(topic, opts \\ []) do
    Phoenix.PubSub.subscribe(__MODULE__, topic, opts)
  end

  def unsubscribe(topic) do
    Phoenix.PubSub.unsubscribe(__MODULE__, topic)
  end
end
