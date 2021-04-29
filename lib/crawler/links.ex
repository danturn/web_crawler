defmodule Crawler.Links do
  def find(html, root_authority) do
    html
    |> Floki.parse_document!()
    |> Floki.find("a")
    |> Floki.attribute("href")
    |> Enum.reduce([], &standardise_url(&1, &2, root_authority))
    |> Enum.uniq()
  end

  defp standardise_url("/" <> link, acc, root_authority) do
    [url_from_path("/#{link}", root_authority) | acc]
  end

  defp standardise_url(link, acc, root_authority) do
    parsed = URI.parse(link)

    if parsed.authority == root_authority do
      [url_from_path(parsed.path, root_authority) | acc]
    else
      acc
    end
  end

  defp url_from_path(path, root_authority), do: "https://#{root_authority}#{path}"
end
