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
       show_grid: ""
     )}
  end

  @impl true
  def handle_event("toggle", _, socket = %{assigns: %{run: run, tick: tick}}) do
    unless run do
      Process.send_after(self(), :update, tick)
    end

    {:noreply, assign(socket, :run, not run)}
  end

  @impl true
  def handle_event(
        "click",
        _params = %{"offset_x" => x, "offset_y" => y},
        socket = %{assigns: %{grid: grid}}
      ) do
    coords = {div(x, 10), div(y, 10)}

    grid =
      if MapSet.member?(grid, coords),
        do: MapSet.delete(grid, coords),
        else: MapSet.put(grid, coords)

    {:noreply, assign(socket, :grid, grid)}
  end

  @impl true
  def handle_event("save_tick", %{"tick" => tick}, socket) do
    {:noreply, assign(socket, :tick, String.to_integer(tick))}
  end

  @impl true
  def handle_event("dump", _, socket = %{assigns: %{grid: grid}}) do
    {:noreply,
     assign(socket, :show_grid, Enum.map(grid, fn {x, y} -> [x, y] end) |> Jason.encode!())}
  end

  @impl true
  def handle_event("load", %{"json" => grid_json}, socket) do
    case Jason.decode(grid_json) do
      {:ok, points} when is_list(points) ->
        {:noreply, assign(socket, :grid, MapSet.new(Enum.map(points, fn [x, y] -> {x, y} end)))}

      _ ->
        {:noreply, socket}
    end
  end

  defp get_ranges(grid) do
    Enum.map(grid, fn {x, y} ->
      for i <- (x - 1)..(x + 1),
          j <- (y - 1)..(y + 1),
          i > 0 and i <= 100,
          j > 0 and j < 100,
          do: {i, j}
    end)
    |> List.flatten()
  end

  defp count_neighbors(grid, x, y) do
    for i <- (x - 1)..(x + 1), j <- (y - 1)..(y + 1), reduce: 0 do
      acc ->
        if i == x and j == y do
          acc
        else
          acc +
            if MapSet.member?(grid, {i, j}) do
              1
            else
              0
            end
        end
    end
  end

  @impl true
  def handle_info(:update, socket = %{assigns: %{run: false}}), do: {:noreply, socket}

  @impl true
  def handle_info(:update, socket = %{assigns: %{grid: grid, tick: tick}}) do
    grid =
      for {x, y} <- get_ranges(grid), reduce: grid do
        acc ->
          neighbors = count_neighbors(grid, x, y)

          cond do
            # starvation
            neighbors < 2 -> MapSet.delete(acc, {x, y})
            # overpopulation
            neighbors > 3 -> MapSet.delete(acc, {x, y})
            # magic birth
            neighbors == 3 -> MapSet.put(acc, {x, y})
            # default
            true -> acc
          end
      end

    Process.send_after(self(), :update, tick)

    {:noreply, assign(socket, :grid, grid)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <h1>Game of Live(View)</h1>

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
