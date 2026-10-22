defmodule GameOfLiveWeb.GameLiveTest do
  use GameOfLiveWeb.ConnCase

  import Phoenix.LiveViewTest

  test "redirects to a new game", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")
    assert_patch(view)
  end

  test "renders the board and toggles cells", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/game/test-board")
    assert html =~ "1 player"

    render_hook(view, "click", %{"offset_x" => 25, "offset_y" => 35})
    assert has_element?(view, "svg#game rect[x='20'][y='30']")
  end

  test "share link creates a board", %{conn: conn} do
    conn = get(conn, ~p"/s?#{%{"board" => "[[1,2]]"}}")
    assert "/game/" <> _ = redirected_to(conn)
  end
end
