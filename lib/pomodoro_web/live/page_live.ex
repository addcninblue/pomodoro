defmodule PomodoroWeb.PageLive do
  use PomodoroWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, room: "")}
  end

  @impl true
  def handle_event("search", %{"q" => room}, socket) do
    if room =~ ~r(^[a-z]*$) do
      {:noreply, redirect(socket, to: "/room/#{room}")}
    else
      {:noreply,
       socket
       |> put_flash(:error, "Room name must be all lowercase")
       |> assign(room: room)}
    end
  end
end
