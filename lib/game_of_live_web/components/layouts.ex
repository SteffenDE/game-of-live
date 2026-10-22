defmodule GameOfLiveWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use GameOfLiveWeb, :html

  # Embed all files in layouts/* within this module.
  # The root.html.heex file contains the HTML skeleton of the application.
  embed_templates "layouts/*"

  @doc """
  Renders the app layout: navbar, flash messages, content and an optional bottom bar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  slot :inner_block, required: true
  slot :navbar_right, doc: "content shown at the right side of the navbar"
  slot :bottom_bar, doc: "content shown in a bar fixed to the bottom"

  def app(assigns) do
    ~H"""
    <nav class="bg-white dark:bg-zinc-900 shadow-sm dark:text-zinc-200 sticky top-0">
      <div class="mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex justify-between h-16">
          <div class="flex w-full relative">
            <div class="absolute left-0 h-full">
              <div class="h-full flex items-center">
                <img class="block h-8 w-auto" src={~p"/images/favicon-120x120.png"} alt="Game of Live" />
                <span class="ml-4 text-2xl">
                  Game of Live<span class="text-zinc-400">View</span>
                </span>
              </div>
            </div>
            <div class="absolute right-0 h-full">
              <div class="h-full flex items-center">
                {render_slot(@navbar_right)}
              </div>
            </div>
          </div>
        </div>
      </div>
    </nav>

    <main>
      <.flash_group flash={@flash} />
      {render_slot(@inner_block)}
    </main>

    <nav
      :if={@bottom_bar != []}
      class="bg-white dark:bg-zinc-900 border-t-2 border-zinc-200 dark:border-zinc-700 dark:text-zinc-200 absolute bottom-0 w-full"
    >
      <div class="mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex justify-between h-16">
          <div class="flex m-auto space-x-2">
            {render_slot(@bottom_bar)}
          </div>
        </div>
      </div>
    </nav>
    """
  end

  attr :flash, :map, required: true, doc: "the map of flash messages"

  def flash_group(assigns) do
    ~H"""
    <div :if={map_size(@flash) > 0} id="flash-group" class="p-2" aria-live="polite">
      <.flash kind={:error} flash={@flash} />
      <.flash kind={:info} flash={@flash} />
    </div>
    """
  end
end
