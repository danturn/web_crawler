defmodule Crawler.Queue do
  use GenStage
  alias Crawler.Store

  def start_link(store_pid) do
    GenStage.start_link(__MODULE__, store_pid)
  end

  def init(store_pid) do
    {:producer, {:queue.new(), 0, store_pid}}
  end

  def enqueue(pid, links) do
    GenStage.call(pid, {:enqueue, links})
  end

  def handle_call({:enqueue, links}, from, {queue, pending_demand, store_pid}) do
    queue =
      store_pid
      |> Store.init_for_links(links)
      |> Enum.reduce(queue, &:queue.in/2)

    GenStage.reply(from, :ok)

    dispatch_events(queue, pending_demand, [], store_pid)
  end

  def handle_demand(incoming_demand, {queue, pending_demand, store_pid}) do
    dispatch_events(queue, incoming_demand + pending_demand, [], store_pid)
  end

  defp dispatch_events(queue, 0, events, store_pid) do
    {:noreply, Enum.reverse(events), {queue, 0, store_pid}}
  end

  defp dispatch_events(queue, demand, events, store_pid) do
    case :queue.out(queue) do
      {{:value, event}, queue} ->
        dispatch_events(queue, demand - 1, [event | events], store_pid)

      {:empty, queue} ->
        {:noreply, Enum.reverse(events), {queue, demand, store_pid}}
    end
  end
end
