// Import the D3 packages we want to use
import { scaleLinear } from 'd3-scale'
import { select } from 'd3-selection'
import { extent, ascending } from 'd3-array'
import { transition } from 'd3-transition'
import { easeCubicInOut } from 'd3-ease'

class Scrabble {
  // FIXME: player sort rack

  // Array of points to render as circles in a line, spaced by time.

  //  [ {value: Number, timestamp: Number } ];
  constructor(socket) {
    window.game = this
    this.token = select("meta[name='id-token']").attr("content");
    this.player = select("meta[name='player']").attr("content");
    this.game_id = select("meta[name='game-id']").attr("content");

    this.socket = socket
    this.cursor = -1;
    this.size = 15;
    this.element = select("section.board-container");
    this.header = select("section.board-header");
    this.rack_container = select("section.rack-container");
    this.flash_container = select("section.flash-container p");
    this.direction = 'h'; // or 'v';
    this.current_player = undefined;
    this.proposed = {};
    this.scores = {};
    this.players = [];

    this.joinGameAs(this.token, this.name);
  }

  joinGameAs(token, name) {
    // this.player = name;

    // FIXME: get name from somewhere else
    this.channel = this.socket.channel(`game:${this.game_id}`, { token: token });
    window.channel = this.channel;
    this.channel.join()
      .receive("ok", resp => { console.log(`joined game:${this.game_id}`, resp) })
      .receive("error", resp => { console.error("unable to join", resp) })

    this.channel.on("state", payload => {
      this.handleGameState(payload)
    });

    this.channel.on("new_proposed", payload => {
      if (this.current_player === this.player) { return }
      this.handleProposed(payload);
    });

    this.channel.on("error", payload => {
      this.flash("error", payload);
    });

    this.channel.on("info", payload => {
      this.flash("info", payload);
    });

    this.channel.on("rack", payload => {
      this.handleRack(payload);
    });

    this.didReceiveAttrs();
  }

  flash(level, { message }) {
    this.flash_container.html(message);
    this.flash_container.classed("alert-danger", level === "error");
  }

  handleProposed(payload) {
    this.proposed = payload;
    this.drawSquares();
  }

  handleGameState(payload) {
    if (payload.current_player) {
      this.current_player = payload.current_player // FIXME: where does this logic belong?
      this.flash("info", { message: `${this.current_player}'s turn`});
    }

    if (payload.board) {
      this.proposed = {};
      this.data = payload.board;
    }

    this.scores = payload.scores;
    this.players = payload.players;

    this.drawSquares();
    this.drawScores();
    this.drawStartButton();
    this.drawSwapButton();
    this.gameOver = payload.gameOver;
  }

  handleRack(payload) {
    if (payload.rack) {
      this.rack = payload.rack;
    }
  }

  get rack() {
    return this._rack;
  }

  pushRack(char) {
    if (char[0] === ":") {
      this.rack.push("BLANK")
    } else {
      this.rack.push(char)
    }

    this.drawRack();
  }

  set rack(newRack) {
    // FIXME: use a proxy to draw on push as well?
    this._rack = newRack;
    this.drawRack();
  }

  didReceiveAttrs() {
    // Schedule a call to our `drawCircles` method on Ember's "render" queue, which will
    // happen after the component has been placed in the DOM, and subsequently
    // each time data is changed.
    // run.scheduleOnce('render', this, this.drawSquares)

    let component = this;
    // FIXME: where to put
    select(window).on('keydown', function() {
      if (component.player !== component.current_player) {
        return;
      }
      // console.info(event, event.key, event.which);

      if (event.ctrlKey) {
        return;
      }

      switch (event.key) {
        case "ArrowUp": {
          event.preventDefault();
          return component.moveByArrow(0, -1);
        }
        case "ArrowDown": {
          event.preventDefault();
          return component.moveByArrow(0, 1);
        }
        case "ArrowLeft": {
          event.preventDefault();
          return component.moveByArrow(-1, 0);
        }
        case "ArrowRight": {
          event.preventDefault();
          return component.moveByArrow(1, 0);
        }
        case "Enter": {
          event.preventDefault();
          return component.submitProposed();
        }
      }

      if (event.which === 8) {
        component.setProposed(null);
      }

      if (event.which >= 65 && event.which <= 90) {
        component.setProposed(String.fromCharCode(event.which));
      }
    });
  }

