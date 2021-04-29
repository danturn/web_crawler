defmodule Crawler do
  alias Crawler.{Queue, Fetcher, Parser, Store}

  def start(url, subscriber) do
    {:ok, store} = Store.start_link(subscriber)
    {:ok, queue} = Queue.start_link(store)

    1..20
    |> Enum.map(fn _ ->
      {:ok, fetcher} = Fetcher.start_link(queue)
      {:ok, _} = Parser.start_link(queue, store, fetcher)
    end)

    Queue.enqueue(queue, [url])
  end
end
