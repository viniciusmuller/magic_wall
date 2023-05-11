# MagicWall

A simple circuit breaker library

# Spawning

## Supervised

In your application's supervision tree:

```elixir 
defmodule MyApp.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Supervisor.child_spec(
        {MagicWall, [
          failures_threshold: 30,
          name: MyApp.BillingAPICircuitBreaker
        ]},
        id: MyApp.BillingAPICircuitBreaker
      ),
      Supervisor.child_spec({
        MagicWall, [
          timeout: 15,
          name: MyApp.DeliveryAPICircuitBreaker
        ]},
        id: MyApp.DeliveryAPICircuitBreaker
      )
    ]

    opts = [strategy: :one_for_one, name: MyApp.Test.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

## Unsupervised

```elixir
iex> {:ok, wall} = MagicWall.start_link(MagicWall, [failures_threshold: 1])
```

# Usage

```elixir
# It takes either the magic wall process or a process name
iex> MagicWall.perform(MyApp.BillingAPICircuitBreaker, fn -> {:ok, :success} end)
{:ok, :success}

iex> MagicWall.perform(wall, fn -> {:error, :failure} end)
{:error, :failure}

iex> MagicWall.perform(wall, fn -> {:ok, :success} end)
{:error, :circuit_breaker_tripped}

# After timeout passes (circuit is half-open now)
iex> MagicWall.perform(wall, fn -> {:ok, :success} end)
{:ok, :success}

# Circuit is opened again
iex> MagicWall.perform(wall, fn -> {:error, :failure} end)
{:error, :failure}
```

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `magic_wall` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:magic_wall, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/magic_wall>.

# TODO
- [ ] Provide a nice way to specify which patterns to count as a failure
