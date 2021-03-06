defmodule GameOfLiveWeb.GameLive do
  use GameOfLiveWeb, :live_view

  @default_tick 100

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       tick: @default_tick,
       grid: MapSet.new(),
       working_grid: MapSet.new(),
       size: {100, 100},
       run: false,
       show_grid: "",
       count: 0,
       page_title: "New Game",
       mode: :draw
     )}
  end

  @impl true
  def handle_params(%{"name" => name}, _uri, socket) do
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

  def handle_event("dump", _, socket = %{assigns: %{grid: grid}}) do
    {:noreply,
     assign(socket, :show_grid, Enum.map(grid, fn {x, y} -> [x, y] end) |> Jason.encode!())}
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

  @impl true
  def handle_info({:run, run}, socket), do: {:noreply, assign(socket, :run, run)}
  def handle_info({:grid, grid}, socket), do: {:noreply, assign(socket, :grid, grid)}
  def handle_info({:tick, tick}, socket), do: {:noreply, assign(socket, :tick, tick)}

  def handle_info({:count, count}, socket),
    do: {:noreply, assign(socket, count: count, page_title: page_title(count))}

  defp page_title(1), do: "1 player"
  defp page_title(n), do: "#{n} players"

  @impl true
  def render(assigns) do
    ~H"""
    <h1>Game of Live(View) - <%= @page_title %></h1>

    <div>
      <button type="button" phx-click="toggle"><%= if @run, do: "Stop", else: "Start" %></button>
      <button type="button" phx-click="clear">Clear grid</button>
      <button type="button" phx-click="apply_work" disabled={MapSet.size(@working_grid) == 0}>
        Apply changes
      </button>
      <button type="button" phx-click="toggle_mode">
        Mode: <%= if @mode == :draw, do: "Draw", else: "Erase" %>
      </button>

      <form phx-change="save_tick">
        <!--<input type="text" inputmode="numeric" pattern="[0-9]*" name="tick" value={@tick}>-->
        <input type="range" min="10" max="1000" value={@tick} name="tick" />
        <span><%= @tick %></span>
      </form>
    </div>

    <svg
      id="game"
      viewBox="0 0 1000 1000"
      width="1000"
      height="1000"
      style="width: 100%; height: 100%; touch-action: pinch-zoom;"
      phx-hook="Draw"
    >
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
        <rect x={x * 10} y={y * 10} width="10" height="10" style="fill:rgb(0,0,255)" />
      <% end %>
      <%= for {x, y} <- @working_grid do %>
        <rect x={x * 10} y={y * 10} width="10" height="10" style="fill:rgb(0,255,0)" />
      <% end %>
    </svg>

    <hr />

    <form phx-submit="load">
      <textarea name="json"><%= @show_grid %></textarea>
      <button type="submit">Load grid</button>
      <button type="button" phx-click="dump">Dump grid</button>
    </form>
    """
  end
end
