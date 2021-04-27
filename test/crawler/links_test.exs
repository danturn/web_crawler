defmodule Crawler.LinksTest do
  use ExUnit.Case, async: true
  alias Crawler.Links

  @root_authority "example.com"
  test "No links in empty document" do
    assert [] == Links.find("", @root_authority)
  end

  test "Single root link in document" do
    assert ["/"] == Links.find(~s|<a href="/"|, @root_authority)
  end

  test "Single relative link in document" do
    assert ["/about"] == Links.find(~s|<a href="/about"|, @root_authority)
  end

  test "Single absolute link in document" do
    assert ["/about"] ==
             Links.find(~s|<a href="https://#{@root_authority}/about"|, @root_authority)
  end

  test "Multiple tags in document" do
    assert [
             "/blog",
             "/news",
             "/contact",
             "/about"
           ] ==
             Links.find(
               """
                 <html>
                   <a href="/about">
                   <a href="/contact">
                   <a href="/news">
                   <a href="https://#{@root_authority}/blog">
                 </html>
               """,
               @root_authority
             )
  end

  test "Removes duplicate tags" do
    assert [
             "/blog",
             "/about"
           ] ==
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
