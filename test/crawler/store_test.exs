defmodule Crawler.StoreTest do
  use ExUnit.Case, async: true
  alias Crawler.Store

  @link1 "https://example.com"
  @link2 "https://the-real-example.com"
  @child1 "https://example.com/about"
  @child2 "https://example.com/contact"

  setup do
    {:ok, pid} = Store.start_link(self())

    on_exit(fn ->
      ProcessKiller.terminate(pid)
    end)

    {:ok, %{store: pid}}
  end

  describe "init_for_links/2" do
    test "adds new links to store state", %{store: store} do
      assert [@link1, @link2] == Store.init_for_links(store, [@link1, @link2])
      assert {%{@link1 => :pending, @link2 => :pending}, _} = :sys.get_state(store)
    end

    test "Ignores duplicates", %{store: store} do
      assert [@link1, @link2] == Store.init_for_links(store, [@link1, @link2, @link1])
      assert {%{@link1 => :pending, @link2 => :pending}, _} = :sys.get_state(store)
    end

    test "Returned list filters out already known links", %{store: store} do
      assert [@link1] == Store.init_for_links(store, [@link1])
      assert [@link2] == Store.init_for_links(store, [@link1, @link2])
      assert {%{@link1 => :pending, @link2 => :pending}, _} = :sys.get_state(store)
    end
  end

  describe "insert/3" do
    test "Updates pending links with children", %{store: store} do
      assert [@link1] == Store.init_for_links(store, [@link1])
      assert :ok == Store.insert(store, @link1, [@child1, @child2])
      assert {%{@link1 => [@child1, @child2]}, _} = :sys.get_state(store)
    end

    test "Ignores duplicates", %{store: store} do
      assert [@link1] == Store.init_for_links(store, [@link1])
      assert :ok == Store.insert(store, @link1, [@child1, @child2])
      assert {%{@link1 => [@child1, @child2]}, _} = :sys.get_state(store)
    end

    test "Notifies subscribers on insert", %{store: store} do
      assert [@link1] == Store.init_for_links(store, [@link1])
      assert :ok == Store.insert(store, @link1, [@child1, @child2])
      assert {%{@link1 => [@child1, @child2]}, _} = :sys.get_state(store)
      assert_receive({:update, @link1, [@child1, @child2], 0})
    end

    test "Notifies subscribers when all pending are resolved", %{store: store} do
      assert [@link1] == Store.init_for_links(store, [@link1])
      assert [@link2] == Store.init_for_links(store, [@link2])

      assert :ok == Store.insert(store, @link1, [@child1, @child2])
      assert {%{@link1 => [@child1, @child2]}, _} = :sys.get_state(store)
      assert_receive({:update, @link1, [@child1, @child2], 1})

      assert :ok == Store.insert(store, @link2, [@child1])
      assert {%{@link2 => [@child1]}, _} = :sys.get_state(store)
      assert_receive({:update, @link2, [@child1], 0})
    end

    @tag :capture_log
    test "Raises if link is not already pending", %{store: store} do
      Process.flag(:trap_exit, true)

      catch_exit do
        Store.insert(store, @link1, [])
      end

      assert_received({:EXIT, ^store, {{:badkey, @link1}, _}})
    end
  end
end
