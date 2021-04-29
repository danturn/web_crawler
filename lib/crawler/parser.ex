defmodule Crawler.Parser do
  alias Crawler.Links
  use GenStage

  def start_link(queue, store, fetcher) do
    GenStage.start_link(__MODULE__, %{queue: queue, store: store, fetcher: fetcher})
  end

  def init(pids) do
    {:consumer, pids, subscribe_to: [{pids.fetcher, max_demand: 5}]}
  end

  def handle_events(html_results, _from, pids) do
    Enum.map(html_results, fn
      {url, :cannot_fetch} ->
        Crawler.Store.insert(pids.store, url, [:cannot_fetch])

      {url, html} ->
        %{authority: root_authority} = URI.parse(url)

        links =
          html
          |> Links.find(root_authority)
          |> Enum.reduce([], fn child_url, acc ->
            if child_url == url do
              acc
            else
              [child_url | acc]
            end
          end)

        Crawler.Queue.enqueue(pids.queue, links)
        Crawler.Store.insert(pids.store, url, links)
    end)

    {:noreply, [], pids}
  end
end
