// We import the CSS which is extracted to its own file by esbuild.
// Remove this line if you add a your own CSS build pipeline (e.g postcss).

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

// https://stackoverflow.com/questions/400212/how-do-i-copy-to-the-clipboard-in-javascript
const copyHelper = {
    fallbackCopyTextToClipboard(text) {
        var textArea = document.createElement("textarea");
        textArea.value = text;
        
        // Avoid scrolling to bottom
        textArea.style.top = "0";
        textArea.style.left = "0";
        textArea.style.position = "fixed";
        textArea.style.display = "none";

        document.body.appendChild(textArea);
        textArea.focus();
        textArea.select();
      
        try {
            if (document.execCommand("copy")) {
                this.handleSuccess();
            } else {
                this.handleError();
            }
        } catch (err) {
            console.error("legacy copy error", err);
            this.handleError();
        }
      
        document.body.removeChild(textArea);
    },
    copyTextToClipboard(text) {
        if (!navigator.clipboard) {
            this.fallbackCopyTextToClipboard(text);
            return;
        }
        navigator.clipboard.writeText(text).then(() => {
            this.handleSuccess();
        }, (err) => {
            console.error("clipboard api error", err);
            this.fallbackCopyTextToClipboard(text);
        });
    },
    handleSuccess() {
        if (!this.el) return; 
        const js = this.el.getAttribute("data-copy-success");
        if (js) {
            this.liveSocket.execJS(this.el, js);
        }
    },
    handleError() {
        if (!this.el) return; 
        const js = this.el.getAttribute("data-copy-error");
        if (js) {
            this.liveSocket.execJS(this.el, js);
        }
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

let topBarScheduled = undefined;
window.addEventListener("phx:page-loading-start", () => {
  if(!topBarScheduled) {
    topBarScheduled = setTimeout(() => topbar.show(), 120);
  };
});
window.addEventListener("phx:page-loading-stop", () => {
  clearTimeout(topBarScheduled);
  topBarScheduled = undefined;
  topbar.hide();
});
// our own helpers
window.addEventListener("gol:toggle-aria", (event) => {
  const current = event.target.getAttribute("aria-expanded");
  event.target.setAttribute("aria-expanded", current === "true" ? "false" : "true");
});
window.addEventListener("js:exec-timeout", (e) => {
  if (e.detail.timeout) {
    setTimeout(() => {
      liveSocket.execJS(e.target, e.target.getAttribute(e.detail.js));
    }, e.detail.timeout);
  }
});
window.addEventListener("phx:copy", (e) => {
    const that = { liveSocket, ...e.detail, ...copyHelper };
    if (e.detail.el) {
        // this should be the element that was clicked,
        // set it to this inside the copyHelper
        that.el = document.querySelector(e.detail.el);
    }
    if (e.target !== window && !e.detail.to) {
        // we got a target from the client, e.g.
        // JS.dispatch("phx:copy", { to: "#my-target" });
        e.detail.to = e.target;
    } else if (e.detail.to) {
        // we got a target from the server, e.g.
        // push_event("copy", %{"to" => "#my-target"});
        // NOTE: currently not supported in Safari...
        e.detail.to = document.querySelector(e.detail.to);
    }
    console.log(e.detail);
    // either copy text directly from detail, or use innerText from
    // the target element
    if (e.detail.text) {
        copyHelper.copyTextToClipboard.bind(that)(e.detail.text);
    } else if (e.detail.to) {
        const el = e.detail.to;
        const text = el.innerText || el.innerHTML || el.value;
        copyHelper.copyTextToClipboard.bind(that)(text);
    } else {
        console.error("invalid use of copy event! expected detail.text or detail.to");
    }
});

// connect if there are any LiveViews on the page
liveSocket.connect();

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket;
