defmodule URL do
  alias Crawler.{Links, Queue, Fetcher, Parser, Store}

  def crawl(url) do
    {:ok, store} = Store.start_link()
    {:ok, queue} = Queue.start_link(store)

    1..20
    |> Enum.map(fn _ ->
      {:ok, fetcher} = Fetcher.start_link(queue)
      {:ok, _} = Parser.start_link(queue, store, fetcher)
    end)

    Queue.enqueue(queue, [url])
    IO.puts("YA")
  end
end

defmodule Crawler.Fetcher do
  use GenStage

  def start_link(queue) do
    GenStage.start_link(__MODULE__, queue)
  end

  def init(queue) do
    {:producer_consumer, [], subscribe_to: [{queue, max_demand: 5}]}
  end

  def handle_events(paths, _from, state) do
    html =
      paths
      |> Enum.reduce([], fn path, acc ->
        IO.write(".")

        with {:ok, html} <- get(path) do
          [{path, html} | acc]
        else
          _ ->
            acc
        end
      end)

    {:noreply, html, state}
  end

  defp get(url) do
    headers = [
      {"content-type", "text/html"}
    ]

    case HTTPoison.get(url, headers, follow_redirect: true) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, body}

      {:ok, %HTTPoison.Response{status_code: _}} ->
        {:error, :naughty_error_code}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end
end

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
    Enum.map(html_results, fn {url, html} ->
      %{authority: root_authority} = URI.parse(url)

      links =
        html
        |> Links.find(root_authority)
        |> Enum.reduce([], fn link, acc ->
          child_url = url_from_path(link, root_authority)

          if child_url == url do
            acc
          else
            [child_url | acc]
          end
        end)

      Crawler.Store.insert(pids.store, url, links)
      Crawler.Queue.enqueue(pids.queue, links)
    end)

    {:noreply, [], pids}
  end

  defp url_from_path(path, root_authority), do: "https://#{root_authority}#{path}"
end
