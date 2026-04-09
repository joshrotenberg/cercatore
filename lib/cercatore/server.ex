defmodule Cercatore.Server do
  @moduledoc """
  GenServer wrapper around `Cercatore.Index`.

  Provides a process-based interface for when you want to hold the index in
  a named process. All logic delegates to the pure functional core.

  ## Examples

      {:ok, pid} = Cercatore.Server.start_link(name: :products, fields: [:name, :description])
      Cercatore.Server.add(:products, "sku-1", %{name: "Widget", description: "A fine widget"})
      results = Cercatore.Server.query(:products, "widget")

  ## Persistence

  Pass `:store` and `:store_ref` options to enable persistence. The index
  is loaded on init (if available) and saved on `flush/1` and terminate.

      Cercatore.Server.start_link(
        name: :products,
        store: Cercatore.Store.File,
        store_ref: "/tmp/products.idx"
      )
      Cercatore.Server.flush(:products)  # saves to disk
  """

  use GenServer

  alias Cercatore.Index

  @type server :: GenServer.server()

  # -- Client API --

  @doc """
  Starts a new server.

  ## Options

    * `:name` - process registration name (optional)
    * `:store` - module implementing `Cercatore.Store` (optional)
    * `:store_ref` - reference passed to store save/load (optional)
    * All other options are passed to `Cercatore.Index.new/1`
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    {server_opts, index_opts} =
      Keyword.split(opts, [:name, :store, :store_ref])

    gen_opts =
      case Keyword.fetch(server_opts, :name) do
        {:ok, name} -> [name: name]
        :error -> []
      end

    GenServer.start_link(__MODULE__, {server_opts, index_opts}, gen_opts)
  end

  @doc """
  Adds a document to the index.

  ## Examples

      Cercatore.Server.add(pid, "doc1", "hello world")
      Cercatore.Server.add(pid, "doc1", %{title: "Hello", body: "World"})
  """
  @spec add(server(), Index.doc_id(), String.t() | %{atom() => String.t()}) :: :ok
  def add(server, id, content) do
    GenServer.call(server, {:add, id, content})
  end

  @doc """
  Adds multiple documents at once.
  """
  @spec add_all(server(), [{Index.doc_id(), String.t() | %{atom() => String.t()}}]) :: :ok
  def add_all(server, docs) do
    GenServer.call(server, {:add_all, docs})
  end

  @doc """
  Removes a document from the index.
  """
  @spec remove(server(), Index.doc_id()) :: :ok
  def remove(server, id) do
    GenServer.call(server, {:remove, id})
  end

  @doc """
  Queries the index.

  ## Options

  See `Cercatore.Index.query/3` for available options.
  """
  @spec query(server(), String.t(), keyword()) :: [Cercatore.Result.t()]
  def query(server, query_text, opts \\ []) do
    GenServer.call(server, {:query, query_text, opts})
  end

  @doc """
  Returns the number of documents in the index.
  """
  @spec size(server()) :: non_neg_integer()
  def size(server) do
    GenServer.call(server, :size)
  end

  @doc """
  Saves the current index to the configured store.

  Returns `{:error, :no_store}` if no store is configured.
  """
  @spec flush(server()) :: :ok | {:error, term()}
  def flush(server) do
    GenServer.call(server, :flush)
  end

  # -- Server Callbacks --

  @impl true
  def init({server_opts, index_opts}) do
    store = Keyword.get(server_opts, :store)
    store_ref = Keyword.get(server_opts, :store_ref)

    index =
      if store && store_ref do
        case store.load(store_ref) do
          {:ok, loaded} -> loaded
          {:error, _} -> Index.new(index_opts)
        end
      else
        Index.new(index_opts)
      end

    {:ok, %{index: index, store: store, store_ref: store_ref}}
  end

  @impl true
  def handle_call({:add, id, content}, _from, state) do
    {:reply, :ok, %{state | index: Index.add(state.index, id, content)}}
  end

  def handle_call({:add_all, docs}, _from, state) do
    {:reply, :ok, %{state | index: Index.add_all(state.index, docs)}}
  end

  def handle_call({:remove, id}, _from, state) do
    {:reply, :ok, %{state | index: Index.remove(state.index, id)}}
  end

  def handle_call({:query, query_text, opts}, _from, state) do
    {:reply, Index.query(state.index, query_text, opts), state}
  end

  def handle_call(:size, _from, state) do
    {:reply, Index.size(state.index), state}
  end

  def handle_call(:flush, _from, state) do
    result = do_save(state)
    {:reply, result, state}
  end

  @impl true
  def terminate(_reason, state) do
    do_save(state)
    :ok
  end

  defp do_save(%{store: nil}), do: {:error, :no_store}
  defp do_save(%{store_ref: nil}), do: {:error, :no_store}
  defp do_save(%{store: store, store_ref: ref, index: index}), do: store.save(index, ref)
end
