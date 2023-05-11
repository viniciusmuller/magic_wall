defmodule MagicWall do
  @moduledoc """
  Circuit breaker implemented as a GenServer

  Server options:
    - failures_threshold: How many failures will cause the circuit to become open
    - failures_interval: The interval, in seconds, of when the failures count will be reset
    - successes_threshold: How many successes will cause the circuit to become closed again
    - successes_interval: The interval, in seconds, of when the successes count will be reset
    - timeout: The interval, in seconds, to transition from :open to :half_open state
    - name: An optional name for the process
  """

  defmodule State do
    @moduledoc false

    defstruct [
      :failures_threshold,
      :failures_interval,
      :successes_threshold,
      :successes_interval,
      :timeout,
      current_failures: 0,
      current_successes: 0,
      state: :closed
    ]
  end

  require Logger

  use GenServer

  # ---- Client ----

  @doc """
  Tries to perform an operation guarded by a magic wall.

  ## Examples

      iex> {:ok, wall} = MagicWall.start_link([failures_threshold: 1])
      iex> MagicWall.perform(wall, fn -> {:ok, :success} end)
      {:ok, :success}
      iex> MagicWall.perform(wall, fn -> {:error, :failure} end)
      {:error, :failure}
      iex> MagicWall.perform(wall, fn -> {:ok, :success} end)
      {:error, :circuit_breaker_tripped}

  """
  def perform(server, fun) do 
    GenServer.call(server, fun)
  end

  # ---- Server ----

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, Keyword.take(opts, [:name]))
  end

  @impl true
  def init(opts) do
    failures_threshold = Keyword.get(opts, :failures_threshold, 20)
    failures_interval = Keyword.get(opts, :failures_interval, 60)
    successes_threshold = Keyword.get(opts, :successes_threshold, 20)
    successes_interval = Keyword.get(opts, :successes_interval, 60)

    {:ok, %State{
      failures_threshold: failures_threshold,
      failures_interval: failures_interval,
      successes_threshold: successes_threshold,
      successes_interval: successes_interval,
      timeout: Keyword.get(opts, :timeout, 15),
    }, {:continue, :setup_reset_timers}}
  end

  @impl true
  def handle_call(fun, {from, _}, %{state: :closed} = state) do
    case fun.() do 
      {:ok, _} = res -> 
        {:reply, res, state}

      {:error, _} = err ->
        if state.current_failures + 1 >= state.failures_threshold do 
          Logger.info("Current failures exceeded failures threshold, opening circuit")
          Process.send_after(self(), :after_timeout, state.timeout * 1000)
          {:reply, err, %{state | state: :open}}
        else
          Logger.info("Operation from #{inspect(from)} failed, increasing current failures to #{state.current_failures + 1}")
          {:reply, err, update_in(state.current_failures, & &1 + 1)}
        end
    end
  end

  @impl true
  def handle_call(_fun, {from, _}, %{state: :open} = state) do
    Logger.info("Call from #{inspect(from)} failed because circuit is open")
    {:reply, {:error, :circuit_breaker_tripped}, state}
  end

  @impl true
  def handle_call(fun, {from, _}, %{state: :half_open} = state) do
    case Enum.random(1..3) do
      1 -> 
        case fun.() do 
          {:ok, _} = res -> 
            if state.current_successes + 1 >= state.successes_threshold do 
              Logger.info("Successes threshold was met, closing circuit")
              {:reply, res, %{state | state: :closed, current_successes: 0}}
            else
              {:reply, res, %{state | current_successes: state.current_successes + 1}}
            end


          {:error, _} = err -> 
            Logger.info("Operation from #{inspect(from)} failed while half-open, opening circuit")
            Process.send_after(self(), :after_timeout, state.timeout * 1000)
            {:reply, err, %{state | state: :open}}
        end

      _ ->
        {:reply, {:error, :circuit_half_open}, state}
    end
  end

  @impl true
  def handle_info(:after_timeout, state) do
    Logger.info("Timeout has passed, circuit is now half-open")
    {:noreply, %{state | state: :half_open}}
  end

  @impl true
  def handle_info(:reset_failures_counter, state) do
    Logger.info("Resetting failures counter at #{state.current_failures} failures.")
    {:noreply, %{state | current_failures: 0}}
  end

  @impl true
  def handle_info(:reset_successes_counter, state) do
    Logger.info("Resetting successes counter at #{state.current_successes} successes.")
    {:noreply, %{state | current_successes: 0}}
  end

  @impl true
  def handle_continue(:setup_reset_timers, state) do 
    :timer.send_interval(state.failures_interval * 1000, :reset_failures_counter)
    :timer.send_interval(state.successes_interval * 1000, :reset_successes_counter)

    {:noreply, state}
  end
end
