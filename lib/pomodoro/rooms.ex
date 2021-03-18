defmodule Pomodoro.Room do
  defstruct participants: [], state: :start, end_time: nil, timer: nil, saved_time: nil

  # TODO: schedule timeout + add timer field. Right now, the client is doing validation before showing a negative time.
end

defmodule Pomodoro.Rooms do
  use GenServer
  alias Phoenix.PubSub

  def start_link(_state) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    # :timer.send_after(1 * 1000, self(), :timer)
    {:ok, %{rooms: %{}, room_mapping: %{}}}
  end

  @impl true
  def handle_info(
        {:DOWN, _ref, :process, from, _reason},
        %{rooms: rooms, room_mapping: room_mapping} = state
      ) do
    {id, room_mapping} = Map.pop!(room_mapping, from)
    room = rooms |> Map.get(id, %Pomodoro.Room{})
    %Pomodoro.Room{participants: participants} = room

    rooms =
      rooms
      |> Map.put(id, %Pomodoro.Room{
        room
        | participants: participants |> Enum.filter(fn user -> user != from end)
      })

    {:noreply, %{state | rooms: rooms, room_mapping: room_mapping}}
  end

  @impl true
  def handle_call(
        {:join_room, id},
        {from, _ref},
        %{rooms: rooms, room_mapping: room_mapping} = state
      ) do
    room_mapping = room_mapping |> Map.put(from, id)
    Process.monitor(from)
    room = rooms |> Map.get(id, %Pomodoro.Room{})
    %Pomodoro.Room{participants: participants} = room
    rooms = rooms |> Map.put(id, %Pomodoro.Room{room | participants: [from | participants]})
    {:reply, room, %{state | rooms: rooms, room_mapping: room_mapping}}
  end

  @impl true
  def handle_call({:time_start, time, id}, _from, %{rooms: rooms} = state) do
    {minutes, _} = Integer.parse(time)
    end_time = Timex.now() |> Timex.shift(minutes: minutes)

    room =
      rooms
      |> Map.get(id)
      |> (fn room ->
            %Pomodoro.Room{room | state: :timer, end_time: end_time}
          end).()

    rooms = Map.put(rooms, id, room)
    PubSub.broadcast(Pomodoro.PubSub, id, {:state, room})

    {:reply, :ok, %{state | rooms: rooms}}
  end

  @impl true
  def handle_call({:break_start, time, id}, _from, %{rooms: rooms} = state) do
    {minutes, _} = Integer.parse(time)
    end_time = Timex.now() |> Timex.shift(minutes: minutes)

    room =
      rooms
      |> Map.get(id)
      |> (fn room ->
            %Pomodoro.Room{room | state: :break_timer, end_time: end_time}
          end).()

    rooms = Map.put(rooms, id, room)

    PubSub.broadcast(Pomodoro.PubSub, id, {:state, room})

    {:reply, :ok, %{state | rooms: rooms}}
  end

  @impl true
  def handle_call({:stop, id}, _from, %{rooms: rooms} = state) do
    room =
      rooms
      |> Map.get(id)
      |> (fn room ->
            %Pomodoro.Room{room | state: :stop, end_time: nil}
          end).()

    rooms = Map.put(rooms, id, room)

    PubSub.broadcast(Pomodoro.PubSub, id, {:state, room})

    {:reply, :ok, %{state | rooms: rooms}}
  end

  @impl true
  def handle_call({:pause_or_resume, id}, _from, %{rooms: rooms} = state) do
    room = rooms |> Map.get(id)
    %Pomodoro.Room{state: room_state, end_time: end_time, saved_time: saved_time} = room

    try do
      new_room_state =
        case room_state do
          :timer -> :timer_paused
          :timer_paused -> :timer
          :break_timer -> :break_timer_paused
          :break_timer_paused -> :break_timer
          _ -> throw("bad pause usage")
        end

      if new_room_state in [:timer_paused, :break_timer_paused] do
        saved_time = Timex.diff(end_time, Timex.now(), :duration)
        room = %Pomodoro.Room{room | state: new_room_state, saved_time: saved_time}
        rooms = Map.put(rooms, id, room)
        PubSub.broadcast(Pomodoro.PubSub, id, {:state, room})

        {:reply, :ok, %{state | rooms: rooms}}
      else
        new_time = Timex.add(Timex.now(), saved_time)
        room = %Pomodoro.Room{room | state: new_room_state, saved_time: nil, end_time: new_time}
        rooms = Map.put(rooms, id, room)
        PubSub.broadcast(Pomodoro.PubSub, id, {:state, room})

        {:reply, :ok, %{state | rooms: rooms}}
      end
    catch
      _ -> {:reply, :ok, state}
    end
  end

  @impl true
  def handle_call({:reset, id}, _from, %{rooms: rooms} = state) do
    room = rooms |> Map.get(id)
    room = %{room | state: :start, end_time: nil, timer: nil, saved_time: nil}
    PubSub.broadcast(Pomodoro.PubSub, id, {:state, room})
    rooms = Map.put(rooms, id, room)
    {:reply, :ok, %{state | rooms: rooms}}
  end

  def join_room(id) do
    PubSub.subscribe(Pomodoro.PubSub, id)
    GenServer.call(Pomodoro.Rooms, {:join_room, id})
  end

  def time_start(time, id) do
    GenServer.call(Pomodoro.Rooms, {:time_start, time, id})
  end

  def break_start(time, id) do
    GenServer.call(Pomodoro.Rooms, {:break_start, time, id})
  end

  def stop(id) do
    GenServer.call(Pomodoro.Rooms, {:stop, id})
  end

  def pause_or_resume(id) do
    GenServer.call(Pomodoro.Rooms, {:pause_or_resume, id})
  end

  def reset(id) do
    GenServer.call(Pomodoro.Rooms, {:reset, id})
  end
end
