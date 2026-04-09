defmodule Cercatore.Fuzzy do
  @moduledoc """
  Fuzzy matching for query term expansion using Simile.

  When a query term doesn't match any indexed term exactly, the fuzzy matcher
  finds close matches from the vocabulary and substitutes them with a score
  penalty.

  ## Strategies

    * `:jaro_winkler` - good for short strings, typos (default)
    * `:levenshtein` - edit distance based, normalized to 0-1
    * `:ngram` - bigram overlap
    * `:none` - disable fuzzy matching

  ## Examples

      iex> vocab = MapSet.new(["elixir", "erlang", "elm"])
      iex> Cercatore.Fuzzy.expand("elxir", vocab, strategy: :jaro_winkler, threshold: 0.85)
      [{"elixir", 0.8}]
  """

  @type strategy :: :jaro_winkler | :levenshtein | :ngram | :none
  @type config :: [
          strategy: strategy(),
          threshold: float(),
          penalty: float(),
          max_expansions: pos_integer()
        ]

  @default_config [
    strategy: :jaro_winkler,
    threshold: 0.85,
    penalty: 0.8,
    max_expansions: 3
  ]

  @doc """
  Expands a query term against the vocabulary using fuzzy matching.

  Returns a list of `{term, penalty}` tuples for terms that exceed the
  similarity threshold. The penalty is a multiplier applied to the BM25
  score for fuzzy-matched terms.

  Returns an empty list if the strategy is `:none` or no matches are found.

  ## Options

    * `:strategy` - similarity function to use (default `:jaro_winkler`)
    * `:threshold` - minimum similarity score (default 0.85)
    * `:penalty` - score multiplier for fuzzy matches (default 0.8)
    * `:max_expansions` - max number of fuzzy expansions (default 3)

  ## Examples

      iex> vocab = MapSet.new(["elixir", "erlang"])
      iex> Cercatore.Fuzzy.expand("elxir", vocab, strategy: :jaro_winkler, threshold: 0.8)
      [{"elixir", 0.8}]

      iex> vocab = MapSet.new(["elixir"])
      iex> Cercatore.Fuzzy.expand("elixir", vocab)
      []

      iex> vocab = MapSet.new(["abc"])
      iex> Cercatore.Fuzzy.expand("xyz", vocab)
      []
  """
  @spec expand(String.t(), MapSet.t(), config()) :: [{String.t(), float()}]
  def expand(term, vocabulary, opts \\ []) do
    config = Keyword.merge(@default_config, opts)

    if config[:strategy] == :none do
      []
    else
      score_fn = score_function(config[:strategy])
      penalty = config[:penalty]
      threshold = config[:threshold]
      max = config[:max_expansions]

      candidates =
        vocabulary
        |> Enum.reject(fn vocab_term -> vocab_term == term end)
        |> Enum.to_list()

      Simile.filter(term, candidates, by: score_fn, min_score: threshold)
      |> Enum.take(max)
      |> Enum.map(fn {match, _score} -> {match, penalty} end)
    end
  end

  @doc """
  Resolves query terms against the vocabulary.

  For each query term:
  - If it exists in the vocabulary, keeps it with weight 1.0
  - If not, attempts fuzzy expansion and returns matches with penalty weights

  Returns a list of `{resolved_term, weight}` tuples.

  ## Examples

      iex> vocab = MapSet.new(["quick", "brown", "fox"])
      iex> Cercatore.Fuzzy.resolve_terms(["quick", "fxo"], vocab)
      [{"quick", 1.0}, {"fox", 0.8}]
  """
  @spec resolve_terms([String.t()], MapSet.t(), config()) :: [{String.t(), float()}]
  def resolve_terms(terms, vocabulary, opts \\ []) do
    Enum.flat_map(terms, fn term ->
      if MapSet.member?(vocabulary, term) do
        [{term, 1.0}]
      else
        expand(term, vocabulary, opts)
      end
    end)
  end

  defp score_function(:jaro_winkler), do: &Simile.jaro_winkler/2
  defp score_function(:levenshtein), do: &Simile.indel_similarity/2
  defp score_function(:ngram), do: fn a, b -> 1.0 - Simile.ngram_distance(a, b) end
end
