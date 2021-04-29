defmodule Crawler.QueueTest do
  alias Crawler.{Store, Queue}
  use ExUnit.Case, async: true

  @link "https://example.com"
  setup do
    {:ok, store} = Store.start_link(self())
    {:ok, queue} = Queue.start_link(store)
    {:ok, queue_consumer} = QueueConsumer.start_link(self())
    GenStage.sync_subscribe(queue_consumer, to: queue)

    on_exit(fn ->
      :ok = ProcessKiller.terminate(queue)
    end)

    {:ok, %{queue: queue, store: store}}
  end

  describe "enqueue/2" do
    test "subscribers to the queue receive events from enqueueing", %{queue: queue} do
      paths = [@link]
      Queue.enqueue(queue, paths)

      assert_receive(^paths, 500)
    end

    test "subscribers to the queue do not receive events that are already seen", %{queue: queue} do
      paths = [@link]
      Queue.enqueue(queue, paths)
      Queue.enqueue(queue, paths)

      assert_receive(^paths, 500)
      refute_receive(^paths, 500)
    end

    test "notifies the store that the link is in progress", %{queue: queue, store: store} do
      paths = [@link]
      Queue.enqueue(queue, paths)
      assert_receive(^paths, 500)
      assert {%{@link => :pending}, _} = :sys.get_state(store)
    end
  end

  describe "handle_demand/2" do
    test "can drain queue to demand" do
      existing_demand = 0
      additional_demand = 7

      queue = :queue.new()
      full_queue = 1..10 |> Enum.reduce(queue, &:queue.in(&1, &2))
      partially_emptied_queue = {[10, 9], [8]}

      assert {:noreply, [1, 2, 3, 4, 5, 6, 7], {partially_emptied_queue, 0, :store_pid}} ==
               Queue.handle_demand(additional_demand, {full_queue, existing_demand, :store_pid})
    end

    test "accumulates demand if nothing in queue" do
      existing_demand = 1
      additional_demand = 6
      total_demand = 7
      queue = :queue.new()

      assert {:noreply, [], {queue, total_demand, :store_pid}} ==
               Queue.handle_demand(additional_demand, {queue, existing_demand, :store_pid})
    end
  end
end
