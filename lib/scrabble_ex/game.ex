defmodule ScrabbleEx.Game do
  alias ScrabbleEx.{Game, Board}
  defstruct [:board, :players, :log, :scores]

  def new(players: players) do
    new(players: players, board: ScrabbleEx.Board.new)
  end

  def new(players: players, board: board) do
    %__MODULE__{
      players: players,
      board: board,
      log: [],
      scores: players |> Enum.map(&{&1, []}) |> Enum.into(%{})
    }
  end

  # FIXME: swap turn
  # FIXME: pass turn (toward end of game)
  # FIXME: pass first turn?
  # FIXME: letter cache
  # FIXME: player racks
  # FIXME: scoring
  # FIXME: validate connected -
  #  - this could probably be:
  #    - if word count is 1, letter count must be > played count
  #    - or word count > 1

  # first play, log is empty
  def play(game = %__MODULE__{scores: scores, log: log, players: players, board: board}, player, letter_map) do

    letter_map = normalize_map(letter_map, board.size)
    with :ok <- validate_play(letter_map, board, log) do
      new_board = %Board{board | state: Map.merge(board.state, letter_map)}

      score = ScrabbleEx.Score.score(board, new_board)
      new_scores = Map.update(scores, player, [score], fn xs -> [score|xs] end)

      {:ok, %Game{
        game |
          log: log,
          board: new_board,
          scores: new_scores,
      }}
    else
      {:error, message} = e -> e
    end
  end

  defp normalize_map(letter_map, size) do
    letter_map
    |> Enum.map(fn
      {{x, y}, v} -> {to_index(x, y, size), v}
      {x, v} -> {x, v}
    end)
    |> Enum.into(%{})
  end

  defp validate_play(letter_map, board, []) do
    validate_first_play(letter_map, board)
  end

  defp validate_play(letter_map, board, _log) do
    validate_play(letter_map, board)
  end

  defp validate_first_play(letter_map, board) do
    with :ok <- validate_crosses_center(letter_map, board.size),
         :ok <- validate_length(letter_map, 2),
         :ok <- validate_linear(letter_map, board) do
      :ok
    else
      {:error, msg} -> {:error, msg}
    end
  end

  defp validate_play(letter_map, board) do
    with :ok <- validate_length(letter_map, 1),
         :ok <- validate_linear(letter_map, board),
         :ok <- validate_linear(letter_map, board) do
      :ok
    else
      {:error, msg} = e -> e
    end
  end

  defp validate_length(letter_map) do
    validate_length(letter_map, 1)
  end

  defp validate_linear(letter_map, board) do
    case direction(letter_map, board) do
      {:ok, :vertical, coords} ->
        [{x1, _}|_] = coords
        ys = coords |> Enum.map(fn {_, y} -> y end)
        y_min = Enum.min(ys)
        y_max = Enum.max(ys)

        coords = Stream.cycle([x1]) |> Enum.zip(y_min..y_max)
        validate_coords_present(coords, letter_map, board)
      {:ok, :horizontal, coords} ->
        [{_, y1}|_] = coords
        xs = coords |> Enum.map(fn {x, _} -> x end)
        x_min = Enum.min(xs)
        x_max = Enum.max(xs)

        coords = (x_min..x_max) |> Enum.zip(Stream.cycle([y1]))
        validate_coords_present(coords, letter_map, board)
      {:error, _} = e -> e
    end
  end

  defp validate_coords_present(coords, letter_map, board) do
    coords = Enum.map(coords, &to_index(&1, board.size))
    cond do
      Enum.all?(coords, fn index ->
        Map.has_key?(letter_map, index) ||
          is_binary(Map.get(board.state, index))
      end) -> :ok
      true -> {:error, "word is not continuous"}
    end
  end


  defp to_index({x, y}, size), do: to_index(x, y, size)
  defp to_index(x, y, size) do
    (y * size) + x
  end

  defp to_xy(index, size) do
    y = div(index, size)
    x = rem(index, size)
    {x, y}
  end

  # FIXME: single letter?
  defp direction(letter_map, board) do
    xc = letter_map
          |> Map.keys
          |> Enum.map(&rem(&1, board.size))
          |> Enum.sort
    yc = letter_map
          |> Map.keys
          |> Enum.map(&div(&1, board.size))
          |> Enum.sort

    coords = List.zip([xc, yc])

    cond do
      Enum.uniq(xc) |> Enum.count == 1 -> {:ok, :vertical, coords}
      Enum.uniq(yc) |> Enum.count == 1 -> {:ok, :horizontal, coords}
      true -> {:error, "word is not linear"}
    end
  end

  defp validate_length(letter_map, min) do
    cond do
      letter_map |> Enum.count > 1 -> :ok
      true -> {:error, "not long enough"}
    end
  end

  defp validate_crosses_center(letter_map, board_size) do
    center_index = div(board_size, 2) * board_size + div(board_size, 2)
    cond do
      letter_map |> Map.has_key?(center_index) -> :ok
      true -> {:error, "does not cross center"}
    end
  end
end
