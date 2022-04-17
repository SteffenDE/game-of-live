defmodule GameOfLiveWeb.LiveHelpers do
  use Phoenix.Component

  alias Phoenix.LiveView.JS
  alias GameOfLiveWeb.Router.Helpers, as: Routes

  # see https://github.com/fly-apps/live_beats/blob/819d5ecc9850ff8f49013f3151213a4419ab44a2/lib/live_beats_web/live/live_helpers.ex#L109
  def icon(assigns) do
    assigns =
      assigns
      |> assign_new(:outlined, fn -> false end)
      |> assign_new(:class, fn -> "w-4 h-4 inline-block" end)
      |> assign_new(:"aria-hidden", fn -> !Map.has_key?(assigns, :"aria-label") end)

    ~H"""
    <%= if @outlined do %>
      <%= apply(Heroicons.Outline, @name, [assigns_to_attributes(assigns, [:outlined, :name])]) %>
    <% else %>
      <%= apply(Heroicons.Solid, @name, [assigns_to_attributes(assigns, [:outlined, :name])]) %>
    <% end %>
    """
  end

  def flash(assigns = %{kind: :info}) do
    ~H"""
    <%= if live_flash(@flash, @kind) do %>
      <div class="rounded-md bg-blue-50 p-4" phx-click={JS.push("lv:clear-flash")}>
        <div class="flex">
          <div class="flex-shrink-0">
            <.icon name={:information_circle} class="h-5 w-5 text-blue-400" />
          </div>
          <div class="ml-3">
            <p class="text-sm text-blue-700"><%= live_flash(@flash, :info) %></p>
          </div>
          <div class="ml-auto pl-3">
            <div class="-mx-1.5 -my-1.5">
              <button
                type="button"
                class="inline-flex bg-blue-50 rounded-md p-1.5 text-blue-500 hover:bg-blue-100 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-offset-blue-50 focus:ring-blue-600"
              >
                <span class="sr-only">Dismiss</span>
                <.icon name={:x} class="h-5 w-5" />
              </button>
            </div>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  def flash(assigns = %{kind: :error}) do
    ~H"""
    <%= if live_flash(@flash, @kind) do %>
      <div class="rounded-md bg-red-50 p-4" phx-click={JS.push("lv:clear-flash")}>
        <div class="flex">
          <div class="flex-shrink-0">
            <.icon name={:information_circle} class="h-5 w-5 text-red-400" />
          </div>
          <div class="ml-3">
            <p class="text-sm text-red-700"><%= live_flash(@flash, :error) %></p>
          </div>
          <div class="ml-auto pl-3">
            <div class="-mx-1.5 -my-1.5">
              <button
                type="button"
                class="inline-flex bg-red-50 rounded-md p-1.5 text-red-500 hover:bg-red-100 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-offset-red-50 focus:ring-red-600"
              >
                <span class="sr-only">Dismiss</span>
                <.icon name={:x} class="h-5 w-5" />
              </button>
            </div>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  def button(assigns) do
    assigns =
      assigns
      |> assign_new(:type, fn -> "button" end)
      |> assign_new(:class, fn -> "" end)
      |> assign(:extra_assigns, assigns_to_attributes(assigns, [:type, :class]))

    ~H"""
    <button
      type={@type}
      class={
        "inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-primary-600 hover:bg-primary-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-primary-500 dark:ring-offset-zinc-700 #{@class}"
      }
      {@extra_assigns}
    >
      <%= render_slot(@inner_block) %>
    </button>
    """
  end

  def textarea(assigns) do
    assigns =
      assigns
      |> assign_new(:class, fn -> "" end)
      |> assign(:extra_assigns, assigns_to_attributes(assigns, [:class]))

    ~H"""
    <textarea
      class={
        "max-w-lg shadow-sm block w-full focus:ring-primary-500 focus:border-primary-500 sm:text-sm border border-zinc-300 dark:border-zinc-700 bg-zinc-50 dark:bg-zinc-900 rounded-md text-zinc-800 dark:text-zinc-200 #{@class}"
      }
      {@extra_assigns}
    ><%= render_slot(@inner_block) %></textarea>
    """
  end

  def toggle_mobile_navbar(js \\ %JS{}) do
    js
    |> JS.toggle(to: "#mobile-menu")
    |> JS.toggle(to: "#mobile-menu-button svg")
    |> JS.dispatch("gol:toggle-aria", to: "#mobile-menu")
  end

  def navbar(assigns) do
    ~H"""
    <nav class="bg-white dark:bg-zinc-900 shadow dark:text-zinc-200 sticky top-0">
      <div class="mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex justify-between h-16">
          <div class="flex w-full relative">
            <div class="absolute left-0 h-full">
              <div class="h-full flex items-center">
                <img
                  class="block h-8 w-auto"
                  src={Routes.static_path(GameOfLiveWeb.Endpoint, "/images/favicon-120x120.png")}
                  alt="Game of Live"
                />
                <span class="ml-4 text-2xl">
                  Game of Live<span class="text-zinc-400">View</span>
                </span>
              </div>
            </div>
            <div class="hidden w-full sm:flex sm:mx-auto sm:space-x-8">
              <!-- main content -->
              <div class="m-auto">
                <%= if assigns[:navbar_main] && is_function(assigns[:navbar_main]) do %>
                  <%= assigns[:navbar_main].(assigns) %>
                <% end %>
              </div>
            </div>
            <div class="absolute right-0 h-full">
              <div class="h-full flex items-center">
                <%= if assigns[:navbar_right] && is_function(assigns[:navbar_right]) do %>
                  <%= assigns[:navbar_right].(assigns) %>
                <% end %>
              </div>
            </div>
          </div>
          <!-- sm:hidden -->
          <div class="-mr-2 flex items-center hidden">
            <!-- Mobile menu button -->
            <button
              id="mobile-menu-button"
              type="button"
              phx-click={toggle_mobile_navbar()}
              class="inline-flex items-center justify-center p-2 rounded-md text-gray-400 hover:text-gray-500 hover:bg-gray-100 focus:outline-none focus:ring-2 focus:ring-inset focus:ring-primary-500"
              aria-controls="mobile-menu"
              aria-expanded="false"
            >
              <span class="sr-only">Open main menu</span>
              <.icon name={:menu} outlined class="block h-6 w-6" />
              <.icon name={:x} outlined class="hidden h-6 w-6" />
            </button>
          </div>
        </div>
      </div>
      <!-- Mobile menu, show/hide based on menu state. -->
      <div id="mobile-menu" class="hidden" id="mobile-menu">
        <div class="pt-2 pb-3 space-y-1">
          <!-- Current: "bg-primary-50 border-primary-500 text-primary-700", Default: "border-transparent text-gray-500 hover:bg-gray-50 hover:border-gray-300 hover:text-gray-700" -->
          <!-- main content -->
        </div>
      </div>
    </nav>
    """
  end

  def show_slideover(js \\ %JS{}, id) do
    js
    |> JS.show(to: "#slideover-#{id}")
    |> JS.show(
      to: "#slideover-#{id}-overlay",
      transition: {"ease-in-out duration-300", "opacity-0", "opacity-100"},
      time: 300
    )
    |> JS.show(
      to: "#slideover-#{id}-panel",
      transition:
        {"transform transition ease-in-out duration-300 sm:duration-500", "translate-x-full",
         "translate-x-0"},
      time: 500
    )
    |> JS.show(
      to: "#slideover-#{id}-close",
      display: "flex",
      transition: {"ease-in-out duration-300", "opacity-0", "opacity-100"},
      time: 300
    )
  end

  def hide_slideover(js \\ %JS{}, id) do
    js
    |> JS.hide(
      to: "#slideover-#{id}-overlay",
      transition: {"ease-in-out duration-300", "opacity-100", "opacity-0"},
      time: 300
    )
    |> JS.hide(
      to: "#slideover-#{id}-panel",
      transition:
        {"transform transition ease-in-out duration-300 sm:duration-500", "translate-x-0",
         "translate-x-full"},
      time: 500
    )
    |> JS.hide(
      to: "#slideover-#{id}-close",
      transition: {"ease-in-out duration-300", "opacity-100", "opacity-0"},
      time: 300
    )

    # |> JS.hide(to: "#slideover-#{id}")
  end

  ### Modal

  def show_modal(js \\ %JS{}, id) do
    js
    |> JS.add_class("overflow-hidden", to: "body")
    |> JS.show(
      to: "##{id}-overlay",
      transition: {"ease-out duration-300", "opacity-0", "opacity-100"},
      time: 300
    )
    |> JS.show(
      to: "##{id}-content",
      transition:
        {"ease-out duration-300", "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"},
      time: 300,
      display: "inline-block"
    )
    |> JS.show(to: "##{id}")
  end

  def hide_modal(js \\ %JS{}, id) do
    js
    |> JS.remove_class("overflow-hidden", to: "body")
    |> JS.hide(
      to: "##{id}-overlay",
      transition: {"ease-in duration-200", "opacity-100", "opacity-0"},
      time: 200
    )
    |> JS.hide(
      to: "##{id}-content",
      transition:
        {"ease-in duration-200", "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"},
      time: 200
    )
    |> JS.dispatch("js:exec-timeout",
      to: "##{id}",
      detail: %{timeout: 200, js: "data-close"}
    )
  end

  def modal(assigns) do
    assigns =
      assigns
      |> assign_new(:no_border, fn -> false end)
      |> assign_new(:on_close, fn -> %JS{} end)
      |> assign_new(:extra_assigns, fn ->
        assigns_to_attributes(assigns, [:id, :on_close, :"phx-target"])
      end)

    ~H"""
    <div
      class="fixed z-10 inset-0 overflow-y-auto hidden"
      aria-labelledby="modal-title"
      role="dialog"
      aria-modal="true"
      id={@id}
      phx-remove={hide_modal(@on_close, @id)}
      data-close={JS.hide(to: "##{@id}")}
      phx-target={assigns[:"phx-target"]}
      {@extra_assigns}
    >
      <div class="flex items-end justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:block sm:p-0">
        <div
          class="fixed inset-0 bg-zinc-500 bg-opacity-75 dark:bg-opacity-25 transition-opacity"
          aria-hidden="true"
          id={"#{@id}-overlay"}
        >
        </div>
        <!-- This element is to trick the browser into centering the modal contents. -->
        <span class="hidden sm:inline-block sm:align-middle sm:h-screen" aria-hidden="true">
          &#8203;
        </span>
        <div
          id={"#{@id}-content"}
          class={
            "hidden relative align-bottom bg-zinc-100 dark:bg-zinc-800 rounded-lg #{unless @no_border, do: "px-4 pt-5 pb-4 sm:p-6"} text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-lg w-full"
          }
          phx-click-away={hide_modal(@on_close, @id)}
          phx-window-keydown={hide_modal(@on_close, @id)}
          phx-target={assigns[:"phx-target"]}
          phx-key="escape"
        >
          <%= render_block(@inner_block) %>
        </div>
      </div>
    </div>
    """
  end

  ### Slideover

  def slideover(assigns) do
    assigns =
      assigns
      |> assign_new(:on_close, fn -> %JS{} end)
      |> assign_new(:extra_assigns, fn ->
        assigns_to_attributes(assigns, [:id, :on_close])
      end)

    ~H"""
    <div
      id={"slideover-#{@id}"}
      class="hidden fixed inset-0 overflow-hidden"
      aria-labelledby={"slide-over-#{@id}"}
      role="dialog"
      aria-modal="true"
      {@extra_assigns}
    >
      <div class="absolute inset-0 overflow-hidden">
        <!--
          Background overlay, show/hide based on slide-over state.

          Entering: "ease-in-out duration-500"
            From: "opacity-0"
            To: "opacity-100"
          Leaving: "ease-in-out duration-500"
            From: "opacity-100"
            To: "opacity-0"
        -->
        <div
          id={"slideover-#{@id}-overlay"}
          class="hidden absolute inset-0 bg-zinc-500 dark:bg-zinc-50 bg-opacity-75 dark:bg-opacity-10 transition-opacity"
          aria-hidden="true"
        >
        </div>
        <div class="pointer-events-none fixed inset-y-0 right-0 flex max-w-full pl-10">
          <!--
            Slide-over panel, show/hide based on slide-over state.

            Entering: "transform transition ease-in-out duration-500 sm:duration-700"
              From: "translate-x-full"
              To: "translate-x-0"
            Leaving: "transform transition ease-in-out duration-500 sm:duration-700"
              From: "translate-x-0"
              To: "translate-x-full"
          -->
          <div
            id={"slideover-#{@id}-panel"}
            class="hidden pointer-events-auto relative w-screen max-w-md"
          >
            <!--
              Close button, show/hide based on slide-over state.

              Entering: "ease-in-out duration-500"
                From: "opacity-0"
                To: "opacity-100"
              Leaving: "ease-in-out duration-500"
                From: "opacity-100"
                To: "opacity-0"
            -->
            <div
              id={"slideover-#{@id}-close"}
              class="hidden absolute top-0 left-0 -ml-8 pt-4 pr-2 sm:-ml-10 sm:pr-4"
            >
              <button
                type="button"
                class="rounded-md text-zinc-300 hover:text-white focus:outline-none focus:ring-2 focus:ring-white"
                phx-click={hide_slideover(@on_close, @id)}
              >
                <span class="sr-only">Close panel</span>
                <.icon name={:x} outlined class="h-6 w-6" />
              </button>
            </div>

            <div class="flex h-full flex-col overflow-y-scroll bg-zinc-50 dark:bg-zinc-800 py-6 shadow-xl">
              <%= if assigns[:title] do %>
                <div class="px-4 sm:px-6">
                  <h2
                    class="text-lg font-medium text-zinc-900 dark:text-zinc-50"
                    id="slide-over-title"
                  >
                    <%= @title %>
                  </h2>
                </div>
                <div class="relative mt-6 flex-1 px-4 sm:px-6">
                  <%= render_slot(@inner_block, %{close_js: hide_slideover(@on_close, @id)}) %>
                </div>
              <% else %>
                <%= render_slot(@inner_block, %{close_js: hide_slideover(@on_close, @id)}) %>
              <% end %>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  ### Card

  def card(assigns) do
    assigns =
      assigns
      |> assign_new(:class, fn -> "" end)
      |> assign_new(:extra_assigns, fn ->
        assigns_to_attributes(assigns, [:title, :inner_block, :class])
      end)

    ~H"""
    <div
      class={"bg-white dark:bg-zinc-800 overflow-hidden shadow rounded-lg #{@class}"}
      {@extra_assigns}
    >
      <div class="px-4 py-5 sm:p-6">
        <%= if assigns[:title] do %>
          <div class="mb-3 text-lg leading-6 font-medium text-zinc-900 dark:text-zinc-100">
            <%= render_slot(@title) %>
          </div>
        <% end %>
        <%= render_slot(@inner_block) %>
      </div>
    </div>
    """
  end
end
