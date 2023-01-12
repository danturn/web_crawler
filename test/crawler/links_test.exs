defmodule Crawler.LinksTest do
  use ExUnit.Case, async: true
  alias Crawler.Links

  @root_authority "example.com"
  test "No links in empty document" do
    assert %{
             a_tags: no_links(),
             script_tags: no_links(),
             link_tags: no_links(),
             image_tags: no_links(),
             iframe_tags: no_links(),
             embed_tags: no_links()
           } ==
             Links.find("", @root_authority, "https")
  end

  test "Single root <a> tag in document" do
    assert %{
             a_tags: %{internal: ["https://#{@root_authority}"], external: []},
             script_tags: no_links(),
             link_tags: no_links(),
             iframe_tags: no_links(),
             image_tags: no_links(),
             embed_tags: no_links()
           } ==
             Links.find(~s|<a href="/"|, @root_authority, "https")
  end

  test "Discard empty tags" do
    assert %{
             a_tags: no_links(),
             script_tags: no_links(),
             link_tags: no_links(),
             iframe_tags: no_links(),
             image_tags: no_links(),
             embed_tags: no_links()
           } ==
             Links.find(
               ~s|<img src="">
                  <a href="">
               |,
               @root_authority,
               "https"
             )
  end

  test "don't assume https" do
    assert %{
             a_tags: %{internal: ["http://#{@root_authority}/about"], external: []},
             script_tags: no_links(),
             link_tags: no_links(),
             iframe_tags: no_links(),
             image_tags: no_links(),
             embed_tags: no_links()
           } ==
             Links.find(~s|<a href="http://#{@root_authority}/about"|, @root_authority, "https")
  end

  test "remove trailing slash" do
    assert %{
             a_tags: %{internal: ["http://#{@root_authority}"], external: []},
             script_tags: no_links(),
             link_tags: no_links(),
             iframe_tags: no_links(),
             image_tags: no_links(),
             embed_tags: no_links()
           } ==
             Links.find(~s|<a href="http://#{@root_authority}/"|, @root_authority, "https")
  end

  test "remove fragment" do
    assert %{
             a_tags: %{internal: ["http://#{@root_authority}"], external: []},
             script_tags: no_links(),
             link_tags: no_links(),
             iframe_tags: no_links(),
             image_tags: no_links(),
             embed_tags: no_links()
           } ==
             Links.find(
               ~s|<a href="http://#{@root_authority}/#hello-dave"|,
               @root_authority,
               "https"
             )
  end

  test "Single relative <a> tag in document" do
    assert %{
             a_tags: %{internal: ["https://#{@root_authority}/about"], external: []},
             script_tags: no_links(),
             link_tags: no_links(),
             iframe_tags: no_links(),
             image_tags: no_links(),
             embed_tags: no_links()
           } ==
             Links.find(~s|<a href="/about"|, @root_authority, "https")
  end

  test "Retrieves external links" do
    assert %{
             a_tags: %{internal: [], external: ["https://another-url.com/hello"]},
             script_tags: no_links(),
             link_tags: no_links(),
             iframe_tags: no_links(),
             image_tags: no_links(),
             embed_tags: no_links()
           } ==
             Links.find(~s|<a href="https://another-url.com/hello"|, @root_authority, "https")
  end

  test "Single relative <a> tag without forward slash in document" do
    assert %{
             a_tags: %{internal: ["https://#{@root_authority}/about.html"], external: []},
             script_tags: no_links(),
             link_tags: no_links(),
             iframe_tags: no_links(),
             image_tags: no_links(),
             embed_tags: no_links()
           } ==
             Links.find(~s|<a href="about.html"|, @root_authority, "https")
  end

  test "Single absolute <a> tag in document" do
    assert %{
             a_tags: %{internal: ["https://#{@root_authority}/about"], external: []},
             script_tags: no_links(),
             link_tags: no_links(),
             iframe_tags: no_links(),
             image_tags: no_links(),
             embed_tags: no_links()
           } ==
             Links.find(~s|<a href="https://#{@root_authority}/about"|, @root_authority, "https")
  end

  test "Stylesheet link in document" do
    assert %{
             a_tags: no_links(),
             script_tags: no_links(),
             link_tags: %{internal: ["https://#{@root_authority}/site.css"], external: []},
             iframe_tags: no_links(),
             image_tags: no_links(),
             embed_tags: no_links()
           } ==
             Links.find(
               ~s|<link rel="stylesheet" href="/site.css">|,
               @root_authority,
               "https"
             )
  end

  test "Mixed" do
    assert %{
             a_tags: %{
               internal: [
                 "https://#{@root_authority}/blog",
                 "https://#{@root_authority}/news"
               ],
               external: []
             },
             script_tags: no_links(),
             link_tags: %{internal: ["https://#{@root_authority}/site.css"], external: []},
             iframe_tags: %{internal: ["https://#{@root_authority}/iframe"], external: []},
             image_tags: %{internal: ["https://#{@root_authority}/images/plop.png"], external: []},
             embed_tags: %{
               external: [],
               internal: [
                 "https://example.com/youtube_or_whatever"
               ]
             }
           } ==
             Links.find(
               """
                        <html>
                          <a href="/news">
                          <a href="https://#{@root_authority}/blog">
                          <link rel="stylesheet" href="/site.css">
                          <img src="/images/plop.png">
                          <iframe src="/iframe">
                          <embed src="/youtube_or_whatever">
                        </html>
               """,
               @root_authority,
               "https"
             )
  end

  test "Removes duplicate tags" do
    assert %{
             a_tags: %{
               internal: [
                 "https://#{@root_authority}/blog",
                 "https://#{@root_authority}/about"
               ],
               external: []
             },
             script_tags: no_links(),
             link_tags: no_links(),
             image_tags: no_links(),
             iframe_tags: no_links(),
             embed_tags: no_links()
           } ==
             Links.find(
               """
                        <html>
                          <a href="/about">
                          <a href="https://#{@root_authority}/blog">
                          <a href="/about">
                          <a href="https://#{@root_authority}/blog">
                        </html>
               """,
               @root_authority,
               "https"
             )
  end

  defp no_links do
    %{internal: [], external: []}
  end
end
