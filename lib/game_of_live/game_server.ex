defmodule GameOfLive.GameServer do
  use GenServer, restart: :transient

  @impl true
  def init(params) do
    {:ok,
     Map.merge(
       %{
         grid: MapSet.new(),
         tick: 100,
         run: false,
         monitor: [],
         count: 0
       },
       params
     )}
  end

  @impl true
  def handle_call({:monitor, pid}, _from, state) do
    %{name: name, monitor: monitor_pids, count: count} = state
    ref = Process.monitor(pid)

    Phoenix.PubSub.broadcast!(GameOfLive.PubSub, "game:#{name}", {:count, count + 1})

    {:reply, :ok, %{state | monitor: [{pid, ref} | monitor_pids], count: count + 1}}
  end

  def handle_call({:demonitor, pid}, _from, state) do
    %{name: name, monitor: monitor_pids, count: count} = state
    monitor_pids = Enum.filter(monitor_pids, fn {monitored_pid, _} -> monitored_pid != pid end)

    Phoenix.PubSub.broadcast!(GameOfLive.PubSub, "game:#{name}", {:count, count - 1})

    {:reply, :ok, %{state | count: count - 1, monitor: monitor_pids}}
  end

  def handle_call(:get_state, _from, state) do
    %{grid: grid, run: tun, tick: tick, count: count} = state

    {:reply,
     {:ok,
      %{
        grid: grid,
        run: tun,
        tick: tick,
        count: count
      }}, state}
  end

  @impl true
  def handle_cast({:set_tick, tick}, state = %{name: name}) do
    Phoenix.PubSub.broadcast!(GameOfLive.PubSub, "game:#{name}", {:tick, tick})

    {:noreply, %{state | tick: tick}}
  end

  def handle_cast(:toggle, state = %{name: name, run: run, tick: tick}) do
    Phoenix.PubSub.broadcast!(GameOfLive.PubSub, "game:#{name}", {:run, not run})

    unless run do
      Process.send_after(self(), :update, tick)
    end

    {:noreply, %{state | run: not run}}
  end

  def handle_cast({:set_grid, grid}, state = %{name: name}) do
    Phoenix.PubSub.broadcast!(GameOfLive.PubSub, "game:#{name}", {:grid, grid})

    {:noreply, %{state | grid: grid}}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, _reason}, state) do
    %{name: name, monitor: monitor_pids, count: count} = state
    monitor_pids = Enum.filter(monitor_pids, fn {_pid, monitor_ref} -> ref != monitor_ref end)

    Phoenix.PubSub.broadcast!(GameOfLive.PubSub, "game:#{name}", {:count, count - 1})

    if monitor_pids == [] do
      Process.send_after(self(), :check_idle, 5_000)
    end

    {:noreply, %{state | monitor: monitor_pids, count: count - 1}}
  end

  def handle_info(:check_idle, state = %{count: 0}), do: {:stop, :normal, state}
  def handle_info(:check_idle, state), do: {:noreply, state}

  ## game tick

  def handle_info(:update, state = %{run: false}), do: {:noreply, state}

  def handle_info(:update, state = %{name: name, grid: grid, tick: tick}) do
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
    Phoenix.PubSub.broadcast!(GameOfLive.PubSub, "game:#{name}", {:grid, grid})

    {:noreply, %{state | grid: grid}}
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

  ## Public API

  def start_link(params = %{name: name}) do
    GenServer.start_link(__MODULE__, params,
      name: {:via, Registry, {GameOfLive.GameRegistry, name}}
    )
  end

  def start_server(params) do
    DynamicSupervisor.start_child(GameOfLive.GameSupervisor, {GameOfLive.GameServer, params})
  end

  def subscribe(server) do
    GenServer.call(server, {:monitor, self()})
  end

  def unsubscribe(server) do
    GenServer.call(server, {:demonitor, self()})
  end

  def get_state(server) do
    GenServer.call(server, :get_state)
  end

  def set_tick(server, tick) do
    GenServer.cast(server, {:set_tick, tick})
  end

  def toggle(server) do
    GenServer.cast(server, :toggle)
  end

  def set_grid(server, grid) do
    GenServer.cast(server, {:set_grid, grid})
  end
end
