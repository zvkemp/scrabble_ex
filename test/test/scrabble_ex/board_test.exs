defmodule ScrabbleEx.BoardTest do
  use ExUnit.Case, async: true
  alias ScrabbleEx.Board

  import Enum, only: [sort: 1]

  test "new" do
    b = ScrabbleEx.Board.new()
    assert(b.size == 15)
    assert(b.state[0] == :triple_word)
  end

  test "words 1" do
    str = """
      . . . . . . . . . . . . . . .
      . . . . . . . . . . . . . . .
      . . . . . . . . t . . . . . .
      . . . . . . . j o k e r s . .
      . . . . . . . o n . . . . . .
      . . . . . . . k a . . . . . .
      . . . . . . . e l . . . . . .
      . . . . . . . s . . . . . . .
      . . . . . . . . . . . . . . .
      . . . . . . . . . . . . . . .
      . . . . . . . . . . . . . . .
      . . . . . . . . . . . . . . .
      . . . . . . . . . . . . . . .
      . . . . . . . . . . . . . . .
      . . . . . . . . . . . . . . .
    """

    board = Board.parse(str)
    ## FIXME: infer size
    board = Board.new(15, board)
    assert Board.words(board) |> sort == ["el", "jokers", "jokes", "ka", "on", "tonal"]
  end
end
