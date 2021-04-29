defmodule Crawler.LinksTest do
  use ExUnit.Case, async: true
  alias Crawler.Links

  @root_authority "example.com"
  test "No links in empty document" do
    assert %{
             a_tags: [],
             script_tags: [],
             link_tags: [],
             image_tags: [],
             iframe_tags: []
           } ==
             Links.find("", @root_authority)
  end

  test "Single root <a> tag in document" do
    assert %{
             a_tags: ["https://#{@root_authority}/"],
             script_tags: [],
             link_tags: [],
             iframe_tags: [],
             image_tags: []
           } ==
             Links.find(~s|<a href="/"|, @root_authority)
  end

  test "Single relative <a> tag in document" do
    assert %{
             a_tags: ["https://#{@root_authority}/about"],
             script_tags: [],
             link_tags: [],
             iframe_tags: [],
             image_tags: []
           } ==
             Links.find(~s|<a href="/about"|, @root_authority)
  end

  test "Single absolute <a> tag in document" do
    assert %{
             a_tags: ["https://#{@root_authority}/about"],
             script_tags: [],
             link_tags: [],
             iframe_tags: [],
             image_tags: []
           } ==
             Links.find(~s|<a href="https://#{@root_authority}/about"|, @root_authority)
  end

  test "Stylesheet link in document" do
    assert %{
             a_tags: [],
             script_tags: [],
             link_tags: ["https://#{@root_authority}/site.css"],
             iframe_tags: [],
             image_tags: []
           } ==
             Links.find(
               ~s|<link rel="stylesheet" href="/site.css">|,
               @root_authority
             )
  end

  test "Mixed" do
    assert %{
             a_tags: [
               "https://#{@root_authority}/blog",
               "https://#{@root_authority}/news"
             ],
             script_tags: [],
             link_tags: ["https://#{@root_authority}/site.css"],
             iframe_tags: ["https://#{@root_authority}/iframe"],
             image_tags: ["https://#{@root_authority}/images/plop.png"]
           } ==
             Links.find(
               """
                        <html>
                          <a href="/news">
                          <a href="https://#{@root_authority}/blog">
                          <link rel="stylesheet" href="/site.css">
                          <img src="/images/plop.png">
                          <iframe src="/iframe">
                        </html>
               """,
               @root_authority
             )
  end

  test "Removes duplicate tags" do
    assert %{
             a_tags: [
               "https://#{@root_authority}/blog",
               "https://#{@root_authority}/about"
             ],
             script_tags: [],
             link_tags: [],
             image_tags: [],
             iframe_tags: []
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
               @root_authority
             )
  end
end
