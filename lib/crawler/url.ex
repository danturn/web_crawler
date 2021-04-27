defmodule URL do
  alias Crawler.{Crawler, Links, Queue, Fetcher, Parser, Store}

  def crawl(url) do
    Store.start_link()
    Queue.start_link()
    {:ok, fetcher} = Fetcher.start_link()
    {:ok, parser} = Parser.start_link()
    {:ok, parser2} = Parser.start_link()

    GenStage.sync_subscribe(parser, to: fetcher)

    GenStage.sync_subscribe(parser2, to: fetcher)

    Queue.enqueue(["https://multiverse.io"])
  end

  defp do_crawl([], site_map, _), do: site_map

  defp do_crawl([path | rest], site_map, root_authority) do
    site_map =
      if not Map.has_key?(site_map, path) do
        links =
          path
          |> url_from_path(root_authority)
          |> links_for_url(root_authority)

        new_site = Map.put(site_map, path, links)
        do_crawl(links, new_site, root_authority)
      else
        site_map
      end

    do_crawl(rest, site_map, root_authority)
  end

  defp links_for_url(url, root_authority) do
    url
    |> get()
    |> and_then(&Links.find(&1, root_authority))
    |> otherwise(fn _ -> {:ok, []} end)
    |> strip_ok()
  end

  defp url_from_path(path, root_authority), do: "https://#{root_authority}#{path}"

  defp get(url) do
    case HTTPoison.get(url, [{"content-type", "text/html"}], follow_redirect: true) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, body}

      {:ok, %HTTPoison.Response{status_code: 404}} ->
        {:error, :not_found}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end

  defp and_then({:ok, result}, fun), do: fun.(result)
  defp and_then(error = {:error, _}, _), do: error

  defp otherwise({:error, reason}, fun), do: fun.(reason)
  defp otherwise(result, _), do: result

  defp strip_ok({:ok, result}), do: result
end

defmodule Crawler.Queue do
  use GenStage

  def start_link() do
    # IO.puts("START")

    GenStage.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(_) do
    {:producer, {:queue.new(), 0}}
  end

  def enqueue(links) do
    # IO.inspect(links, label: "ENQUEING")
    GenStage.cast(__MODULE__, {:enqueue, links})
  end

  def handle_cast({:enqueue, links}, {queue, pending_demand}) do
    queue =
      Enum.reduce(links, queue, fn link, queue ->
        :queue.in(link, queue)
      end)

    # ' IO.inspect("NEW QUEUE: #{inspect(queue)}", label: "ENQUEUE")
    dispatch_events(queue, pending_demand, [])
  end

  def handle_demand(incoming_demand, {queue, pending_demand}) do
    # IO.puts("HANDLE DEMAND")
    # IO.inspect(queue, label: "QUEUE")
    dispatch_events(queue, incoming_demand + pending_demand, [])
  end

  defp dispatch_events(queue, 0, events) do
    {:noreply, Enum.reverse(events), {queue, 0}}
  end

  defp dispatch_events(queue, demand, events) do
    #    IO.puts("DISPATCH: #{inspect(queue)}, demand: #{inspect(demand)} events: #{inspect(events)}")

    case :queue.out(queue) do
      {{:value, event}, queue} ->
        dispatch_events(queue, demand - 1, [event | events])

      {:empty, queue} ->
        {:noreply, Enum.reverse(events), {queue, demand}}
    end
  end
end

defmodule Crawler.Fetcher do
  use GenStage

  def start_link() do
    GenStage.start_link(__MODULE__, :ok)
  end

  def init(:ok) do
    {:producer_consumer, :ok, subscribe_to: [Crawler.Queue]}
  end

  def handle_events(paths, _from, state) do
    html =
      paths
      |> Enum.reduce([], fn path, acc ->
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
    case HTTPoison.get(url, [{"content-type", "text/html"}], follow_redirect: true) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, body}

      {:ok, %HTTPoison.Response{status_code: 404}} ->
        {:error, :not_found}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end
end

defmodule Crawler.Parser do
  alias Crawler.Links
  use GenStage

  def start_link() do
    GenStage.start_link(__MODULE__, :ok)
  end

  def init(_) do
    {:consumer, []}
  end

  def handle_events(html_results, _from, state) do
    Enum.map(html_results, fn {url, html} ->
      %{authority: root_authority} = URI.parse(url)
      {:ok, links} = Links.find(html, state)

      links = links |> Enum.map(fn link -> url_from_path(link, root_authority) end)
      uncrawled_links = Crawler.Store.uncrawled(links)
      Crawler.Store.insert(url, links)
      Crawler.Queue.enqueue(uncrawled_links)
    end)

    {:noreply, [], state}
  end

  defp url_from_path(path, root_authority), do: "https://#{root_authority}#{path}"
end

defmodule Crawler.Store do
  use GenServer

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    {:ok, %{}}
  end

  def insert(link, child_links) do
    GenServer.cast(__MODULE__, {:insert, link, child_links})
  end

  def uncrawled(links) do
    GenServer.call(__MODULE__, {:uncrawled, links})
  end

  def dump_state do
    GenServer.call(__MODULE__, :dump_state)
  end

  def handle_cast({:insert, link, child_links}, state) do
    state = Map.put(state, link, child_links)
    IO.inspect(link, label: "INSERTING")
    {:noreply, state}
  end

  def handle_call({:uncrawled, links}, _, state) do
    known_links = Map.keys(state)

    {:reply, links -- known_links, state}
  end

  def handle_call(:dump_state, _, state) do
    {:reply, state, state}
  end
end
