defmodule PomodoroWeb.RoomLive do
  use PomodoroWeb, :live_view
  require Logger

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    %Pomodoro.Room{state: state, end_time: end_time} = Pomodoro.Rooms.join_room(id)

    timer =
      case state do
        state when state in [:timer, :break_timer] ->
          {:ok, timer} = :timer.send_interval(1 * 1000, self(), :tick)
          timer

        _ ->
          nil
      end

    {:ok,
     assign(socket,
       id: id,
       end_time: end_time,
       time_remaining: time_remaining(end_time),
       state: state,
       timer: timer,
       play: true
     )}
  end

  @impl true
  def handle_event("time-" <> time, _, %Phoenix.LiveView.Socket{assigns: %{id: id}} = socket) do
    :ok = Pomodoro.Rooms.time_start(time, id)
    {:noreply, socket}
  end

  @impl true
  def handle_event("break-" <> time, _, %Phoenix.LiveView.Socket{assigns: %{id: id}} = socket) do
    :ok = Pomodoro.Rooms.break_start(time, id)
    {:noreply, socket}
  end

  @impl true
  def handle_event("stop", _, %Phoenix.LiveView.Socket{assigns: %{id: id}} = socket) do
    :ok = Pomodoro.Rooms.stop(id)
    {:noreply, socket}
  end

  @impl true
  def handle_event(
        "update_time",
        %{"key" => key},
        %Phoenix.LiveView.Socket{assigns: %{id: id}} = socket
      ) do
    case key do
      " " -> Pomodoro.Rooms.pause_or_resume(id)
      "Enter" -> Pomodoro.Rooms.reset(id)
      _ -> Logger.warn("#{key} not implemented.")
    end

    {:noreply, socket}
  end

  @impl true
  def handle_info(
        {:state, %Pomodoro.Room{state: state, end_time: end_time} = _state},
        %Phoenix.LiveView.Socket{assigns: %{timer: timer}} = socket
      ) do
    {timer, time_remaining} =
      case {state, timer} do
        {state, nil} when state in [:timer, :break_timer] ->
          {:ok, timer} = :timer.send_interval(1 * 1000, self(), :tick)
          {timer, time_remaining(end_time)}

        {state, timer} when state in [:timer, :break_timer] ->
          {timer, time_remaining(end_time)}

        {state, nil} when state in [:timer_paused, :break_timer_paused] ->
          {nil, time_remaining(end_time)}

        {state, timer} when state in [:timer_paused, :break_timer_paused] ->
          {:ok, :cancel} = :timer.cancel(timer)
          {nil, time_remaining(end_time)}

        {_state, nil} ->
          {nil, nil}

        {_state, timer} ->
          {:ok, :cancel} = :timer.cancel(timer)
          {nil, nil}
      end

    {:noreply,
     socket
     |> assign(
       state: state,
       end_time: end_time,
       timer: timer,
       time_remaining: time_remaining
     )}
  end

  def handle_info(
        :tick,
        %Phoenix.LiveView.Socket{assigns: %{end_time: end_time, timer: timer, state: state}} =
          socket
      ) do
    time_remaining(end_time)
    |> case do
      nil ->
        {:ok, :cancel} = :timer.cancel(timer)

        case state do
          :timer ->
            {:noreply,
             socket |> assign(end_time: nil, time_remaining: nil, timer: nil, state: :start_break)}

          :break_timer ->
            {:noreply,
             socket |> assign(end_time: nil, time_remaining: nil, timer: nil, state: :start)}
        end

      time_remaining ->
        {:noreply, socket |> assign(time_remaining: time_remaining)}
    end
  end

  defp time_remaining(end_time) when is_nil(end_time), do: nil

  defp time_remaining(end_time) do
    remaining_seconds = Timex.diff(end_time, Timex.now(), :seconds)

    if remaining_seconds <= 0 do
      nil
    else
      minutes = div(remaining_seconds, 60)
      seconds = rem(remaining_seconds, 60)

      case seconds do
        seconds when seconds >= 10 -> "#{minutes}:#{seconds}"
        seconds when seconds < 0 -> "0:00"
        _ -> "#{minutes}:0#{seconds}"
      end
    end
  end
end
