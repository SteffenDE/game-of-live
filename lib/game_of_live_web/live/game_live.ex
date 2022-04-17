defmodule GameOfLiveWeb.GameLive do
  use GameOfLiveWeb, :live_view

  alias Phoenix.LiveView.JS

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       navbar_right: &render_nav_right/1,
       after_content: &render_bottom_bar/1,
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

      {:noreply, push_patch(socket, to: Routes.game_path(socket, :game, name))}
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

  def handle_event("dump", %{"copy-el" => el}, socket = %{assigns: %{grid: grid}}) do
    grid_json = Enum.map(grid, fn {x, y} -> [x, y] end) |> Jason.encode!()

    socket
    |> assign(:show_grid, grid_json)
    |> push_event("copy", %{"text" => grid_json, "el" => el})
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

  def handle_event("share_link", %{"copy-el" => el}, socket = %{assigns: %{grid: grid}}) do
    url = share_url(grid)

    socket
    |> assign(:share_url, url)
    |> push_event("copy", %{"text" => url, "el" => el})
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

    Routes.share_url(GameOfLiveWeb.Endpoint, :index, %{"board" => board_json})
  end

  defp render_bottom_bar(assigns) do
    ~H"""
    <nav class="bg-white dark:bg-zinc-900 border-t-2 dark:border-zinc-700 dark:text-zinc-200 absolute bottom-0 w-full">
      <div class="mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex justify-between h-16">
          <div class="flex m-auto space-x-2">
            <button
              type="button"
              title={if @run, do: "Pause Game", else: "Start Game"}
              phx-click="toggle"
              class="inline-flex items-center p-1.5 border border-transparent rounded-full shadow-sm text-white bg-primary-600 hover:bg-primary-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-primary-500"
            >
              <.icon name={if @run, do: :pause, else: :play} class="h-5 w-5" />
            </button>
            <button
              type="button"
              title="Clear Grid"
              phx-click="clear"
              disabled={MapSet.size(@working_grid) == 0 && MapSet.size(@grid) == 0}
              class="disabled:bg-zinc-300 dark:disabled:bg-zinc-700 disabled:cursor-not-allowed inline-flex items-center p-1.5 border border-transparent rounded-full shadow-sm text-white bg-primary-600 hover:bg-primary-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-primary-500"
            >
              <.icon name={:x} class="h-5 w-5" />
            </button>
            <button
              type="button"
              title="Apply Changes"
              phx-click="apply_work"
              disabled={MapSet.size(@working_grid) == 0}
              class={
                "disabled:bg-zinc-300 dark:disabled:bg-zinc-700 disabled:cursor-not-allowed inline-flex items-center p-1.5 border border-transparent rounded-full shadow-sm text-white bg-primary-600 hover:bg-primary-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-primary-500 #{}"
              }
            >
              <.icon name={:check} class="h-5 w-5" />
            </button>
            <button
              type="button"
              title={"Change mode to: #{if @mode == :draw, do: "Erase", else: "Draw"}"}
              phx-click="toggle_mode"
              class={
                "inline-flex items-center p-1.5 border border-transparent rounded-full shadow-sm text-white bg-primary-600 hover:bg-primary-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-primary-500 #{}"
              }
            >
              <.icon name={if @mode == :draw, do: :trash, else: :pencil} class="h-5 w-5" />
            </button>
            <button
              type="button"
              title="Share"
              phx-click={show_modal("share")}
              class={
                "inline-flex items-center p-1.5 border border-transparent rounded-full shadow-sm text-white bg-primary-600 hover:bg-primary-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-primary-500 #{}"
              }
            >
              <.icon name={:share} class="h-5 w-5" />
            </button>
            <button
              type="button"
              title="Game Settings"
              phx-click={show_modal("settings")}
              class={
                "inline-flex items-center p-1.5 border border-transparent rounded-full shadow-sm text-white bg-primary-600 hover:bg-primary-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-primary-500 #{}"
              }
            >
              <.icon name={:cog} class="h-5 w-5" />
            </button>
            <button
              type="button"
              title="Information"
              phx-click={show_modal("info")}
              class={
                "inline-flex items-center p-1.5 border border-transparent rounded-full shadow-sm text-white bg-primary-600 hover:bg-primary-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-primary-500 #{}"
              }
            >
              <.icon name={:information_circle} class="h-5 w-5" />
            </button>
          </div>
        </div>
      </div>
    </nav>
    """
  end

  defp render_nav_right(assigns) do
    ~H"""
    <.icon name={if @count > 1, do: :users, else: :user} outlined />
    <span class="ml-2 text-zinc-800 dark:text-zinc-200"><%= page_title(@count) %></span>
    """
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
    <div class="flex-1 flex flex-col overflow-hidden">
      <!-- Main content -->
      <div class="flex-1 flex items-stretch overflow-hidden">
        <main class="flex-1 overflow-y-auto p-4">
          <!-- Primary column -->
          <section
            aria-labelledby="primary-heading"
            class="min-w-0 flex-1 h-full flex flex-col lg:order-last"
          >
            <svg
              id="game"
              viewBox="0 0 1000 1000"
              width="1000"
              height="1000"
              class="bg-white dark:bg-zinc-900 shadow mx-auto w-full h-auto max-w-[calc(100vh-theme(space.40))] max-h-[calc(100vh-theme(space.40))] touch-pinch-zoom"
              phx-hook="Draw"
            >
              <!-- https://stackoverflow.com/questions/22013281/drawing-a-grid-using-svg-markup -->
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
              <%= for {x, y} <- @grid do %>
                <rect
                  x={x * 10}
                  y={y * 10}
                  width="10"
                  height="10"
                  fill="currentColor"
                  class="text-primary-600 dark:text-primary-500"
                />
              <% end %>
              <%= for {x, y} <- @working_grid do %>
                <rect
                  x={x * 10}
                  y={y * 10}
                  width="10"
                  height="10"
                  fill="currentColor"
                  class="text-green-600 dark:text-green-500"
                />
              <% end %>
            </svg>
          </section>
        </main>
        <div class="hidden">
          <!-- Secondary column (hidden on smaller screens) -->
          <aside
            id="player-bar"
            class="hidden w-80 bg-white dark:bg-zinc-900 border-l border-zinc-200 dark:border-zinc-700 overflow-y-auto xl:block dark:text-zinc-100"
          >
            Cool
          </aside>
          <.slideover id="players" class="xl:hidden">
            Cool
          </.slideover>
        </div>
      </div>
      <.modal id="settings" no_border>
        <.card>
          <:title>Settings</:title>
          <h3 class="text-md mb-2">Load or Dump the Game Grid</h3>
          <form phx-submit="load" class="my-4">
            <.textarea name="json" rows="5"><%= @show_grid %></.textarea>
            <div class="mt-4">
              <.button type="submit" phx-click={hide_modal("settings")}>Load grid</.button>
              <.button
                id="dump-btn"
                type="button"
                class="transition ease-out-300"
                phx-click={JS.push("dump", value: %{"copy-el" => "#dump-btn"})}
                data-copy-success={success_btn("#dump-btn")}
                data-copy-error={error_btn("#dump-btn")}
              >
                Dump grid
              </.button>
            </div>
          </form>
          <hr class="my-4" />
          <h3 class="text-md mb-2">Tick Speed</h3>
          <form phx-change="save_tick">
            <!--<input type="text" inputmode="numeric" pattern="[0-9]*" name="tick" value={@tick}>-->
            <input type="range" min="10" max="1000" value={@tick} name="tick" />
            <span><%= @tick %></span>
          </form>
        </.card>
      </.modal>
      <.modal id="share" no_border>
        <.card>
          <:title>Share this board</:title>
          <p class="mb-4">
            Use the following button to create a permanent link to the current board state:
          </p>

          <.button
            id="share-url-btn"
            class="transition ease-out-300"
            phx-click={JS.push("share_link", value: %{"copy-el" => "#share-url-btn"})}
            data-copy-success={success_btn("#share-url-btn")}
            data-copy-error={error_btn("#share-url-btn")}
          >
            Generate Link
          </.button>

          <p class="my-4">
            If your browser supports it, the link is automatically copied to your clipboard.
          </p>

          <%= if @share_url do %>
            <.textarea><%= @share_url %></.textarea>
          <% end %>

          <hr />

          <p class="my-4">
            If you want others to join the current game session, just send them the current URL.
          </p>

          <div class="flex">
            <.textarea id="current-url" rows="1"><%= Routes.game_url(@socket, :game, @name) %></.textarea>
            <.button
              id="copy-current-url-btn"
              class="ml-2 transition ease-out-300"
              phx-click={
                JS.dispatch("phx:copy", to: "#current-url", detail: %{"el" => "#copy-current-url-btn"})
              }
              data-copy-success={success_btn("#copy-current-url-btn")}
              data-copy-error={error_btn("#copy-current-url-btn")}
            >
              Copy
            </.button>
          </div>
        </.card>
      </.modal>
      <.modal id="info" no_border>
        <.card>
          <:title>Information</:title>
          <p class="mb-4">
            This game implements
            <a class="underline" href="https://en.wikipedia.org/wiki/Conway's_Game_of_Life">Conway's Game of Life</a>
            using <a class="underline" href="https://www.phoenixframework.org/">Phoenix LiveView</a>.
          </p>

          <p class="mb-4">The game is played on a grid of cells. In each game step:</p>

          <ol class="list-decimal list-inside">
            <li>Any live cell with fewer than two live neighbours dies, as if by underpopulation.</li>
            <li>Any live cell with two or three live neighbours lives on to the next generation.</li>
            <li>Any live cell with more than three live neighbours dies, as if by overpopulation.</li>
            <li>
              Any dead cell with exactly three live neighbours becomes a live cell, as if by reproduction.
            </li>
          </ol>
        </.card>
      </.modal>
    </div>
    """
  end
end
