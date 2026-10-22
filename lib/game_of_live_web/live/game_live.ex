defmodule GameOfLiveWeb.GameLive do
  use GameOfLiveWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       name: "",
       tick: 100,
       grid: MapSet.new(),
       working_grid: MapSet.new(),
       size: {100, 100},
       run: false,
       show_grid: "",
       share_url: nil,
       count: 0,
       page_title: "New Game",
       mode: :draw
     )}
  end

  @impl true
  def handle_params(_params = %{"name" => name}, _uri, socket) do
    server =
      case Registry.lookup(GameOfLive.GameRegistry, name) do
        [] ->
          {:ok, pid} = GameOfLive.GameServer.start_server(%{name: name})
          pid

        [{server, _pid}] ->
          server
      end

    Phoenix.PubSub.subscribe(GameOfLive.PubSub, "game:#{name}")
    GameOfLive.GameServer.subscribe(server)
    {:ok, assigns = %{count: count}} = GameOfLive.GameServer.get_state(server)

    {:noreply,
     socket
     |> assign(server: server, name: name, page_title: page_title(count))
     |> assign(assigns)}
  end

  def handle_params(_params, _uri, socket) do
    if connected?(socket) do
      name = Nanoid.generate()
      {:ok, _pid} = GameOfLive.GameServer.start_server(%{name: name})

      {:noreply, push_patch(socket, to: ~p"/game/#{name}")}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("toggle", _, socket = %{assigns: %{server: server}}) do
    GameOfLive.GameServer.toggle(server)

    {:noreply, socket}
  end

  def handle_event("click", _params = %{"offset_x" => x, "offset_y" => y}, socket) do
    %{assigns: %{working_grid: grid}} = socket
    coords = {div(x, 10), div(y, 10)}

    grid =
      if MapSet.member?(grid, coords),
        do: MapSet.delete(grid, coords),
        else: MapSet.put(grid, coords)

    {:noreply, assign(socket, :working_grid, grid)}
  end

  def handle_event("draw", _params = %{"offset_x" => x, "offset_y" => y}, socket) do
    %{assigns: %{mode: mode}} = socket
    coords = {div(x, 10), div(y, 10)}

    {:noreply,
     update(socket, :working_grid, fn grid ->
       if mode == :draw do
         MapSet.put(grid, coords)
       else
         MapSet.delete(grid, coords)
       end
     end)}
  end

  def handle_event("toggle_mode", _params, socket) do
    {:noreply,
     update(socket, :mode, fn
       :draw -> :erase
       :erase -> :draw
     end)}
  end

  def handle_event("apply_work", _params, socket) do
    %{assigns: %{server: server, grid: grid, working_grid: work_grid}} = socket
    GameOfLive.GameServer.set_grid(server, MapSet.union(grid, work_grid))
    {:noreply, assign(socket, :working_grid, MapSet.new())}
  end

  def handle_event("save_tick", %{"tick" => tick}, socket = %{assigns: %{server: server}}) do
    GameOfLive.GameServer.set_tick(server, String.to_integer(tick))

    {:noreply, socket}
  end

  def handle_event("clear", _, socket) do
    %{assigns: %{server: server, working_grid: work_grid}} = socket
    # first clear the working grid, then the global grid
    if MapSet.size(work_grid) > 0 do
      {:noreply, assign(socket, :working_grid, MapSet.new())}
    else
      GameOfLive.GameServer.set_grid(server, MapSet.new())
      {:noreply, socket}
    end
  end

  def handle_event("dump", _params, socket = %{assigns: %{grid: grid}}) do
    grid_json = Enum.map(grid, fn {x, y} -> [x, y] end) |> Jason.encode!()

    socket
    |> assign(:show_grid, grid_json)
    |> then(&{:noreply, &1})
  end

  def handle_event("load", %{"json" => grid_json}, socket = %{assigns: %{server: server}}) do
    case Jason.decode(grid_json) do
      {:ok, points} when is_list(points) ->
        GameOfLive.GameServer.set_grid(
          server,
          MapSet.new(Enum.map(points, fn [x, y] -> {x, y} end))
        )

        {:noreply, assign(socket, :show_grid, grid_json)}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("share_link", _params, socket = %{assigns: %{grid: grid}}) do
    url = share_url(grid)

    socket
    |> assign(:share_url, url)
    |> then(&{:noreply, &1})
  end

  @impl true
  def handle_info({:run, run}, socket), do: {:noreply, assign(socket, :run, run)}
  def handle_info({:grid, grid}, socket), do: {:noreply, assign(socket, :grid, grid)}
  def handle_info({:tick, tick}, socket), do: {:noreply, assign(socket, :tick, tick)}

  def handle_info({:count, count}, socket),
    do: {:noreply, assign(socket, count: count, page_title: page_title(count))}

  defp page_title(1), do: "1 player"
  defp page_title(n), do: "#{n} players"

  defp share_url(grid) do
    board_json = Enum.map(grid, fn {x, y} -> [x, y] end) |> Jason.encode!()

    url(~p"/s?#{%{"board" => board_json}}")
  end

  defp success_btn(to) do
    JS.transition("bg-green-500 hover:bg-green-500 text-zinc-800", time: 1000, to: to)
  end

  defp error_btn(to) do
    JS.transition("bg-red-500 hover:bg-red-500", time: 1000, to: to)
  end


  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <:navbar_right>
        <.icon name={if @count > 1, do: "hero-users", else: "hero-user"} class="size-6" />
        <span class="ml-2 text-zinc-800 dark:text-zinc-200">{page_title(@count)}</span>
      </:navbar_right>

      <div class="flex-1 flex flex-col overflow-hidden">
        <div class="flex-1 flex items-stretch overflow-hidden">
          <div class="flex-1 overflow-y-auto p-4">
            <section class="min-w-0 flex-1 h-full flex flex-col lg:order-last">
              <svg
                id="game"
                viewBox="0 0 1000 1000"
                width="1000"
                height="1000"
                class="bg-white dark:bg-zinc-900 shadow-sm mx-auto w-full h-auto max-w-[calc(100vh-10rem)] max-h-[calc(100vh-10rem)] touch-pinch-zoom"
                phx-hook=".Draw"
              >
                <%!-- https://stackoverflow.com/questions/22013281/drawing-a-grid-using-svg-markup --%>
                <defs>
                  <pattern id="tenthGrid" width="10" height="10" patternUnits="userSpaceOnUse">
                    <path d="M 10 0 L 0 0 0 10" fill="none" stroke="silver" stroke-width="0.5" />
                  </pattern>
                  <pattern id="grid" width="100" height="100" patternUnits="userSpaceOnUse">
                    <rect width="100" height="100" fill="url(#tenthGrid)" />
                    <path d="M 100 0 L 0 0 0 100" fill="none" stroke="gray" stroke-width="1" />
                  </pattern>
                </defs>
                <rect width="100%" height="100%" fill="url(#grid)" />
                <rect
                  :for={{x, y} <- @grid}
                  x={x * 10}
                  y={y * 10}
                  width="10"
                  height="10"
                  fill="currentColor"
                  class="text-primary-600 dark:text-primary-500"
                />
                <rect
                  :for={{x, y} <- @working_grid}
                  x={x * 10}
                  y={y * 10}
                  width="10"
                  height="10"
                  fill="currentColor"
                  class="text-green-600 dark:text-green-500"
                />
              </svg>
            </section>
          </div>
        </div>
        <.modal id="settings" no_border>
          <.card>
            <:title>Settings</:title>
            <h3 class="text-md mb-2">Load or Dump the Game Grid</h3>
            <form phx-submit="load" class="my-4">
              <div class="flex items-end">
                <.textarea id="dump-area" name="json" rows="5">{@show_grid}</.textarea>
                <.copy_button id="copy-dump-btn" target="#dump-area" />
              </div>
              <div class="mt-4">
                <.button type="submit" phx-click={hide_modal("settings")}>Load grid</.button>
                <.button id="dump-btn" type="button" phx-click="dump">Dump grid</.button>
              </div>
            </form>
            <hr class="my-4 border-zinc-300 dark:border-zinc-700" />
            <h3 class="text-md mb-2">Tick Speed</h3>
            <form phx-change="save_tick">
              <input type="range" min="10" max="1000" value={@tick} name="tick" />
              <span>{@tick}</span>
            </form>
          </.card>
        </.modal>
        <.modal id="share" no_border>
          <.card>
            <:title>Share this board</:title>
            <p class="mb-4">
              Use the following button to create a permanent link to the current board state:
            </p>

            <.button id="share-url-btn" class="mb-4" phx-click="share_link">
              Generate Link
            </.button>

            <div :if={@share_url} class="flex items-end mb-4">
              <.textarea id="share-url" rows="5">{@share_url}</.textarea>
              <.copy_button id="copy-share-url-btn" target="#share-url" />
            </div>

            <hr class="border-zinc-300 dark:border-zinc-700" />

            <p class="my-4">
              If you want others to join the current game session, just send them the current URL.
            </p>

            <div class="flex items-end">
              <.textarea id="current-url" rows="2">{url(~p"/game/#{@name}")}</.textarea>
              <.copy_button id="copy-current-url-btn" target="#current-url" />
            </div>
          </.card>
        </.modal>
        <.modal id="info" no_border>
          <.card>
            <:title>Information</:title>
            <p class="mb-4">
              This game implements
              <a class="underline" href="https://en.wikipedia.org/wiki/Conway's_Game_of_Life">
                Conway's Game of Life
              </a>
              using <a class="underline" href="https://www.phoenixframework.org/">Phoenix LiveView</a>.
            </p>

            <p class="mb-4">The game is played on a grid of cells. In each game step:</p>

            <ol class="list-decimal list-inside">
              <li>
                Any live cell with fewer than two live neighbours dies, as if by underpopulation.
              </li>
              <li>
                Any live cell with two or three live neighbours lives on to the next generation.
              </li>
              <li>Any live cell with more than three live neighbours dies, as if by overpopulation.</li>
              <li>
                Any dead cell with exactly three live neighbours becomes a live cell, as if by reproduction.
              </li>
            </ol>
          </.card>
        </.modal>
      </div>

      <script :type={Phoenix.LiveView.ColocatedHook} name=".Draw">
        export default {
          calcOffset(e) {
            // as the svg is scaled to 100% width and height,
            // we need to scale the coordinates
            const r = this.el.getBoundingClientRect();
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
              const r = this.el.getBoundingClientRect();
              e.offsetX = parseInt(e.touches[0].clientX - r.left);
              e.offsetY = parseInt(e.touches[0].clientY - r.top);
              return fun(e);
            };
          },
          mounted() {
            // mouse events
            this.el.addEventListener("mousedown", this.drawstart.bind(this));
            this.el.addEventListener("mousemove", this.drawmove.bind(this));
            this.el.addEventListener("mouseup", this.drawend.bind(this));
            // touch events
            this.el.addEventListener("touchstart", this.touchwrap(this.drawstart.bind(this)), {passive: true});
            this.el.addEventListener("touchmove", this.touchwrap(this.drawmove.bind(this)), {passive: true});
            this.el.addEventListener("touchend", this.touchwrap(this.drawend.bind(this)));
          }
        }
      </script>

      <:bottom_bar>
        <.icon_button
          title={if @run, do: "Pause Game", else: "Start Game"}
          icon={if @run, do: "hero-pause-mini", else: "hero-play-mini"}
          phx-click="toggle"
        />
        <.icon_button
          title="Clear Grid"
          icon="hero-x-mark-mini"
          phx-click="clear"
          disabled={MapSet.size(@working_grid) == 0 && MapSet.size(@grid) == 0}
        />
        <.icon_button
          title="Apply Changes"
          icon="hero-check-mini"
          phx-click="apply_work"
          disabled={MapSet.size(@working_grid) == 0}
        />
        <.icon_button
          title={"Change mode to: #{if @mode == :draw, do: "Erase", else: "Draw"}"}
          icon={if @mode == :draw, do: "hero-trash-mini", else: "hero-pencil-mini"}
          phx-click="toggle_mode"
        />
        <.icon_button title="Share" icon="hero-share-mini" phx-click={show_modal("share")} />
        <.icon_button
          title="Game Settings"
          icon="hero-cog-6-tooth-mini"
          phx-click={show_modal("settings")}
        />
        <.icon_button title="Information" icon="hero-information-circle-mini" phx-click={show_modal("info")} />
      </:bottom_bar>
    </Layouts.app>
    """
  end

  attr :id, :string, required: true
  attr :target, :string, required: true, doc: "selector of the element whose text is copied"

  defp copy_button(assigns) do
    ~H"""
    <.button
      id={@id}
      class="ml-2 transition ease-out-300 flex-0"
      phx-click={JS.dispatch("phx:copy", to: @target, detail: %{"el" => "##{@id}"})}
      data-copy-success={success_btn("##{@id}")}
      data-copy-error={error_btn("##{@id}")}
    >
      Copy
    </.button>
    """
  end
end
