defmodule ScrabbleEx.Word do
  use Ecto.Schema
  import Ecto.Changeset
  alias ScrabbleEx.Repo
  alias ScrabbleEx.Word
  import Ecto.Query

  schema "words" do
    field :ospd, :boolean, default: false
    field :word, :string

    timestamps()
  end

  def load_ospd_file(path) do
    path
    |> File.stream!
    |> Stream.each(&IO.puts/1)
    |> Stream.map(&String.trim/1)
    |> Enum.each(&ScrabbleEx.Word.add_ospd_word/1)
  end

  def add_ospd_word(word) do
    insert(%{ ospd: true, word: word })
  end

  def insert(attrs) do
    Repo.insert(
      changeset(%Word{}, attrs), on_conflict: :nothing
    )
  end

  def ospd_words?(words) do
    Repo.aggregate(
      (from w in Word, where: w.word in ^words),
      :count
    ) == Enum.count(words)
  end

  def show_illegal_words(words) do
    words -- show_legal_words(words)
  end

  def show_legal_words(words) do
    Repo.all(select_words(words))
  end

  defp select_words(words) do
    from w in Word,
      where: w.word in ^words and w.ospd == true,
      select: w.word
  end

  def ospd_word?(word) do
    ospd_words?([word])
  end

  @doc false
  def changeset(word, attrs) do
    word
    |> cast(attrs, [:word, :ospd])
    |> validate_required([:word, :ospd])
  end
end
