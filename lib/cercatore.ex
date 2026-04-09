defmodule Cercatore do
  @moduledoc """
  BM25 full-text search with fuzzy matching for Elixir.

  Cercatore provides a pure functional search index with BM25 scoring and
  optional fuzzy query expansion powered by Simile.

  ## Quick start

      iex> index = Cercatore.new()
      iex> index = Cercatore.add(index, "doc1", "The quick brown fox jumps over the lazy dog")
      iex> index = Cercatore.add(index, "doc2", "A brown cat sleeps on the mat")
      iex> [result] = Cercatore.query(index, "quick fox")
      iex> result.id
      "doc1"

  ## Multi-field indexing

      index = Cercatore.new(fields: [:title, :body], weights: %{title: 2.0})
      index = Cercatore.add(index, "doc1", %{title: "Elixir Guide", body: "Learn Elixir programming"})
      Cercatore.query(index, "elixir")

  ## Fuzzy matching

      index = Cercatore.new(fuzzy: [strategy: :jaro_winkler, threshold: 0.85])
      index = Cercatore.add(index, "doc1", "elixir programming")
      Cercatore.query(index, "elxir")  # still finds "doc1"

  See `Cercatore.Index` for the full API.
  """

  alias Cercatore.Index

  @doc """
  Creates a new empty search index. See `Cercatore.Index.new/1` for options.
  """
  @spec new(keyword()) :: Index.t()
  defdelegate new(opts \\ []), to: Index

  @doc """
  Adds a document to the index. See `Cercatore.Index.add/3`.
  """
  @spec add(Index.t(), Index.doc_id(), String.t() | %{atom() => String.t()}) :: Index.t()
  defdelegate add(index, id, content), to: Index

  @doc """
  Adds multiple documents at once. See `Cercatore.Index.add_all/2`.
  """
  @spec add_all(Index.t(), [{Index.doc_id(), String.t() | %{atom() => String.t()}}]) :: Index.t()
  defdelegate add_all(index, docs), to: Index

  @doc """
  Removes a document from the index. See `Cercatore.Index.remove/2`.
  """
  @spec remove(Index.t(), Index.doc_id()) :: Index.t()
  defdelegate remove(index, id), to: Index

  @doc """
  Queries the index. See `Cercatore.Index.query/3` for options.
  """
  @spec query(Index.t(), String.t(), keyword()) :: [Cercatore.Result.t()]
  defdelegate query(index, query_text, opts \\ []), to: Index
end
