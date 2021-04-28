defmodule QueueConsumer do
  use GenStage

  def start_link(pid) do
    GenStage.start_link(__MODULE__, pid)
  end

  def init(pid) do
    {:consumer, pid}
  end

  def handle_events(paths, _from, state) do
    send(state, paths)
    {:noreply, [], state}
  end
end
