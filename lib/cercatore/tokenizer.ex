defmodule Cercatore.Tokenizer do
  @moduledoc """
  Tokenizer behaviour and default implementation.

  The default tokenizer pipeline: Unicode NFC normalize, downcase, split on
  non-alphanumeric boundaries, strip tokens shorter than 2 characters,
  optional stopword removal.

  ## Behaviour

  Implement `c:tokenize/1` to provide a custom tokenizer.

      defmodule MyTokenizer do
        @behaviour Cercatore.Tokenizer

        @impl true
        def tokenize(text) do
          text |> String.downcase() |> String.split()
        end
      end
  """

  @callback tokenize(text :: String.t()) :: [String.t()]

  @english_stopwords MapSet.new(~w(
    a an and are as at be but by for if in into is it no not of on or such
    that the their then there these they this to was will with
  ))

  @doc """
  Tokenizes text using the default pipeline.

  Pipeline: NFC normalize, downcase, split on non-alphanumeric, drop tokens
  shorter than 2 characters, remove English stopwords.

  ## Examples

      iex> Cercatore.Tokenizer.tokenize("The Quick Brown Fox!")
      ["quick", "brown", "fox"]

      iex> Cercatore.Tokenizer.tokenize("hello-world 123")
      ["hello", "world", "123"]

      iex> Cercatore.Tokenizer.tokenize("")
      []
  """
  @spec tokenize(String.t()) :: [String.t()]
  def tokenize(text) do
    text
    |> :unicode.characters_to_nfc_binary()
    |> String.downcase()
    |> String.split(~r/[^[:alnum:]]+/u, trim: true)
    |> Enum.filter(fn token -> String.length(token) >= 2 end)
    |> Enum.reject(fn token -> MapSet.member?(@english_stopwords, token) end)
  end

  @doc """
  Tokenizes text without stopword removal.

  Useful for indexing when you want to preserve all terms.

  ## Examples

      iex> Cercatore.Tokenizer.tokenize_raw("The Quick Fox")
      ["the", "quick", "fox"]
  """
  @spec tokenize_raw(String.t()) :: [String.t()]
  def tokenize_raw(text) do
    text
    |> :unicode.characters_to_nfc_binary()
    |> String.downcase()
    |> String.split(~r/[^[:alnum:]]+/u, trim: true)
    |> Enum.filter(fn token -> String.length(token) >= 2 end)
  end
end
