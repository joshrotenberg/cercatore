defmodule Cercatore.Scorer do
  @moduledoc """
  BM25 scoring math.

  Implements the standard Okapi BM25 ranking function with configurable
  parameters k1 and b.

  ## BM25 Formula

      score(D, Q) = sum(IDF(qi) * tf_norm(qi, D))

  Where:
  - `tf_norm = f(qi,D) * (k1 + 1) / (f(qi,D) + k1 * (1 - b + b * |D| / avgdl))`
  - `IDF(qi) = ln((N - n(qi) + 0.5) / (n(qi) + 0.5) + 1)`
  """

  @doc """
  Computes the BM25 IDF (inverse document frequency) for a term.

  ## Parameters

    * `doc_count` - total number of documents in the corpus
    * `term_doc_count` - number of documents containing the term

  ## Examples

      iex> Cercatore.Scorer.idf(100, 10)
      2.3513752571634776

      iex> Cercatore.Scorer.idf(100, 0)
      5.214936462751692
  """
  @spec idf(non_neg_integer(), non_neg_integer()) :: float()
  def idf(doc_count, term_doc_count) do
    :math.log((doc_count - term_doc_count + 0.5) / (term_doc_count + 0.5) + 1.0)
  end

  @doc """
  Computes the BM25 term frequency normalization.

  ## Parameters

    * `tf` - raw term frequency in the document
    * `doc_length` - length of the document (in tokens)
    * `avg_doc_length` - average document length in the corpus
    * `k1` - term frequency saturation parameter (default 1.2)
    * `b` - length normalization parameter (default 0.75)

  ## Examples

      iex> Cercatore.Scorer.tf_norm(3, 100, 120, 1.2, 0.75)
      0.7746478873239436
  """
  @spec tf_norm(number(), number(), number(), float(), float()) :: float()
  def tf_norm(tf, doc_length, avg_doc_length, k1 \\ 1.2, b \\ 0.75) do
    numerator = tf * (k1 + 1.0)
    denominator = tf + k1 * (1.0 - b + b * doc_length / avg_doc_length)
    numerator / denominator
  end

  @doc """
  Computes the full BM25 score for a document against a set of query terms.

  ## Parameters

    * `query_terms` - list of tokenized query terms
    * `doc_term_freqs` - map of `%{term => frequency}` for the document
    * `doc_length` - number of tokens in the document
    * `avg_doc_length` - average document length across the corpus
    * `doc_count` - total number of documents
    * `term_doc_counts` - map of `%{term => doc_count}` across corpus
    * `k1` - BM25 k1 parameter (default 1.2)
    * `b` - BM25 b parameter (default 0.75)
  """
  @spec score(
          [String.t()],
          %{String.t() => non_neg_integer()},
          non_neg_integer(),
          float(),
          non_neg_integer(),
          %{String.t() => non_neg_integer()},
          float(),
          float()
        ) :: float()
  def score(
        query_terms,
        doc_term_freqs,
        doc_length,
        avg_doc_length,
        doc_count,
        term_doc_counts,
        k1 \\ 1.2,
        b \\ 0.75
      ) do
    Enum.reduce(query_terms, 0.0, fn term, acc ->
      tf = Map.get(doc_term_freqs, term, 0)
      term_docs = Map.get(term_doc_counts, term, 0)

      if tf > 0 do
        acc + idf(doc_count, term_docs) * tf_norm(tf, doc_length, avg_doc_length, k1, b)
      else
        acc
      end
    end)
  end
end
