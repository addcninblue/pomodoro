defmodule Pomodoro.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      PomodoroWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: Pomodoro.PubSub},
      # Start the Endpoint (http/https)
      PomodoroWeb.Endpoint,
      # Start a worker by calling: Pomodoro.Worker.start_link(arg)
      # {Pomodoro.Worker, arg}
      {Pomodoro.Rooms, name: Pomodoro.Rooms}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Pomodoro.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    PomodoroWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
