defmodule Crawler.Store do
  use GenServer

  def start_link do
    GenServer.start_link(__MODULE__, [])
  end

  def init(_) do
    {:ok, %{}}
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

  def handle_call({:init_for_links, links}, _, state) do
    {uncrawled, state} =
      Enum.reduce(links, {[], state}, fn link, {acc, state} ->
        if Map.has_key?(state, link) do
          {acc, state}
        else
          state = Map.put(state, link, :pending)
          {[link | acc], state}
        end
      end)

    {:reply, Enum.reverse(uncrawled), state}
  end

  def handle_call({:insert, link, child_links}, _, state) do
    state = Map.update!(state, link, fn :pending -> child_links end)
    {:reply, :ok, state}
  end

  def handle_call(:show_state, _, state) do
    {:reply, state, state}
  end

  def handle_call(:dump_state, _, _) do
    {:reply, :ok, %{}}
  end
end
