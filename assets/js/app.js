// We import the CSS which is extracted to its own file by esbuild.
// Remove this line if you add a your own CSS build pipeline (e.g postcss).
import "../css/app.css"

// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "./vendor/some-package.js"
//
// Alternatively, you can `npm install some-package` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html";
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix";
import {LiveSocket} from "phoenix_live_view";
import topbar from "../vendor/topbar";

const Hooks = {};
Hooks.Draw = {
    calcOffset(e) {
        // as the svg is scaled to 100% width and height,
        // we need to scale the coordinates
        r = this.el.getBoundingClientRect();
        return {
            offset_x: parseInt(e.offsetX * (1000 / r.width)),
            offset_y: parseInt(e.offsetY * (1000 / r.height))
        };
    },
    drawstart(_e) {
        this.draw = true;
        this.move = false;
    },
    drawmove(e) {
        if (!this.draw) return;
        if (!this.move) {
            this.move = true;
        } else {
            this.pushEvent("draw", this.calcOffset(e));
        }
    },
    drawend(e) {
        this.draw = false;
        if (this.move) {
            this.pushEvent("draw", this.calcOffset(e));
        } else {
            // there was no move -> click event toggles
            this.pushEvent("click", this.calcOffset(e));
        }
        this.move = false;
    },
    touchwrap(fun) {
        // this function calculates the offsetX and offsetY
        // events that are missing from touch events
        // and allows us to treat them the same as mouse moves
        return (e) => {
            if (!e.touches[0]) return;
            // do not draw on zoom
            if (e.scale !== 1) return;
            // https://stackoverflow.com/a/59411792
            r = this.el.getBoundingClientRect();
            e.offsetX = parseInt(e.touches[0].clientX - r.left);     
            e.offsetY = parseInt(e.touches[0].clientY - r.top);
            return fun(e);
        }
    },
    mounted() {
        // mouse events
        this.el.addEventListener("mousedown", this.drawstart.bind(this));
        this.el.addEventListener("mousemove", this.drawmove.bind(this));
        this.el.addEventListener("mouseup", this.drawend.bind(this));
        // touch events
        this.el.addEventListener("touchstart", this.touchwrap(this.drawstart.bind(this)), { passive: true });
        this.el.addEventListener("touchmove", this.touchwrap(this.drawmove.bind(this)), { passive: true });
        this.el.addEventListener("touchend", this.touchwrap(this.drawend.bind(this)));
    },
};

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");
let liveSocket = new LiveSocket("/live", Socket, {
    params: {
        _csrf_token: csrfToken
    },
    hooks: Hooks,
});

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"});
window.addEventListener("phx:page-loading-start", info => topbar.show());
window.addEventListener("phx:page-loading-stop", info => topbar.hide());

// connect if there are any LiveViews on the page
liveSocket.connect();

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket;
