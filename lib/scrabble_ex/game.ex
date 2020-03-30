defmodule ScrabbleEx.Game do
  # FIXME: swap turn
  # FIXME: pass turn (toward end of game) - allowed when fewer than 7 tiles remaining in bag
  # FIXME: handle game over
  #

  alias ScrabbleEx.{Game, Board}

  @derive {Jason.Encoder, only: [:board, :scores, :current_player, :players]}
  defstruct [:board, :players, :log, :scores, :racks, :bag, :current_player]

  def new(players: players) do
    new(players: players, board: ScrabbleEx.Board.new())
  end

  def new(players: players, board: board) do
    new(players: players, board: board, bag: new_bag)
  end

  def new(players: players, board: board, bag: bag) do
    %__MODULE__{
      players: players,
      current_player: nil,
      board: board,
      log: [],
      bag: bag,
      scores: players |> Enum.map(&{&1, []}) |> Enum.into(%{}),
      racks: players |> Enum.map(&{&1, []}) |> Enum.into(%{})
    }
    |> fill_racks
  end

  @char_counts %{
    "A" => 9,
    "B" => 2,
    "C" => 2,
    "D" => 4,
    "E" => 12,
    "F" => 2,
    "G" => 3,
    "H" => 2,
    "I" => 9,
    "J" => 1,
    "K" => 1,
    "L" => 4,
    "M" => 2,
    "N" => 6,
    "O" => 8,
    "P" => 2,
    "Q" => 1,
    "R" => 6,
    "S" => 4,
    "T" => 6,
    "U" => 4,
    "V" => 2,
    "W" => 2,
    "X" => 1,
    "Y" => 2,
    "Z" => 1
    # :blank => 2 # FIXME
  }

  def add_player(%Game{current_player: p}) when is_binary(p) do
    {:error, "game already started"}
  end

  def add_player(%Game{} = game, player) do
    case Map.has_key?(game.racks, player) do
      false ->
        new_players = game.players ++ [player]
        new_scores = game.scores |> Map.put(player, [])
        new_racks = game.racks |> Map.put(player, [])

        {:ok,
         %Game{game | scores: new_scores, racks: new_racks, players: new_players} |> fill_racks}

      _ ->
        {:error, "player already joined"}
    end
  end

  def start(game) do
    {:ok, next_player(game)}
  end

  def next_player(%Game{current_player: nil} = game) do
    next_player(game, 0)
  end

  def next_player(%Game{} = game) do
    count = game.players |> Enum.count()
    idx = index_of_player(game.players, game.current_player)
    next_player(game, rem(idx + 1, count))
  end

  defp index_of_player(players, player) do
    Enum.with_index(players)
    |> Enum.reduce(0, fn
      {^player, idx}, acc -> idx
      _, acc -> acc
    end)
  end

  defp next_player(game, index) do
    %Game{game | current_player: Enum.at(game.players, index)}
  end

  defp new_bag do
    @char_counts
    |> Enum.flat_map(fn {c, n} ->
      Stream.cycle([c]) |> Enum.take(n)
    end)
    |> Enum.shuffle()
  end

  defmodule Turn do
    defstruct [:player, :letter_map]
  end

  def play(
        %__MODULE__{scores: scores, log: log, players: players, board: board} = game,
        player,
        letter_map
      ) do
    letter_map = normalize_map(letter_map, board.size)
    first_turn = Enum.empty?(log)
    turn = %Turn{player: player, letter_map: letter_map}

    with :ok <- validate_play(turn, game),
         {:ok, new_board} <- Board.merge_and_validate(board, letter_map),
         {:ok, score} <- ScrabbleEx.Score.score(board, new_board, letter_map, first_turn) do
      new_scores = Map.update(scores, player, [score], fn xs -> [score | xs] end)
      # remove played letters
      new_racks = Map.put(game.racks, player, game.racks[player] -- Map.values(letter_map))

      {:ok,
       %Game{
         game
         | log: [[player, letter_map] | log],
           board: new_board,
           scores: new_scores,
           racks: new_racks
       }
       |> fill_racks
       |> next_player}
    else
      {:error, message} = e -> e
    end
  end

  defp normalize_map(letter_map, size) do
    letter_map
    |> Enum.map(fn
      {{x, y}, v} -> {to_index(x, y, size), v}
      {x, v} -> {x, v |> String.upcase()}
    end)
    |> Enum.into(%{})
  end

  defp validate_play(%Turn{} = turn, %Game{log: []} = game) do
    validate_first_play(turn, game)
  end

  defp validate_play(%Turn{} = turn, %Game{} = game) do
    with :ok <- validate_length(turn.letter_map, 1),
         :ok <- validate_common(turn, game) do
      :ok
    else
      {:error, msg} = e -> e
    end
  end

  defp validate_first_play(%Turn{} = turn, %Game{} = game) do
    with :ok <- validate_crosses_center(turn.letter_map, game.board.size),
         :ok <- validate_length(turn.letter_map, 2),
         :ok <- validate_common(turn, game) do
      :ok
    else
      {:error, msg} -> {:error, msg}
    end
  end

  defp validate_common(%Turn{} = turn, %Game{} = game) do
    with :ok <- validate_linear(turn.letter_map, game.board),
         :ok <- validate_player_is_current(turn, game),
         :ok <- validate_player_has_tiles(turn, game) do
      :ok
    else
      {:error, _} = e -> e
    end
  end

  defp validate_player_is_current(turn, game) do
    cond do
      turn.player == game.current_player -> :ok
      true -> {:error, "it is not #{turn.player}'s turn"}
    end
  end

  defp validate_player_has_tiles(%Turn{} = turn, %Game{racks: racks} = game) do
    case Map.values(turn.letter_map) -- racks[turn.player] do
      [] ->
        :ok

      _ ->
        {:error,
         "player does not have the goods; tried=#{
           Map.values(turn.letter_map) |> Enum.join() |> inspect
         }; has=#{racks[turn.player] |> Enum.join() |> inspect}"}
    end
  end

  defp validate_linear(letter_map, board) do
    case direction(letter_map, board) do
      {:ok, :vertical, coords} ->
        [{x1, _} | _] = coords
        ys = coords |> Enum.map(fn {_, y} -> y end)
        y_min = Enum.min(ys)
        y_max = Enum.max(ys)

        coords = Stream.cycle([x1]) |> Enum.zip(y_min..y_max)
        validate_coords_present(coords, letter_map, board)

      {:ok, :horizontal, coords} ->
        [{_, y1} | _] = coords
        xs = coords |> Enum.map(fn {x, _} -> x end)
        x_min = Enum.min(xs)
        x_max = Enum.max(xs)

        coords = x_min..x_max |> Enum.zip(Stream.cycle([y1]))
        validate_coords_present(coords, letter_map, board)

      {:error, _} = e ->
        e
    end
  end

  defp validate_coords_present(coords, letter_map, board) do
    coords = Enum.map(coords, &to_index(&1, board.size))

    cond do
      Enum.all?(coords, fn index ->
        Map.has_key?(letter_map, index) ||
            is_binary(Map.get(board.state, index))
      end) ->
        :ok

      true ->
        {:error, "word is not continuous"}
    end
  end

  defp to_index({x, y}, size), do: to_index(x, y, size)

  defp to_index(x, y, size) do
    y * size + x
  end

  defp to_xy(index, size) do
    y = div(index, size)
    x = rem(index, size)
    {x, y}
  end

  # FIXME: single letter?
  defp direction(letter_map, board) do
    xc =
      letter_map
      |> Map.keys()
      |> Enum.map(&rem(&1, board.size))
      |> Enum.sort()

    yc =
      letter_map
      |> Map.keys()
      |> Enum.map(&div(&1, board.size))
      |> Enum.sort()

    coords = List.zip([xc, yc])

    cond do
      Enum.uniq(xc) |> Enum.count() == 1 -> {:ok, :vertical, coords}
      Enum.uniq(yc) |> Enum.count() == 1 -> {:ok, :horizontal, coords}
      true -> {:error, "word is not linear"}
    end
  end

  defp validate_length(letter_map, min) do
    cond do
      letter_map |> Enum.count() >= min -> :ok
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

  defp fill_racks(%Game{players: players, bag: lc, racks: racks} = game) do
    {new_racks, new_lc} =
      Enum.reduce(players, {racks, lc}, fn
        _player, {racks, [] = lc} ->
          # empty, just continue
          {racks, lc}

        player, {racks, lc} ->
          count_needed = 7 - Enum.count(racks[player])

          {
            Map.put(racks, player, Enum.take(lc, count_needed) ++ racks[player]),
            Enum.drop(lc, count_needed)
          }
      end)

    %Game{
      game
      | racks: new_racks,
        bag: new_lc
    }
  end
end
