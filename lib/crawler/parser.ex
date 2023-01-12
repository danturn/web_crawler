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
      {url, {:cannot_fetch, reason}} ->
        Crawler.Store.insert(pids.store, url, {:cannot_fetch, reason})

      {url, html} ->
        %{authority: root_authority, scheme: scheme} = URI.parse(url)

        links = Links.find(html, root_authority, scheme)

        links_to_crawl =
          links.a_tags.internal
          |> Enum.reduce([], fn child_url, acc ->
            if String.ends_with?(child_url, "/") do
              raise child_url
            end

            if child_url == url do
              acc
            else
              [child_url | acc]
            end
          end)

        Crawler.Queue.enqueue(pids.queue, links_to_crawl)
        Crawler.Store.insert(pids.store, url, links)
    end)

    {:noreply, [], pids}
  end
end
