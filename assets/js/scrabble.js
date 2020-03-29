// Import the D3 packages we want to use
import { scaleLinear } from 'd3-scale'
import { select } from 'd3-selection'
import { extent, ascending } from 'd3-array'
import { transition } from 'd3-transition'
import { easeCubicInOut } from 'd3-ease'

class Scrabble {
  // FIXME: add player scores
  // FIXME: show scoring
  // FIXME: add a 'start' button
  // FIXME: join a specific game by id

  // Array of points to render as circles in a line, spaced by time.
  //  [ {value: Number, timestamp: Number } ];
  constructor(socket) {
    window.game = this
    this.socket = socket
    this.cursor = -1;
    this.element = select("section.board-container");
    this.header = select("section.board-header");
    this.rack_container = select("section.rack-container");
    this.direction = 'h'; // or 'v';
    this.player = undefined;
    this.current_player = undefined;
    this.proposed = {};

    this.drawJoinInput();
  }

  drawJoinInput() {
    if (this.player) {
      return this.header.selectAll('div').remove();
    }

    let s = this.header;
    let component = this;
    let div = s
      .append('div')
        .attr('class', 'join-input')
    let input = div
      .append('input')
        .attr('type', 'text')
        .attr('placeholder', 'enter your name')
    let button = div
      .append('button')
        .html('join')
        .on('click', function() {
          let name = input._groups[0][0].value
          component.joinGameAs(name);
        });
  }

  joinGameAs(name) {
    this.player = name;
    this.drawJoinInput();

    // FIXME: get name from somewhere else
    this.channel = this.socket.channel("game:default", { name: name });
    window.channel = this.channel;
    this.channel.join()
      .receive("ok", resp => { console.log("joined game:default", resp) })
      .receive("error", resp => { console.error("unable to join", resp) })

    this.channel.on("state", payload => {
      this.handleGameState(payload)
    });

    this.channel.on("board", payload => {
      this.handleBoard(payload)
    });

    this.channel.on("new_proposed", payload => {
      this.handleProposed(payload);
    });

    this.channel.on("turn", payload => {
      console.info("turn", payload)

      if (payload.player) {
        this.current_player = payload.player;
      }
    });

    this.channel.on("error", payload => {
      console.error(payload) // FIXME: render a message
    });

    this.channel.on("rack", payload => {
      this.handleRack(payload);
    });

    this.didReceiveAttrs();
  }

  handleBoard(payload) {
    if (payload.current_player) {
      this.current_player = payload.current_player // FIXME: where does this logic belong?
    }
    this.proposed = {};
    this.data = payload.board
    this.drawSquares();
  }

  handleProposed(payload) {
    this.proposed = payload;
    this.drawSquares();
  }

  handleGameState(payload) {
    // debugger;
    if (payload.current_player) {
      this.current_player = payload.current_player // FIXME: where does this logic belong?
    }

    if (payload.board) {
      this.proposed = {};
      this.data = payload.board;
    }

    console.info(
      (payload.scores[this.player][0] || []).join(" ")
    );

    this.drawSquares();
  }

  handleRack(payload) {
    if (payload.rack) {
      this.rack = payload.rack;
      this.drawRack();
    }
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
          return component.moveByArrow(0, -1);
        }
        case "ArrowDown": {
          return component.moveByArrow(0, 1);
        }
        case "ArrowLeft": {
          return component.moveByArrow(-1, 0);
        }
        case "ArrowRight": {
          return component.moveByArrow(1, 0);
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

    if ((dx > 0 && x > 14) || (dx < 0 && x < 0)) {
      return false;
    }

    if ((dy > 0 && y > 14) || (dy < 0 && y < 0)) {
      return false;
    }

    this.setCursorXY(x, y);
    return true;
  }

  setCursorXY(x, y) {
    this.setCursor((15 * y) + x);
  }

  cursorX() {
    return this.cursor % 15;
  }

  cursorY() {
    return Math.floor(this.cursor / 15);
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
      tile.html('').classed("tile-proposed", false);
      this.deleteProposed(this.cursor);
      this.reverseCursor();
    } else {
      if (this.updateProposed(this.cursor, char)) {
        tile.html(char).classed("tile-proposed", true);
        this.advanceCursor();
      }
    }
  }

  deleteProposed(cursor) {
    let d = this.proposed[cursor];
    delete this.proposed[cursor];
    this.rack.push(d);
    this.drawRack();
    console.info(d);
    this.sendProposed();
  }

  updateProposed(cursor, char) {
    let current = this.proposed[cursor]

    let i = this.rack.indexOf(char);
    if (i < 0) { return false }

    this.rack.splice(i, 1);
    if (current) {
      this.rack.push(current);
    }
    this.proposed[cursor] = char
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

    let squares = container.selectAll('div.board-square').data(data);
    let enterJoin = squares
      .enter()
      .append('div')
      .attr('class', d => `board-square ${d.bonus || ''}`)
      .attr('id', (d, i) => `tile-${i}`);

    enterJoin.on('click', (d, i) => this.setCursor(i))

    let currentSquares = squares.merge(enterJoin);
    currentSquares.classed("tile", d => d.character);
    currentSquares.classed("tile-proposed", (d, i) => this.proposed[i]);
    currentSquares.filter((d) => d.has_cursor).classed("cursor", true);
    currentSquares.html((d, i) => d.character || this.proposed[i] || "");
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
    currentSquares.html(d => d);
    squares.exit().remove();

    let button = select('#submit-button-container').selectAll('button').data([1]);
    button.enter()
      .append('button')
      .attr('class', 'submit-button')
      .html('SUBMIT')
      .on("click", () => { this.submitProposed() });
  }
}

export default Scrabble
