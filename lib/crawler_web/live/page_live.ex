defmodule CrawlerWeb.PageLive do
  use CrawlerWeb, :live_view
  alias Crawler.{ImageDownload, Result}

  def mount(_params, _session, socket) do
    socket =
      assign(socket, query: "", download_images?: false, state: :idle, store: [], page_count: 0)

    # , temporary_assigns: [store: []]}
    {:ok, socket}
  end

  def handle_event("search", params, socket) do
    query = params["query"]
    download_images? = params["download-images"]

    new_socket =
      query
      |> rescue_input()
      |> Result.and_then(&validate_uri/1)
      |> Result.and_then(fn uri ->
        uri_string = uri |> URI.to_string() |> String.trim_trailing("/")
        start_time = DateTime.utc_now()
        Crawler.start(uri_string, download_images?, self())

        assign(socket,
          state: {:waiting, 1},
          query: uri_string,
          start_time: start_time,
          store: [],
          page_count: 0
        )
      end)
      |> Result.otherwise(fn _ ->
        socket
        |> put_flash(:error, ~s|Invalid url "#{query}" please try again|)
        |> assign(query: query)
      end)
      |> assign(store: [], page_count: 0, download_images?: download_images?)

    {:noreply, new_socket}
  end

  def handle_event("download-images", _, socket) do
    ImageDownload.download(socket.assigns.store)
    {:noreply, socket}
  end

  def handle_info(:complete, socket) do
    # TODO this completes waaaaay before the front end finishes updating, wondering if there's a more optimal way of streaming the results, maybe we should batch them ?
    duration = DateTime.diff(DateTime.utc_now(), socket.assigns.start_time)

    {:noreply,
     socket
     |> update(:store, fn store -> Enum.sort_by(store, fn {link, _} -> link end) end)
     |> assign(state: {:complete, duration})}
  end

  def handle_info({:update, link, children, remaining}, socket) do
    {:noreply,
     socket
     |> update(:store, fn store -> store ++ [{link, children}] end)
     |> update(:page_count, fn current -> current + 1 end)
     |> assign(state: {:waiting, remaining})}
  end

  defp validate_uri(uri) do
    uri.host
    |> to_char_list()
    |> :inet.gethostbyname()
    |> Result.and_then(fn _ -> {:ok, uri} end)
  end

  defp rescue_input(query) do
    query
    |> URI.parse()
    |> case do
      %URI{scheme: nil} -> rescue_input("https://#{query}")
      %URI{host: nil} -> {:error, query}
      %URI{path: nil} -> rescue_input("#{query}")
      uri -> {:ok, uri}
    end
  end
end