  moveByArrow(dx, dy) {
    let want;

    if (dy !== 0) {
      want = 'v'
    } else {
      want = 'h'
    }

    if (want === this.direction) {
      return this.moveCursor(dx, dy);
    } else {
      this.direction = want;
      if (this.currentTileSelection().html() === "") { // FIXME: used proposed data
        return this.setCursor(this.cursor); // stay here, but change direction
      } else {
        return this.moveCursor(dx, dy);
      }
    }
  }

  currentTileSelection() {
    return select(`#tile-${this.cursor}`);
  }

  moveCursor(dx, dy) {
    let x = this.cursorX() + dx;
    let y = this.cursorY() + dy;

    if ((dx > 0 && x > (this.size - 1)) || (dx < 0 && x < 0)) {
      return false;
    }

    if ((dy > 0 && y > (this.size - 1)) || (dy < 0 && y < 0)) {
      return false;
    }

    this.setCursorXY(x, y);
    return true;
  }

  setCursorXY(x, y) {
    this.setCursor((this.size * y) + x);
  }

  cursorX() {
    return this.cursor % this.size;
  }

  cursorY() {
    return Math.floor(this.cursor / this.size);
  }

  setProposed(char) {
    if (this.data[this.cursor].character !== undefined) {
      return this.reverseCursor();
    }

    let tile = select(`#tile-${this.cursor}`)

    if (char === null) {
      if (tile.html() === "") { // back up to last set tile
        if (this.reverseCursor()) {
          return this.setProposed(null);
        }
      }
      tile.html('').classed("tile-proposed", false)
        .classed("tile-blank", false);
      this.deleteProposed(this.cursor);
      this.reverseCursor();
    } else {
      if (this.updateProposed(this.cursor, char)) {
        let isBlank = this.proposed[this.cursor][0] === ":"
        tile.html(this.proposed[this.cursor]).classed("tile-proposed", true)
          .classed("tile-blank", isBlank);
        this.advanceCursor();
      }
    }
  }

  deleteProposed(cursor) {
    let d = this.proposed[cursor];
    delete this.proposed[cursor];
    if (d) {
      this.pushRack(d);
    }
    console.info(d);
    this.sendProposed();
  }

  updateProposed(cursor, char) {
    let current = this.proposed[cursor]
    let usingBlank = false;
    let i = this.rack.indexOf(char);
    if (i < 0) {
      i = this.rack.indexOf("BLANK");

      if (i < 0) { return false }
      usingBlank = true;
    }

    this.rack.splice(i, 1);
    if (current) {
      this.pushRack(current);
    }

    this.proposed[cursor] = `${usingBlank ? ":" : ""}${char}`
    this.sendProposed();
    this.drawRack();

    return true;
  }

  submitProposed() {
    this.channel.push("submit_payload", this.proposed);
  }

  sendProposed() {
    this.channel.push("proposed", this.proposed);
  }

  sendSwapped(str) {
    this.channel.push("swap", str);
  }

  clickSetCursor(i) {
    let tile = select(`#tile-${this.cursor}`);
    if (this.cursor === i) {
      if (this.direction === "h") {
        this.direction = "v"
      } else {
        this.direction = "h"
      }
    }

    this.setCursor(i);
  }

  setCursor(i) {
    let tile = select(`#tile-${this.cursor}`);
    tile.classed('cursor', false);
    this.cursor = i;
    tile = select(`#tile-${this.cursor}`);
    tile.classed('cursor', true);
    tile.classed('cursor-h', this.direction === "h");
  }

  advanceCursor() {
    if (this.direction === "h") {
      return this.moveCursorToNextEmpty(1, 0);
    } else {
      return this.moveCursorToNextEmpty(0, 1);
    }
  }

  moveCursorToNextEmpty(dx, dy) {
    if (this.moveCursor(dx, dy)) {
      if (this.data[this.cursor].character !== undefined) {
        return this.moveCursorToNextEmpty(dx, dy)
      }

      return true;
    }

    return false;
  }

  reverseCursor() {
    if (this.direction === "h") {
      return this.moveCursor(-1, 0);
    } else {
      return this.moveCursor(0, -1);
    }
  }

