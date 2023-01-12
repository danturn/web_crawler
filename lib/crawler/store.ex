defmodule Crawler.Store do
  use GenServer

  def start_link(subscriber) do
    GenServer.start_link(__MODULE__, subscriber)
  end

  def init(subscriber) do
    {:ok, {%{}, subscriber}}
  end

  def init_for_links(pid, links) do
    GenServer.call(pid, {:init_for_links, links})
  end

  def insert(pid, link, child_links) do
    GenServer.call(pid, {:insert, link, child_links})
  end

  def dump_state(pid) do
    GenServer.call(pid, :dump_state)
  end

  def show_state(pid) do
    GenServer.call(pid, :show_state)
  end

  def handle_call({:init_for_links, links}, _, {store, subscriber}) do
    {uncrawled, store} =
      Enum.reduce(links, {[], store}, fn link, {acc, store} ->
        if Map.has_key?(store, link) do
          {acc, store}
        else
          store = Map.put(store, link, :pending)
          {[link | acc], store}
        end
      end)

    remaining_lookups = remaining_lookups(store)

    {:reply, Enum.reverse(uncrawled), {store, subscriber}}
  end

  def handle_call({:insert, link, child_links}, _, {store, subscriber}) do
    store = Map.update!(store, link, fn :pending -> child_links end)

    remaining_lookups = remaining_lookups(store)

    send(subscriber, {:update, link, child_links, remaining_lookups})

    if remaining_lookups == 0 do
      send(subscriber, :complete)
    end

    {:reply, :ok, {store, subscriber}}
  end

  defp remaining_lookups(store) do
    store
    |> Enum.filter(fn {key, value} -> value == :pending end)
    |> Enum.count()
  end

  def handle_call(:show_state, _, state) do
    {:reply, state, state}
  end

  def handle_call(:dump_state, _, _) do
    {:reply, :ok, %{}}
  end
end
