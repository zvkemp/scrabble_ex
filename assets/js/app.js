// We need to import the CSS so that webpack will load it.
// The MiniCssExtractPlugin is used to separate it out into
// its own CSS file.
import css from "../css/app.css"

// webpack automatically bundles all modules in your
// entry points. Those entry points can be configured
// in "webpack.config.js".
//
// Import dependencies
//
import "phoenix_html"
import socket from "./socket"
import Scrabble from "./scrabble"
import LiveSocket from "phoenix_live_view"

// Import local files
//
// Local files can be imported directly using relative paths, for example:
if (document.querySelector('meta[name="id-token"]')) {
  socket.connect();
  const scrabble = new Scrabble(socket);
}

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");
let liveSocket = new LiveSocket("/live", Socket, {params: {_csrf_token: csrfToken}});

// connect if there are any LiveViews on the page
liveSocket.connect()
window.liveSocket = liveSocket