  drawSquares() {
    let container = this.element;
    let data = this.data;

    container.classed('current', this.current_player == this.player);

    if (data.length === 441) {
      this.size = 21; // FIXME: better way to set this once
      container.classed('super', true)
    }

    let squares = container.selectAll('div.board-square').data(data);
    let enterJoin = squares
      .enter()
      .append('div')
      .attr('class', d => `board-square ${d.bonus || ''}`)
      .attr('id', (d, i) => `tile-${i}`);

    enterJoin.on('click', (d, i) => this.clickSetCursor(i))

    let currentSquares = squares.merge(enterJoin);
    currentSquares.classed("tile", d => d.character);
    currentSquares.classed("tile-blank", d => d.character && d.character[0] == ":");
    currentSquares.classed("tile-proposed", (d, i) => this.proposed[i]);
    currentSquares.filter((d) => d.has_cursor).classed("cursor", true);
    currentSquares.html((d, i) => {
      if (d.character && d.character[0] == ":") {
        return d.character[1];
      } else {
        return d.character || this.proposed[i] || "";
      }
    });
    squares.exit().remove();
  }

  drawRack() {
    let container = this.rack_container;
    let squares = container.selectAll('div.rack-square').data(this.rack);
    let enterJoin = squares
      .enter()
      .append('div')
      .attr('class', 'rack-square tile')

    let currentSquares = squares.merge(enterJoin);
    currentSquares.html(d => d === "BLANK" ? "" : d);
    squares.exit().remove();

    let button = select('#submit-button-container').selectAll('button.submit-button').data([1]);
    button.enter()
      .append('button')
      .attr('class', 'submit-button')
      .html('SUBMIT')
      .on("click", () => { this.submitProposed() });
  }

  drawScores() {
    // FIXME: this is a mess
    let scoreCount = 0;
    for (let player in this.scores) {
      scoreCount = Math.max(this.scores[player].length, scoreCount);
    }

    // count of all rows needed
    let data = [];
    for (let i = 0; i < scoreCount; i++) {
      data.push(i);
    }

    let component = this;
    let scores = this.scores;
    let players = this.players;

    let table = select('#score-container table');
    let headerSelection = table.select('thead').selectAll('tr').data([0]);
    let headEnter = headerSelection.enter()
      .append('tr').attr('id', 'score-header')

    headerSelection = headerSelection.merge(headEnter);
    let thSelection = headerSelection.selectAll('th').data(players);
    thSelection = thSelection.merge(thSelection.enter().append('th'));
    thSelection.html(function (player) {
      return `${player} (${component.totalScore(player)})`
    }).classed('current-player', (d) => this.current_player == d)
    .classed('is-player', (d) => this.player == d);

    let rowSelection = table.select('tbody').selectAll('tr').data(data);
    let row_entry = rowSelection.enter().append('tr')
    let rows = rowSelection.merge(row_entry);
    rows.each(function(d) {
      let cells = select(this).selectAll('td').data(players)
      let cell_entry = cells.enter().append('td');
      cells = cells.merge(cell_entry);

      cells.html(function (p) {
        return (scores[p][d] || []).join(' ')
      });
    })
  }

  totalScore(player) {
    let sum = 0;
    this.scores[player].forEach(turn => {
      turn.forEach(word => {
        sum += word[1]
      })
    })

    return sum;
  }

  drawStartButton() {
    let data = [];
    if (!this.current_player) {
      data.push(0);
    }

    let selection = this.header.selectAll('button').data(data);
    let channel = this.channel

    selection.enter()
      .append('button')
      .attr('class', 'start-button')
      .html("click here to start")
      .on("click", () => { channel.push("start") });

    selection.exit().remove();
  }

  drawSwapButton() {
    let data = [];
    if (this.current_player === this.player) {
      data.push(0);
    }

    let selection = select('#submit-button-container').selectAll('button#swap-button').data(data);

    let component = this;
    selection.enter()
      .append('button')
      .attr('id', 'swap-button')
      .html("SWAP")
      .on('click', () => {
        let response = window.prompt("please enter letters to swap, separated by spaces. Enter BLANK to swap a blank.");
        if (response) {
          component.sendSwapped(response);
        }
      });

    selection.exit().remove();
  }
}

export default Scrabble
