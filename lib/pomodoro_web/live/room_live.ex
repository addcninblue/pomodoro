defmodule PomodoroWeb.RoomLive do
  use PomodoroWeb, :live_view
  require Logger

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    {:ok, assign(socket, id: id, end_time: nil)}
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

  @impl true
  def handle_event("start-" <> time, _, %Phoenix.LiveView.Socket{} = socket) do
    {minutes, _} = Integer.parse(time)
    end_time = Timex.now() |> Timex.shift(minutes: minutes)
    {:noreply, socket |> assign(end_time: end_time)}
  end
end
