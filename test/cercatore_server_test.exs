defmodule Cercatore.ServerTest do
  use ExUnit.Case

  describe "server basics" do
    test "start, add, query" do
      {:ok, pid} = Cercatore.Server.start_link()
      Cercatore.Server.add(pid, "d1", "the quick brown fox")
      Cercatore.Server.add(pid, "d2", "the lazy dog")

      results = Cercatore.Server.query(pid, "quick fox")
      assert hd(results).id == "d1"
    end

    test "named server" do
      {:ok, _pid} = Cercatore.Server.start_link(name: :test_index)
      Cercatore.Server.add(:test_index, "d1", "hello world")

      assert Cercatore.Server.size(:test_index) == 1
      results = Cercatore.Server.query(:test_index, "hello")
      assert hd(results).id == "d1"
    end

    test "add_all" do
      {:ok, pid} = Cercatore.Server.start_link()

      Cercatore.Server.add_all(pid, [
        {"d1", "hello world"},
        {"d2", "hello there"}
      ])

      assert Cercatore.Server.size(pid) == 2
    end

    test "remove" do
      {:ok, pid} = Cercatore.Server.start_link()
      Cercatore.Server.add(pid, "d1", "hello world")
      Cercatore.Server.add(pid, "d2", "hello there")
      Cercatore.Server.remove(pid, "d1")

      assert Cercatore.Server.size(pid) == 1
    end

    test "query with options" do
      {:ok, pid} = Cercatore.Server.start_link()
      Cercatore.Server.add(pid, "d1", "hello world")

      results = Cercatore.Server.query(pid, "hello", limit: 1)
      assert length(results) == 1
    end

    test "multi-field with server" do
      {:ok, pid} =
        Cercatore.Server.start_link(fields: [:title, :body], weights: %{title: 2.0})

      Cercatore.Server.add(pid, "d1", %{title: "Elixir", body: "Programming"})
      results = Cercatore.Server.query(pid, "elixir")
      assert hd(results).id == "d1"
    end
  end

  describe "persistence" do
    test "flush saves and load restores" do
      path = Path.join(System.tmp_dir!(), "cercatore_server_test_#{System.unique_integer()}")

      {:ok, pid} =
        Cercatore.Server.start_link(store: Cercatore.Store.File, store_ref: path)

      Cercatore.Server.add(pid, "d1", "hello world")
      assert :ok == Cercatore.Server.flush(pid)
      GenServer.stop(pid)

      {:ok, pid2} =
        Cercatore.Server.start_link(store: Cercatore.Store.File, store_ref: path)

      assert Cercatore.Server.size(pid2) == 1
      results = Cercatore.Server.query(pid2, "hello")
      assert hd(results).id == "d1"

      GenServer.stop(pid2)
      File.rm(path)
    end

    test "flush without store returns error" do
      {:ok, pid} = Cercatore.Server.start_link()
      assert {:error, :no_store} == Cercatore.Server.flush(pid)
    end

    test "load from missing file starts fresh" do
      {:ok, pid} =
        Cercatore.Server.start_link(
          store: Cercatore.Store.File,
          store_ref: "/tmp/nonexistent_#{System.unique_integer()}"
        )

      assert Cercatore.Server.size(pid) == 0
      GenServer.stop(pid)
    end
  end
end
