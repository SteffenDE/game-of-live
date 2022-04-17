defmodule GameOfLiveWeb.ShareController do
  use GameOfLiveWeb, :controller

  def index(conn, %{"board" => board_json}) do
    name = Nanoid.generate()
    {:ok, server} = GameOfLive.GameServer.start_server(%{name: name})

    case Jason.decode(board_json) do
      {:ok, points} when is_list(points) ->
        GameOfLive.GameServer.set_grid(
          server,
          MapSet.new(Enum.map(points, fn [x, y] -> {x, y} end))
        )

        conn
        |> redirect(to: Routes.game_path(conn, :game, name))

      {:error, _} ->
        IO.puts("error!!!")

        conn
        |> put_flash(:error, "Invalid board")
        |> redirect(to: Routes.game_path(conn, :game, name))
    end
  end
end
