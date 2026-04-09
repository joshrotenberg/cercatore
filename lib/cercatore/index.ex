defmodule Cercatore.Index do
  @moduledoc """
  Pure functional BM25 search index.

  The index is a struct that holds an inverted index, document store, and
  corpus statistics. All operations are pure functions -- the caller owns
  the lifecycle and decides where to store the struct.

  ## Examples

      iex> index = Cercatore.Index.new(fields: [:title, :body])
      iex> index = Cercatore.Index.add(index, "doc1", %{title: "Quick Fox", body: "The quick brown fox"})
      iex> [result] = Cercatore.Index.query(index, "fox")
      iex> result.id
      "doc1"

  ## Single-field shorthand

      iex> index = Cercatore.Index.new()
      iex> index = Cercatore.Index.add(index, "doc1", "The quick brown fox")
      iex> [result] = Cercatore.Index.query(index, "fox")
      iex> result.id
      "doc1"
  """

  alias Cercatore.{Fuzzy, Result, Scorer, Tokenizer}

  @default_field :content

  # inverted_index: %{term => %{doc_id => %{field => count}}}
  @type doc_id :: term()
  @type t :: %__MODULE__{
          inverted_index: %{String.t() => %{doc_id() => %{atom() => non_neg_integer()}}},
          documents: %{doc_id() => %{atom() => String.t()}},
          doc_lengths: %{doc_id() => %{atom() => non_neg_integer()}},
          doc_count: non_neg_integer(),
          total_field_lengths: %{atom() => non_neg_integer()},
          fields: [atom()],
          weights: %{atom() => float()},
          vocabulary: MapSet.t(),
          tokenizer: module() | nil,
          k1: float(),
          b: float(),
          fuzzy: Fuzzy.config()
        }

  defstruct inverted_index: %{},
            documents: %{},
            doc_lengths: %{},
            doc_count: 0,
            total_field_lengths: %{},
            fields: [@default_field],
            weights: %{},
            vocabulary: MapSet.new(),
            tokenizer: nil,
            k1: 1.2,
            b: 0.75,
            fuzzy: []

  @doc """
  Creates a new empty index.

  ## Options

    * `:fields` - list of field names (default `[:content]`)
    * `:weights` - map of `%{field => weight}` (default 1.0 for all)
    * `:tokenizer` - module implementing `Cercatore.Tokenizer` behaviour,
      or `nil` to use the default tokenizer (default `nil`)
    * `:k1` - BM25 term frequency saturation (default 1.2)
    * `:b` - BM25 length normalization (default 0.75)
    * `:fuzzy` - fuzzy matching config (see `Cercatore.Fuzzy`)

  ## Examples

      iex> index = Cercatore.Index.new()
      iex> index.fields
      [:content]

      iex> index = Cercatore.Index.new(fields: [:title, :body], weights: %{title: 2.0})
      iex> index.fields
      [:title, :body]
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    fields = Keyword.get(opts, :fields, [@default_field])
    weights = Keyword.get(opts, :weights, %{})

    %__MODULE__{
      fields: fields,
      weights: weights,
      tokenizer: Keyword.get(opts, :tokenizer),
      k1: Keyword.get(opts, :k1, 1.2),
      b: Keyword.get(opts, :b, 0.75),
      fuzzy: Keyword.get(opts, :fuzzy, [])
    }
  end

  @doc """
  Adds a document to the index.

  Accepts either a map of `%{field => text}` or a plain string (which indexes
  into the default `:content` field).

  ## Examples

      iex> index = Cercatore.Index.new(fields: [:title, :body])
      iex> index = Cercatore.Index.add(index, "doc1", %{title: "Elixir", body: "Functional programming"})
      iex> index.doc_count
      1

      iex> index = Cercatore.Index.new()
      iex> index = Cercatore.Index.add(index, "doc1", "hello world")
      iex> index.doc_count
      1
  """
  @spec add(t(), doc_id(), String.t() | %{atom() => String.t()}) :: t()
  def add(%__MODULE__{} = index, id, text) when is_binary(text) do
    add(index, id, %{@default_field => text})
  end

  def add(%__MODULE__{} = index, id, fields) when is_map(fields) do
    index = remove(index, id)

    {inverted_index, doc_lengths, vocabulary} =
      Enum.reduce(index.fields, {index.inverted_index, %{}, index.vocabulary}, fn field,
                                                                                  {inv, lengths,
                                                                                   vocab} ->
        text = Map.get(fields, field, "")
        tokens = tokenize(index, text)
        field_len = length(tokens)
        freqs = Enum.frequencies(tokens)

        {inv, vocab} =
          Enum.reduce(freqs, {inv, vocab}, fn {token, count}, {inv, vocab} ->
            postings = Map.get(inv, token, %{})
            doc_fields = Map.get(postings, id, %{})
            doc_fields = Map.put(doc_fields, field, count)
            postings = Map.put(postings, id, doc_fields)
            {Map.put(inv, token, postings), MapSet.put(vocab, token)}
          end)

        {inv, Map.put(lengths, field, field_len), vocab}
      end)

    total_field_lengths =
      Enum.reduce(doc_lengths, index.total_field_lengths, fn {field, len}, acc ->
        Map.update(acc, field, len, &(&1 + len))
      end)

    %{
      index
      | inverted_index: inverted_index,
        documents: Map.put(index.documents, id, fields),
        doc_lengths: Map.put(index.doc_lengths, id, doc_lengths),
        doc_count: index.doc_count + 1,
        total_field_lengths: total_field_lengths,
        vocabulary: vocabulary
    }
  end

  @doc """
  Adds multiple documents to the index at once.

  Each entry is a `{id, content}` tuple where content is a string or field map.

  ## Examples

      iex> index = Cercatore.Index.new()
      iex> index = Cercatore.Index.add_all(index, [{"d1", "hello"}, {"d2", "world"}])
      iex> index.doc_count
      2
  """
  @spec add_all(t(), [{doc_id(), String.t() | %{atom() => String.t()}}]) :: t()
  def add_all(%__MODULE__{} = index, docs) do
    Enum.reduce(docs, index, fn {id, content}, acc -> add(acc, id, content) end)
  end

  @doc """
  Removes a document from the index.

  Returns the index unchanged if the document doesn't exist.

  ## Examples

      iex> index = Cercatore.Index.new()
      iex> index = Cercatore.Index.add(index, "doc1", "hello world")
      iex> index = Cercatore.Index.remove(index, "doc1")
      iex> index.doc_count
      0
  """
  @spec remove(t(), doc_id()) :: t()
  def remove(%__MODULE__{} = index, id) do
    case Map.fetch(index.documents, id) do
      :error ->
        index

      {:ok, _doc} ->
        do_remove(index, id)
    end
  end

  defp do_remove(index, id) do
    old_lengths = Map.get(index.doc_lengths, id, %{})

    inverted_index =
      Enum.reduce(index.inverted_index, %{}, fn {term, postings}, acc ->
        case Map.delete(postings, id) do
          empty when map_size(empty) == 0 -> acc
          remaining -> Map.put(acc, term, remaining)
        end
      end)

    vocabulary = MapSet.new(Map.keys(inverted_index))

    total_field_lengths =
      Enum.reduce(old_lengths, index.total_field_lengths, fn {field, len}, acc ->
        Map.update(acc, field, 0, &max(&1 - len, 0))
      end)

    %{
      index
      | inverted_index: inverted_index,
        documents: Map.delete(index.documents, id),
        doc_lengths: Map.delete(index.doc_lengths, id),
        doc_count: max(index.doc_count - 1, 0),
        total_field_lengths: total_field_lengths,
        vocabulary: vocabulary
    }
  end

  @doc """
  Queries the index and returns ranked results.

  ## Options

    * `:limit` - max number of results (default 10)
    * `:min_score` - minimum BM25 score threshold (default 0.0)
    * `:fuzzy` - override fuzzy config for this query
    * `:fields` - restrict search to specific fields (default: all fields)

  ## Examples

      iex> index = Cercatore.Index.new()
      iex> index = Cercatore.Index.add(index, "d1", "the quick brown fox")
      iex> index = Cercatore.Index.add(index, "d2", "the lazy dog")
      iex> results = Cercatore.Index.query(index, "quick fox")
      iex> hd(results).id
      "d1"

      iex> index = Cercatore.Index.new()
      iex> Cercatore.Index.query(index, "anything")
      []
  """
  @spec query(t(), String.t(), keyword()) :: [Result.t()]
  def query(index, query_text, opts \\ [])

  def query(%__MODULE__{doc_count: 0}, _query_text, _opts), do: []

  def query(%__MODULE__{} = index, query_text, opts) do
    limit = Keyword.get(opts, :limit, 10)
    min_score = Keyword.get(opts, :min_score, 0.0)
    fuzzy_config = Keyword.get(opts, :fuzzy, index.fuzzy)
    query_fields = Keyword.get(opts, :fields, index.fields)

    query_tokens = tokenize(index, query_text)

    resolved_terms = resolve_query_terms(query_tokens, index.vocabulary, fuzzy_config)

    term_doc_counts = term_document_counts(index, Enum.map(resolved_terms, &elem(&1, 0)))

    index.documents
    |> Enum.map(fn {doc_id, _doc} ->
      score_document(index, doc_id, resolved_terms, term_doc_counts, query_fields)
    end)
    |> Enum.filter(fn result -> result.score > min_score end)
    |> Enum.sort_by(fn result -> result.score end, :desc)
    |> Enum.take(limit)
  end

  @doc """
  Returns the number of documents in the index.

  ## Examples

      iex> index = Cercatore.Index.new()
      iex> Cercatore.Index.size(index)
      0
  """
  @spec size(t()) :: non_neg_integer()
  def size(%__MODULE__{doc_count: n}), do: n

  @doc """
  Returns the vocabulary (set of all indexed terms).

  ## Examples

      iex> index = Cercatore.Index.new()
      iex> index = Cercatore.Index.add(index, "d1", "hello world")
      iex> "hello" in Cercatore.Index.vocabulary(index)
      true
  """
  @spec vocabulary(t()) :: MapSet.t()
  def vocabulary(%__MODULE__{vocabulary: v}), do: v

  # -- Private --

  defp tokenize(%__MODULE__{tokenizer: nil}, text), do: Tokenizer.tokenize(text)
  defp tokenize(%__MODULE__{tokenizer: mod}, text), do: mod.tokenize(text)

  defp resolve_query_terms(tokens, vocabulary, fuzzy_config) do
    if fuzzy_config == [] or Keyword.get(fuzzy_config, :strategy) == :none do
      Enum.map(tokens, fn t -> {t, 1.0} end)
    else
      Fuzzy.resolve_terms(tokens, vocabulary, fuzzy_config)
    end
  end

  defp term_document_counts(index, terms) do
    Map.new(terms, fn term ->
      postings = Map.get(index.inverted_index, term, %{})
      {term, map_size(postings)}
    end)
  end

  defp score_document(index, doc_id, resolved_terms, term_doc_counts, query_fields) do
    doc_field_lengths = Map.get(index.doc_lengths, doc_id, %{})

    {total_score, matches} =
      Enum.reduce(query_fields, {0.0, %{}}, fn field, {score_acc, matches_acc} ->
        {field_score, field_matches} =
          score_field(index, doc_id, field, doc_field_lengths, resolved_terms, term_doc_counts)

        field_weight = Map.get(index.weights, field, 1.0)
        score_acc = score_acc + field_score * field_weight

        matches_acc =
          if field_matches != [] do
            Map.put(matches_acc, field, Enum.reverse(field_matches))
          else
            matches_acc
          end

        {score_acc, matches_acc}
      end)

    %Result{id: doc_id, score: total_score, matches: matches}
  end

  defp score_field(index, doc_id, field, doc_field_lengths, resolved_terms, term_doc_counts) do
    doc_len = Map.get(doc_field_lengths, field, 0)
    avg_len = avg_field_length(index, field)

    Enum.reduce(resolved_terms, {0.0, []}, fn {term, weight}, {fs, fm} ->
      tf = get_field_tf(index, term, doc_id, field)

      if tf > 0 do
        term_docs = Map.get(term_doc_counts, term, 0)

        s =
          Scorer.idf(index.doc_count, term_docs) *
            Scorer.tf_norm(tf, doc_len, avg_len, index.k1, index.b) *
            weight

        {fs + s, [term | fm]}
      else
        {fs, fm}
      end
    end)
  end

  defp get_field_tf(index, term, doc_id, field) do
    index.inverted_index
    |> Map.get(term, %{})
    |> Map.get(doc_id, %{})
    |> Map.get(field, 0)
  end

  defp avg_field_length(%__MODULE__{doc_count: 0}, _field), do: 1.0

  defp avg_field_length(index, field) do
    total = Map.get(index.total_field_lengths, field, 0)
    max(total / index.doc_count, 1.0)
  end
end
