defmodule GameOfLiveWeb.GameLive do
  use GameOfLiveWeb, :live_view

  @default_tick 100

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       tick: @default_tick,
       grid: MapSet.new(),
       size: {100, 100},
       run: false,
       show_grid: "",
       count: 0
     )}
  end

  @impl true
  def handle_params(%{"name" => name}, _uri, socket) do
    case Registry.lookup(GameOfLive.GameRegistry, name) do
      [] ->
        {
          :noreply,
          socket
          |> put_flash(:error, "Game not found")
          |> push_patch(to: Routes.game_path(socket, :index))
        }

      [{server, _pid}] ->
        Phoenix.PubSub.subscribe(GameOfLive.PubSub, "game:#{name}")
        GameOfLive.GameServer.subscribe(server)
        {:ok, assigns} = GameOfLive.GameServer.get_state(server)
        {:noreply, socket |> assign(server: server, name: name) |> assign(assigns)}
    end
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

  def handle_event(
        "click",
        _params = %{"offset_x" => x, "offset_y" => y},
        socket = %{assigns: %{server: server, grid: grid}}
      ) do
    coords = {div(x, 10), div(y, 10)}

    grid =
      if MapSet.member?(grid, coords),
        do: MapSet.delete(grid, coords),
        else: MapSet.put(grid, coords)

    GameOfLive.GameServer.set_grid(server, grid)

    {:noreply, socket}
  end

  def handle_event("save_tick", %{"tick" => tick}, socket = %{assigns: %{server: server}}) do
    GameOfLive.GameServer.set_tick(server, String.to_integer(tick))

    {:noreply, socket}
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

        {:noreply, socket}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:run, run}, socket), do: {:noreply, assign(socket, :run, run)}
  def handle_info({:grid, grid}, socket), do: {:noreply, assign(socket, :grid, grid)}
  def handle_info({:tick, tick}, socket), do: {:noreply, assign(socket, :tick, tick)}
  def handle_info({:count, count}, socket), do: {:noreply, assign(socket, :count, count)}

  @impl true
  def render(assigns) do
    ~H"""
    <h1>Game of Live(View) - <%= @count %> players</h1>

    <div>
      <button type="button" phx-click="toggle"><%= if @run, do: "Stop", else: "Start" %></button>
      <button type="button" phx-click="dump">Dump grid</button>

      <form phx-change="save_tick">
        <!--<input type="text" inputmode="numeric" pattern="[0-9]*" name="tick" value={@tick}>-->

        <input type="range" min="1" max="500" value={@tick} name="tick"><span><%= @tick %></span>
      </form>
    </div>

    <svg viewBox="0 0 1000 1000" width="1000" height="1000" phx-click="click">
    <defs>
      <pattern id="tenthGrid" width="10" height="10" patternUnits="userSpaceOnUse">
        <path d="M 10 0 L 0 0 0 10" fill="none" stroke="silver" stroke-width="0.5"/>
      </pattern>
      <pattern id="grid" width="100" height="100" patternUnits="userSpaceOnUse">
        <rect width="100" height="100" fill="url(#tenthGrid)"/>
        <path d="M 100 0 L 0 0 0 100" fill="none" stroke="gray" stroke-width="1"/>
      </pattern>
    </defs>
    <rect width="100%" height="100%" fill="url(#grid)"/>
    <%= for {x, y} <- @grid do %>
      <rect x={x * 10} y={y * 10} width="10" height="10" style="fill:rgb(0,0,255)" />
    <% end %>
    </svg>

    <form phx-submit="load">
      <textarea name="json"><%= @show_grid %></textarea>
      <button type="submit">Load grid</button>
    </form>
    """
  end
end
