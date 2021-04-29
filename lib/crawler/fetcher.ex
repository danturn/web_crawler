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
        with {:ok, html} <- get(path) do
          [{path, html} | acc]
        else
          {:error, reason} ->
            [{path, {:cannot_fetch, reason}} | acc]
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

      {:ok, %HTTPoison.Response{status_code: code}} ->
        {:error, code}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end
end
