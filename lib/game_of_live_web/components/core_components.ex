defmodule GameOfLiveWeb.CoreComponents do
  @moduledoc """
  Provides core UI components.

  Icons are extracted from the `deps/heroicons` directory and bundled within
  your compiled app.css by the plugin in `assets/vendor/heroicons.js`.
  """
  use Phoenix.Component

  alias Phoenix.LiveView.JS

  @doc """
  Renders a [Heroicon](https://heroicons.com).

  ## Examples

      <.icon name="hero-x-mark" />
      <.icon name="hero-users" class="size-6" />
  """
  attr :name, :string, required: true
  attr :class, :any, default: "size-4"

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class, "inline-block"]} aria-hidden="true" />
    """
  end

  @doc """
  Renders flash notices.

  ## Examples

      <.flash kind={:info} flash={@flash} />
  """
  attr :id, :string, doc: "the optional id of flash container"
  attr :flash, :map, default: %{}, doc: "the map of flash messages to display"
  attr :kind, :atom, values: [:info, :error], doc: "used for styling and flash lookup"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

  slot :inner_block, doc: "the optional inner block that renders the flash message"

  def flash(assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      role="alert"
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind})}
      class={[
        "rounded-md p-4 cursor-pointer",
        @kind == :info && "bg-blue-50 text-blue-700",
        @kind == :error && "bg-red-50 text-red-700"
      ]}
      {@rest}
    >
      <div class="flex items-center gap-3">
        <.icon
          name={if @kind == :info, do: "hero-information-circle-mini", else: "hero-exclamation-circle-mini"}
          class={["size-5 shrink-0", @kind == :info && "text-blue-400", @kind == :error && "text-red-400"]}
        />
        <p class="text-sm">{msg}</p>
        <button type="button" class="ml-auto p-1 rounded-md" aria-label="Dismiss">
          <.icon name="hero-x-mark-mini" class="size-5" />
        </button>
      </div>
    </div>
    """
  end

  @doc """
  Renders a button.

  ## Examples

      <.button>Send!</.button>
      <.button phx-click="go" class="ml-2">Send!</.button>
  """
  attr :type, :string, default: "button"
  attr :class, :any, default: nil
  attr :rest, :global, include: ~w(disabled form name value)

  slot :inner_block, required: true

  def button(assigns) do
    ~H"""
    <button
      type={@type}
      class={[
        "inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-xs text-white bg-primary-600 hover:bg-primary-700 focus:outline-hidden focus:ring-2 focus:ring-offset-2 focus:ring-primary-500 dark:ring-offset-zinc-700 cursor-pointer",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  @doc """
  Renders a round icon button, as used in the bottom bar.
  """
  attr :icon, :string, required: true
  attr :title, :string, required: true
  attr :rest, :global, include: ~w(disabled)

  def icon_button(assigns) do
    ~H"""
    <button
      type="button"
      title={@title}
      class="disabled:bg-zinc-300 dark:disabled:bg-zinc-700 disabled:cursor-not-allowed inline-flex items-center p-1.5 border border-transparent rounded-full shadow-xs text-white bg-primary-600 hover:bg-primary-700 focus:outline-hidden focus:ring-2 focus:ring-offset-2 focus:ring-primary-500 dark:ring-offset-zinc-700 cursor-pointer"
      {@rest}
    >
      <.icon name={@icon} class="size-5" />
    </button>
    """
  end

  attr :id, :string, default: nil
  attr :class, :any, default: nil
  attr :rest, :global, include: ~w(name rows)

  slot :inner_block

  def textarea(assigns) do
    ~H"""
    <textarea
      id={@id}
      class={[
        "max-w-lg shadow-xs block w-full p-2 focus:ring-primary-500 focus:border-primary-500 sm:text-sm border border-zinc-300 dark:border-zinc-700 bg-zinc-50 dark:bg-zinc-900 rounded-md text-zinc-800 dark:text-zinc-200",
        @class
      ]}
      {@rest}
    >{render_slot(@inner_block)}</textarea>
    """
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

  attr :id, :string, required: true
  attr :no_border, :boolean, default: false
  attr :on_close, JS, default: %JS{}
  attr :rest, :global

  slot :inner_block, required: true

  def modal(assigns) do
    ~H"""
    <div
      class="fixed z-10 inset-0 overflow-y-auto hidden"
      aria-labelledby="modal-title"
      role="dialog"
      aria-modal="true"
      id={@id}
      phx-remove={hide_modal(@on_close, @id)}
      data-close={JS.hide(to: "##{@id}")}
      {@rest}
    >
      <div class="flex items-end justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:block sm:p-0">
        <div
          class="fixed inset-0 bg-zinc-500/75 dark:bg-zinc-500/25 transition-opacity"
          aria-hidden="true"
          id={"#{@id}-overlay"}
        >
        </div>
        <%!-- This element is to trick the browser into centering the modal contents. --%>
        <span class="hidden sm:inline-block sm:align-middle sm:h-screen" aria-hidden="true">
          &#8203;
        </span>
        <div
          id={"#{@id}-content"}
          class={[
            "hidden relative align-bottom bg-zinc-100 dark:bg-zinc-800 rounded-lg text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-lg w-full",
            !@no_border && "px-4 pt-5 pb-4 sm:p-6"
          ]}
          phx-click-away={hide_modal(@on_close, @id)}
          phx-window-keydown={hide_modal(@on_close, @id)}
          phx-key="escape"
        >
          {render_slot(@inner_block)}
        </div>
      </div>
    </div>
    """
  end

  ### Card

  attr :class, :any, default: nil
  attr :rest, :global

  slot :title
  slot :inner_block, required: true

  def card(assigns) do
    ~H"""
    <div class={["bg-white dark:bg-zinc-800 overflow-hidden shadow-sm rounded-lg", @class]} {@rest}>
      <div class="px-4 py-5 sm:p-6">
        <div
          :if={@title != []}
          class="mb-3 text-lg leading-6 font-medium text-zinc-900 dark:text-zinc-100"
        >
          {render_slot(@title)}
        </div>
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end
end
