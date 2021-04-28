defmodule UrlTest do
  alias URL
  use ExUnit.Case, async: true

  test "MEEMMEM" do
    URL.crawl("https://multiverse.io")
  end
end
