defmodule Crawler.ImageDownload do
  def download(crawler_data) do
    crawler_data
    |> Enum.flat_map(fn {_, %{image_tags: tags}} -> tags.internal ++ tags.external end)
    |> Enum.uniq()
    |> Enum.map(&do_download/1)
  end

  defp do_download(image_url) do
    case HTTPoison.get(image_url) do
      {:ok, %{body: body}} ->
        uri = URI.parse(image_url)

        File.mkdir_p!(uri.host)

        IO.inspect(uri)

        file_name =
          uri.path
          |> String.trim_leading("/")
          |> String.replace("/", "-")

        uri.host
        |> Path.join(file_name)
        |> File.write!(body)

      {:error, error} ->
        IO.inspect(error)
    end
  end
end
