defmodule ScrabbleEx.Game do
  # FIXME: add a timer
  # FIXME: lose a turn if you propose a non-word, or allow other players to vote
  # FIXME: better 'game_over' handling

  alias ScrabbleEx.{Game, Board, Score}
  import Map, only: [put: 3, merge: 2, values: 1, has_key?: 2, update: 4, get: 2, keys: 1]

  import Enum,
    only: [
      map: 2,
      into: 2,
      count: 1,
      reduce: 3,
      shuffle: 1,
      empty?: 1,
      take: 2,
      drop: 2,
      join: 2,
      min: 1,
      max: 1,
      zip: 2,
      all?: 2,
      sort: 1,
      uniq: 1,
      any?: 2
    ]

  # @derive {Jason.Encoder, only: [:board, :scores, :current_player, :players, :game_over]}
  defstruct [
    :board,
    :players,
    :log,
    :scores,
    :racks,
    :bag,
    :current_player,
    :pkid,
    :name,
    :game_over,
    :pass_count,
    :referee,
    :board_type,
    opts: []
  ]

  defimpl Jason.Encoder, for: [__MODULE__] do
    def encode(struct, opts) do
      Jason.Encode.map(
        %{
          board: struct.board,
          scores: struct.scores,
          current_player: struct.current_player,
          players: struct.players,
          game_over: struct.game_over,
          swap_allowed: Game.swap_allowed?(struct),
          pass_allowed: Game.pass_allowed?(struct),
          bag_count: Enum.count(struct.bag),
          pass_count: struct.pass_count,
          size: struct.board.size,
          board_type: Game.board_type(struct),
          last_turn_indices: Game.last_turn_indices(struct)
        },
        opts
      )
    end
  end

  # FIXME: remove once all games have been backfilled
  def board_type(game) do
    game.board_type ||
      case game.board.size do
        11 -> :mini
        15 -> :standard
        21 -> :super
      end
  end

  def new(name, opts \\ [])

  def new("super:" <> _ = name, opts) do
    _new(
      name,
      Keyword.merge(opts, board_type: :super)
    )
  end

  def new("mini:" <> _ = name, opts) do
    _new(
      name,
      Keyword.merge(opts, board_type: :mini)
    )
  end

  def new(name, opts) do
    _new(name, opts)
  end

  # players: players, board: board, bag: bag) do
  defp _new(name, opts) do
    import Keyword, only: [get: 2, get: 3, get_lazy: 3]

    players = get(opts, :players, [])
    board_type = get(opts, :board_type, :standard)
    board = get_lazy(opts, :board, fn -> Board.new(board_type) end)

    board = if get(opts, :scramble, false), do: Board.scramble(board), else: board

    %__MODULE__{
      players: players,
      current_player: nil,
      board: board,
      log: [],
      bag: get_lazy(opts, :bag, fn -> new_bag(board_type) end),
      scores: players |> map(&{&1, []}) |> into(%{}),
      racks: players |> map(&{&1, []}) |> into(%{}),
      name: name,
      game_over: false,
      pass_count: 0,
      board_type: board_type,
      referee: struct(ScrabbleEx.Referee),
      opts: [start_at: get(opts, :start_at, :rand)]
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
    "Z" => 1,
    "BLANK" => 2
  }

  @super_counts %{
    "A" => 16,
    "B" => 4,
    "C" => 6,
    "D" => 8,
    "E" => 24,
    "F" => 4,
    "G" => 5,
    "H" => 5,
    "I" => 13,
    "J" => 2,
    "K" => 2,
    "L" => 7,
    "M" => 6,
    "N" => 13,
    "O" => 15,
    "P" => 4,
    "Q" => 2,
    "R" => 13,
    "S" => 10,
    "T" => 15,
    "U" => 7,
    "V" => 3,
    "W" => 4,
    "X" => 2,
    "Y" => 4,
    "Z" => 2,
    "BLANK" => 4
  }

  # FIXME: Balance of letters needs work.
  # should be around 54 to fill up 45% of the board;
  # maybe fewer odd letters and more blanks
  @mini_counts %{
    "A" => 3,
    "B" => 1,
    "C" => 1,
    "D" => 2,
    "E" => 5,
    "F" => 1,
    "G" => 2,
    "H" => 1,
    "I" => 3,
    "J" => 1,
    "K" => 1,
    "L" => 2,
    "M" => 1,
    "N" => 3,
    "O" => 3,
    "P" => 1,
    "Q" => 1,
    "R" => 3,
    "S" => 3,
    "T" => 4,
    "U" => 2,
    "V" => 1,
    "W" => 1,
    "X" => 1,
    "Y" => 1,
    "Z" => 1,
    "BLANK" => 2
  }

  def counts(:standard), do: @char_counts
  def counts(:super), do: @super_counts
  def counts(:mini), do: @mini_counts

  def add_player(%Game{current_player: p, players: px}, username) when is_binary(p) do
    if Enum.member?(px, username) do
      {:ok, :rejoin}
    else
      {:error, "game already started"}
    end
  end

  def add_player(%Game{current_player: nil} = game, player) do
    case has_key?(game.racks, player) do
      false ->
        new_players = game.players ++ [player]
        new_scores = game.scores |> put(player, [])
        new_racks = game.racks |> put(player, [])

        {:ok,
         game
         |> merge(%{scores: new_scores, racks: new_racks, players: new_players})
         |> fill_racks()}

      _ ->
        {:error, "player already joined"}
    end
  end

  def remaining_letters(game) do
    remaining_letters(game, [])
  end

  def remaining_letters(%{racks: racks} = game, player) when is_binary(player) do
    remaining_letters(game, racks[player])
  end

  def last_turn_indices(game) do
    case Enum.at(game.log, 0) do
      [_player, {:play, map}] -> keys(map)
      _ -> []
    end
  end

  def remaining_letters(%{racks: racks, bag: bag}, omit) when is_list(omit) do
    (((values(racks) |> List.flatten()) ++ bag) -- omit)
    |> Enum.sort_by(fn
      "BLANK" -> "ZZZ"
      char -> char
    end)
    |> Enum.reduce([], fn
      char, [] -> [[char, 1]]
      char, [[other_char, count] | tail] when char == other_char -> [[char, count + 1] | tail]
      char, [_ | _] = tail -> [[char, 1] | tail]
    end)
    |> Enum.reverse()
  end

  def start(%Game{current_player: nil} = game) do
    {:ok, next_player(game)}
  end

  def start(_game) do
    {:error, "game already started"}
  end

  def next_player(%Game{current_player: nil} = game) do
    idx =
      case Keyword.get(game.opts || [], :start_at, :rand) do
        :rand -> :rand.uniform(count(game.players)) - 1
        n when is_integer(n) -> n
      end

    next_player(game, idx)
  end

  def next_player(%Game{} = game) do
    count = game.players |> count()
    idx = index_of_player(game.players, game.current_player)

    next_player(game, rem(idx + 1, count))
    |> prepare_turn
  end

  defp index_of_player(players, player) do
    Enum.with_index(players)
    |> reduce(0, fn
      {^player, idx}, _acc -> idx
      _, acc -> acc
    end)
  end

  defp next_player(game, index) do
    put(game, :current_player, Enum.at(game.players, index))
  end

  defp new_bag(board_type) when is_atom(board_type) do
    new_bag(counts(board_type))
  end

  defp new_bag(counts) when is_map(counts) do
    counts
    |> Enum.flat_map(fn {c, n} ->
      Stream.cycle([c]) |> Enum.take(n)
    end)
    |> shuffle()
  end

  defmodule Turn do
    defstruct [:player, :letter_map]
  end

  # FIXME: make a better 'live score' feature
  def propose(
        %__MODULE__{log: log, board: board} = game,
        player,
        letter_map
      ) do
    letter_map = normalize_map(letter_map, board.size)
    turn = %Turn{player: player, letter_map: letter_map}

    with :ok <- validate_play(turn, game),
         {:ok, new_board} <- Board.merge_and_validate(board, letter_map),
         {:ok, score} <- Score.score(board, new_board, letter_map) do
      {:ok, score}
    else
      {:error, _msg} = e -> e
    end
  end

  def total_scores(%Game{scores: scores}) do
    Enum.reduce(
      scores,
      %{},
      fn {player, pscores}, acc ->
        tot =
          pscores |> Enum.map(&(&1 |> Enum.map(fn [_, n] -> n end) |> Enum.sum())) |> Enum.sum()

        put(acc, player, tot)
      end
    )
  end

  def play(%Game{game_over: true}, _player, _letter_map) do
    {:error, "game is over"}
  end

  def play(
        %__MODULE__{scores: scores, log: log, board: board} = game,
        player,
        letter_map
      ) do
    letter_map = normalize_map(letter_map, board.size)
    turn = %Turn{player: player, letter_map: letter_map}

    with :ok <- validate_current_player(game, player),
         :ok <- validate_play(turn, game),
         {:ok, new_board} <- Board.merge_and_validate(board, letter_map),
         {:ok, score} <- Score.valid_score(board, new_board, letter_map) do
      new_scores = update(scores, player, [score], fn xs -> [score | xs] end)
      # remove played letters
      new_racks =
        put(
          game.racks,
          player,
          game.racks[player] -- (values(letter_map) |> map(&normalize_blank/1))
        )

      {:ok,
       game
       |> merge(%{
         log: [[player, {:play, letter_map}] | log],
         board: new_board,
         scores: new_scores,
         racks: new_racks,
         # reset pass count if someone has played
         pass_count: 0
       })
       |> fill_racks
       |> next_player
       |> check_game_over}
    else
      {:error, _msg} = e ->
        e

      {:miss, msg} ->
        case handle_miss(game) do
          {:ok, :next_player, additional_message, game} ->
            {:error, :next_player, msg <> "; " <> additional_message, game}

          {:ok, %Game{} = game} ->
            {:error, msg, game}
        end
    end
  end

  defp handle_miss(game) do
    referee(game).handle_miss(game)
  end

  defp prepare_turn(game) do
    referee(game).prepare_turn(game)
  end

  defp referee(game) do
    (game.referee || default_referee()).__struct__
  end

  defp default_referee do
    struct(ScrabbleEx.Referee)
  end

  def pass(%Game{game_over: true} = game, player) do
    play(game, player, %{})
  end

  def pass(game, player) do
    with :ok <- validate_current_player(game, player),
         true <- pass_allowed?(game) do
      new_log = [[player, :pass] | game.log]

      {:ok,
       game
       |> update(:pass_count, 1, &(&1 + 1))
       |> put(:log, new_log)
       |> next_player
       |> check_game_over}
    else
      false -> {:error, "you shall not pass"}
      {:error, _} = e -> e
    end
  end

  def swap(%Game{game_over: true} = game, player, _str) do
    play(game, player, %{})
  end

  def swap(game, player, letter_map) when is_map(letter_map) do
    swap(
      game,
      player,
      values(letter_map) |> map(&normalize_blank/1)
    )
  end

  def swap(%Game{} = game, player, str) when is_binary(str) do
    swapped = str |> String.upcase() |> String.split(~r/\s+/, trim: true)
    swap(game, player, swapped)
  end

  def swap(%Game{} = game, player, swapped) when is_list(swapped) do
    with :ok <- validate_current_player(game, player),
         :ok <- validate_swap(game, player, swapped),
         :ok <- validate_swappability(game) do
      count = swapped |> count()
      new_tiles = game.bag |> take(count)
      new_rack = (game.racks[player] -- swapped) ++ new_tiles

      new_bag = (drop(game.bag, count) ++ swapped) |> shuffle()
      new_racks = put(game.racks, player, new_rack)
      new_log = [[player, :swap] | game.log]

      new_game =
        game
        |> merge(%{bag: new_bag, racks: new_racks, log: new_log})
        |> next_player

      {:ok, new_game}
    else
      {:error, _msg} = e -> e
    end
  end

  defp validate_swappability(%Game{bag: bag}) do
    if count(bag) >= 7 do
      :ok
    else
      {:error, "not enough tiles left in bag"}
    end
  end

  defp validate_swap(game, player, data) do
    diff = data -- game.racks[player]

    case diff do
      [] -> :ok
      _ -> {:error, "player does not have #{diff |> inspect}"}
    end
  end

  defp normalize_map(letter_map, size) do
    letter_map
    |> map(fn
      {{x, y}, v} -> {to_index(x, y, size), v}
      {x, v} -> {parse_int(x), v |> upcase()}
    end)
    |> into(%{})
  end

  defp parse_int(x) when is_integer(x), do: x

  defp parse_int(x) when is_binary(x) do
    {i, _} = Integer.parse(x)
    i
  end

  defp upcase(c) do
    String.upcase(c)
  end

  # defp validate_play(%Turn{} = turn, %Game{log: []} = game) do
  #   validate_first_play(turn, game)
  # end

  defp validate_play(%Turn{} = turn, %Game{} = game) do
    with :ok <- validate_first_play(turn, game),
         :ok <- validate_length(game.board, turn.letter_map),
         :ok <- validate_common(turn, game) do
      :ok
    else
      {:error, _msg} = e -> e
    end
  end

  # This validation is here only to make the first turn
  # 'not connected' message nicer; i.e., 'word does not cross center'
  defp validate_first_play(%Turn{} = turn, %Game{} = game) do
    with :ok <- validate_no_words_have_been_played(game),
         :ok <- validate_crosses_center(game, turn.letter_map) do
      :ok
    else
      :not_first_turn -> :ok # just continue
      {:error, msg} -> {:error, msg}
    end
  end

  defp validate_no_words_have_been_played(game) do
    if Enum.all?(game.scores, fn
         {_, []} -> true
         _ -> false
       end) do
      :ok
    else
      :not_first_turn
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
    if turn.player == game.current_player do
      :ok
    else
      {:error, "it is not #{turn.player}'s turn"}
    end
  end

  defp validate_player_has_tiles(%Turn{} = turn, %Game{racks: racks}) do
    case (values(turn.letter_map) |> map(&normalize_blank/1)) -- racks[turn.player] do
      [] ->
        :ok

      _ ->
        {:error,
         "player does not have the goods; tried=#{
           values(turn.letter_map)
           |> map(&normalize_blank/1)
           |> join(" ")
           |> inspect
         }; has=#{racks[turn.player] |> join(" ") |> inspect}"}
    end
  end

  # for rack comparison
  defp normalize_blank(":" <> _c), do: "BLANK"
  defp normalize_blank(c), do: c

  defp validate_linear(letter_map, board) do
    case direction(letter_map, board) do
      {:ok, :vertical, coords} ->
        [{x1, _} | _] = coords
        ys = coords |> map(fn {_, y} -> y end)
        y_min = min(ys)
        y_max = max(ys)

        coords = Stream.cycle([x1]) |> zip(y_min..y_max)
        validate_coords_present(coords, letter_map, board)

      {:ok, :horizontal, coords} ->
        [{_, y1} | _] = coords
        xs = coords |> map(fn {x, _} -> x end)
        x_min = min(xs)
        x_max = max(xs)

        coords = x_min..x_max |> zip(Stream.cycle([y1]))
        validate_coords_present(coords, letter_map, board)

      {:error, _} = e ->
        e
    end
  end

  defp validate_coords_present(coords, letter_map, board) do
    coords = map(coords, &to_index(&1, board.size))

    if all?(coords, fn index ->
         has_key?(letter_map, index) ||
           is_binary(get(board.state, index))
       end) do
      :ok
    else
      {:error, "word is not continuous"}
    end
  end

  defp to_index({x, y}, size), do: to_index(x, y, size)

  defp to_index(x, y, size) do
    y * size + x
  end

  # credo:disable-for-next-line
  defp to_xy(index, size) do
    y = div(index, size)
    x = rem(index, size)
    {x, y}
  end

  defp direction(letter_map, board) do
    xc =
      letter_map
      |> keys()
      |> map(&rem(&1, board.size))
      |> sort()

    yc =
      letter_map
      |> keys()
      |> map(&div(&1, board.size))
      |> sort()

    coords = List.zip([xc, yc])

    cond do
      uniq(xc) |> count() == 1 -> {:ok, :vertical, coords}
      uniq(yc) |> count() == 1 -> {:ok, :horizontal, coords}
      true -> {:error, "word is not linear"}
    end
  end

  defp validate_length(board, letter_map) do
    min = if Board.crosses_center?(board, letter_map), do: 2, else: 1

    if letter_map |> count() >= min do
      :ok
    else
      {:error, "not long enough"}
    end
  end

  defp validate_crosses_center(game, letter_map) do
    if Board.crosses_center?(game.board, letter_map) do
      :ok
    else
      {:error, "does not cross center"}
    end
  end

  defp fill_racks(%Game{players: players, bag: lc, racks: racks} = game) do
    {new_racks, new_lc} =
      reduce(players, {racks, lc}, fn
        _player, {racks, [] = lc} ->
          # empty, just continue
          {racks, lc}

        player, {racks, lc} ->
          count_needed = 7 - count(racks[player])

          {
            put(racks, player, take(lc, count_needed) ++ racks[player]),
            drop(lc, count_needed)
          }
      end)

    merge(game, %{racks: new_racks, bag: new_lc})
  end

  defp check_game_over(%Game{racks: racks} = game) do
    if any?(racks, fn {_player, rack} -> empty?(rack) end) ||
         (game.pass_count && game.pass_count >= count(game.players) * 2) do
      game
      |> put(:game_over, true)
      |> subtract_remaining_tiles
    else
      game
    end
  end

  defp subtract_remaining_tiles(game) do
    new_scores =
      game.racks
      |> reduce(game.scores, fn {player, rack}, scores ->
        total = Score.score_rack(rack)
        update(scores, player, [], &[[["remaining tiles", -total]] | &1])
      end)

    put(game, :scores, new_scores)
  end

  def swap_allowed?(game) do
    case validate_swappability(game) do
      :ok -> true
      _ -> false
    end
  end

  defp validate_current_player(game, player) do
    if game.current_player == player do
      :ok
    else
      {:error, "it is not #{player}'s turn"}
    end
  end

  def pass_allowed?(game) do
    !swap_allowed?(game)
  end
end
