defmodule CrawlerWeb.PageLive do
  use CrawlerWeb, :live_view
  alias Crawler.Result

  def mount(_params, _session, socket) do
    {:ok, assign(socket, query: "", state: :idle, store: [])}
  end

  def handle_event("search", %{"q" => query}, socket) do
    query
    |> rescue_input()
    |> Result.and_then(&validate_uri/1)
    |> Result.and_then(fn uri ->
      uri_string = URI.to_string(uri)
      start_time = DateTime.utc_now()
      Crawler.start(uri_string, self())

      {:noreply,
       assign(socket, store: [], state: {:waiting, 1}, query: uri_string, start_time: start_time)}
    end)
    |> Result.otherwise(fn _ ->
      {:noreply,
       socket
       |> put_flash(:error, ~s|Invalid url "#{query}" please try again|)
       |> assign(store: [], query: query)}
    end)
  end

  def handle_info(:complete, socket) do
    duration = DateTime.diff(DateTime.utc_now(), socket.assigns.start_time)
    {:noreply, assign(socket, state: {:complete, duration})}
  end

  def handle_info({:update, link, children, remaining}, socket) do
    {:noreply,
     socket
     |> update(:store, fn store -> store ++ [{link, children}] end)
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
      %URI{path: nil} -> rescue_input("#{query}/")
      uri -> {:ok, uri}
    end
  end
end
