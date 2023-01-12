defmodule Crawler.Links do
  # TODO image with empty src tag :(
  def find(html, root_authority, root_scheme) do
    document = Floki.parse_document!(html)

    hyperlinks =
      document
      |> Floki.find("a")
      |> Floki.attribute("href")
      |> format(root_authority, root_scheme)

    stylesheet_links =
      document
      |> Floki.find("link")
      |> Floki.attribute("href")
      |> format(root_authority, root_scheme)

    script_links =
      document
      |> Floki.find("script")
      |> Floki.attribute("src")
      |> format(root_authority, root_scheme)

    images =
      document
      |> Floki.find("img")
      |> Floki.attribute("src")
      |> format(root_authority, root_scheme)

    embeds =
      document
      |> Floki.find("embed")
      |> Floki.attribute("src")
      |> format(root_authority, root_scheme)

    iframes =
      document
      |> Floki.find("iframe")
      |> Floki.attribute("src")
      |> format(root_authority, root_scheme)

    %{
      a_tags: hyperlinks,
      link_tags: stylesheet_links,
      script_tags: script_links,
      image_tags: images,
      embed_tags: embeds,
      iframe_tags: iframes
    }
  end

  defp format(nodes, root_authority, root_scheme) do
    nodes
    |> Enum.reduce(
      %{internal: [], external: []},
      fn link, acc ->
        standardise_url(link, acc, root_authority, root_scheme)
      end
    )
    |> (fn acc ->
          %{acc | internal: Enum.uniq(acc.internal), external: Enum.uniq(acc.external)}
        end).()
  end

  defp standardise_url("", acc, _, _), do: acc

  defp standardise_url("/" <> link, acc, root_authority, root_scheme) do
    %{acc | internal: [url_from_path(root_authority, "#{link}", root_scheme) | acc.internal]}
  end

  defp standardise_url(link, acc, root_authority, root_scheme) do
    parsed = URI.parse(link)

    cond do
      parsed.authority == root_authority ->
        %{
          acc
          | internal: [url_from_path(root_authority, parsed.path, parsed.scheme) | acc.internal]
        }

      parsed.scheme == nil && parsed.host == nil ->
        %{
          acc
          | internal: [
              url_from_path(root_authority, "#{parsed.path}", root_scheme) | acc.internal
            ]
        }

      true ->
        %{acc | external: [link | acc.external]}
    end
  end

  defp url_from_path(root_authority, nil, scheme) do
    "#{scheme}://#{root_authority}"
  end

  defp url_from_path(root_authority, "", scheme) do
    "#{scheme}://#{root_authority}"
  end

  defp url_from_path(root_authority, path, scheme) do
    path = String.trim_leading(path, "/")

    "#{scheme}://#{root_authority}/#{path}"
    |> String.split("#")
    |> hd()
    |> String.trim_trailing("/")
  end
end
