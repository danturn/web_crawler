defmodule Crawler do
  alias Crawler.{Queue, Fetcher, Parser, Store}

  def start(url, download_images, subscriber) do
    {:ok, store} = Store.start_link(subscriber)
    {:ok, queue} = Queue.start_link(store)

    1..10
    |> Enum.map(fn _ ->
      {:ok, fetcher} = Fetcher.start_link(queue)
      {:ok, _} = Parser.start_link(queue, store, fetcher)
    end)

    Queue.enqueue(queue, [url])

    %{store_pid: store}
  end
end
