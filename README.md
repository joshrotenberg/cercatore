# Cercatore

[![CI](https://github.com/joshrotenberg/cercatore/actions/workflows/ci.yml/badge.svg)](https://github.com/joshrotenberg/cercatore/actions/workflows/ci.yml)
[![Hex.pm](https://img.shields.io/hexpm/v/cercatore.svg)](https://hex.pm/packages/cercatore)
[![Hex Docs](https://img.shields.io/badge/hex-docs-blue.svg)](https://hexdocs.pm/cercatore)
[![License](https://img.shields.io/hexpm/l/cercatore.svg)](https://github.com/joshrotenberg/cercatore/blob/main/LICENSE)

BM25 full-text search for Elixir with optional fuzzy matching via
[simile](https://hex.pm/packages/simile).

## Usage

### Basic indexing and search

```elixir
index =
  Cercatore.new()
  |> Cercatore.add("doc1", "The quick brown fox jumps over the lazy dog")
  |> Cercatore.add("doc2", "A brown cat sleeps on the mat")

Cercatore.query(index, "quick fox")
#=> [%Cercatore.Result{id: "doc1", score: ..., matches: %{content: ["quick", "fox"]}}]
```

### Multi-field with weights

```elixir
index =
  Cercatore.new(fields: [:title, :body], weights: %{title: 2.0, body: 1.0})
  |> Cercatore.add("doc1", %{title: "Elixir Guide", body: "Learn Elixir programming"})
  |> Cercatore.add("doc2", %{title: "Rust Book", body: "Systems programming"})

Cercatore.query(index, "elixir")
# title matches score higher due to weight
```

### Fuzzy matching

```elixir
index =
  Cercatore.new(fuzzy: [strategy: :jaro_winkler, threshold: 0.85])
  |> Cercatore.add("doc1", "elixir programming")

Cercatore.query(index, "elxir")
# finds "doc1" via fuzzy expansion
```

Fuzzy strategies: `:jaro_winkler`, `:levenshtein`, `:ngram`, `:none`.

### Query options

```elixir
Cercatore.query(index, "search terms",
  limit: 5,
  min_score: 0.5,
  fields: [:title],
  fuzzy: [strategy: :jaro_winkler, threshold: 0.8]
)
```

### GenServer wrapper

```elixir
{:ok, _} = Cercatore.Server.start_link(name: :products, fields: [:name, :description])
Cercatore.Server.add(:products, "sku-1", %{name: "Widget", description: "A fine widget"})
Cercatore.Server.query(:products, "widget")
```

### Persistence

```elixir
{:ok, _} = Cercatore.Server.start_link(
  name: :products,
  store: Cercatore.Store.File,
  store_ref: "/tmp/products.idx"
)

# saves index to disk
Cercatore.Server.flush(:products)
```

Implement `Cercatore.Store` behaviour for custom persistence backends.

### Custom tokenizer

```elixir
defmodule MyTokenizer do
  @behaviour Cercatore.Tokenizer

  @impl true
  def tokenize(text) do
    text |> String.downcase() |> String.split()
  end
end

Cercatore.new(tokenizer: MyTokenizer)
```

## Installation

```elixir
def deps do
  [
    {:cercatore, "~> 0.1.0"}
  ]
end
```

Documentation: [hexdocs.pm/cercatore](https://hexdocs.pm/cercatore)

## License

MIT
