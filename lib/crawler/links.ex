defmodule Crawler.Links do
  def find(html, root_authority) do
    document = Floki.parse_document!(html)

    hyperlinks =
      document
      |> Floki.find("a")
      |> Floki.attribute("href")
      |> format(root_authority)

    stylesheet_links =
      document
      |> Floki.find("link")
      |> Floki.attribute("href")
      |> format(root_authority)

    script_links =
      document
      |> Floki.find("script")
      |> Floki.attribute("src")
      |> format(root_authority)

    images =
      document
      |> Floki.find("img")
      |> Floki.attribute("src")
      |> format(root_authority)

    iframes =
      document
      |> Floki.find("iframe")
      |> Floki.attribute("src")
      |> format(root_authority)

    %{
      a_tags: hyperlinks,
      link_tags: stylesheet_links,
      script_tags: script_links,
      image_tags: images,
      iframe_tags: iframes
    }
  end

  defp format(nodes, root_authority) do
    nodes
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
