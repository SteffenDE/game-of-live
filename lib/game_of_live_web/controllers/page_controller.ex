defmodule GameOfLiveWeb.PageController do
  use GameOfLiveWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
