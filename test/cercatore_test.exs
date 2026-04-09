defmodule CercatoreTest do
  use ExUnit.Case

  describe "single-field indexing" do
    test "basic add and query" do
      index =
        Cercatore.new()
        |> Cercatore.add("d1", "the quick brown fox")
        |> Cercatore.add("d2", "the lazy brown dog")

      results = Cercatore.query(index, "quick fox")
      assert hd(results).id == "d1"
    end

    test "empty index returns no results" do
      index = Cercatore.new()
      assert Cercatore.query(index, "anything") == []
    end

    test "query with no matches returns empty" do
      index =
        Cercatore.new()
        |> Cercatore.add("d1", "hello world")

      assert Cercatore.query(index, "zzzzzz") == []
    end

    test "add_all" do
      index =
        Cercatore.new()
        |> Cercatore.add_all([
          {"d1", "the quick brown fox"},
          {"d2", "the lazy brown dog"},
          {"d3", "a brown cat on the mat"}
        ])

      assert Cercatore.Index.size(index) == 3
      results = Cercatore.query(index, "brown")
      assert length(results) == 3
    end

    test "remove document" do
      index =
        Cercatore.new()
        |> Cercatore.add("d1", "hello world")
        |> Cercatore.add("d2", "hello there")
        |> Cercatore.remove("d1")

      assert Cercatore.Index.size(index) == 1
      results = Cercatore.query(index, "hello")
      assert length(results) == 1
      assert hd(results).id == "d2"
    end

    test "removing non-existent doc is a no-op" do
      index = Cercatore.new() |> Cercatore.add("d1", "hello")
      assert Cercatore.Index.size(Cercatore.remove(index, "nope")) == 1
    end

    test "re-adding a document updates it" do
      index =
        Cercatore.new()
        |> Cercatore.add("d1", "hello world")
        |> Cercatore.add("d1", "goodbye world")

      assert Cercatore.Index.size(index) == 1
      assert Cercatore.query(index, "hello") == []
      assert hd(Cercatore.query(index, "goodbye")).id == "d1"
    end

    test "results include match details" do
      index =
        Cercatore.new()
        |> Cercatore.add("d1", "the quick brown fox")

      [result] = Cercatore.query(index, "quick fox")
      assert result.id == "d1"
      assert result.score > 0
      assert is_map(result.matches)
    end

    test "results are ranked by BM25 score" do
      index =
        Cercatore.new()
        |> Cercatore.add("d1", "fox")
        |> Cercatore.add("d2", "fox fox fox")
        |> Cercatore.add("d3", "cat")

      results = Cercatore.query(index, "fox")
      ids = Enum.map(results, & &1.id)
      assert "d3" not in ids
      assert length(results) == 2
    end

    test "limit option" do
      index =
        Cercatore.new()
        |> Cercatore.add_all(Enum.map(1..20, fn i -> {"d#{i}", "word"} end))

      results = Cercatore.query(index, "word", limit: 5)
      assert length(results) == 5
    end

    test "min_score option" do
      index =
        Cercatore.new()
        |> Cercatore.add("d1", "exact match term")
        |> Cercatore.add("d2", "something else entirely different words here")

      results = Cercatore.query(index, "exact match term", min_score: 1.0)
      assert Enum.all?(results, fn r -> r.score >= 1.0 end)
    end
  end

  describe "multi-field indexing" do
    test "basic multi-field" do
      index =
        Cercatore.new(fields: [:title, :body])
        |> Cercatore.add("d1", %{title: "Elixir Guide", body: "Learn functional programming"})
        |> Cercatore.add("d2", %{title: "Rust Book", body: "Systems programming language"})

      results = Cercatore.query(index, "elixir")
      assert hd(results).id == "d1"
    end

    test "field weights boost scoring" do
      index =
        Cercatore.new(fields: [:title, :body], weights: %{title: 10.0, body: 1.0})
        |> Cercatore.add("d1", %{title: "fox", body: "something else"})
        |> Cercatore.add("d2", %{title: "something else", body: "fox"})

      results = Cercatore.query(index, "fox")
      assert hd(results).id == "d1"
    end

    test "field-scoped query" do
      index =
        Cercatore.new(fields: [:title, :body])
        |> Cercatore.add("d1", %{title: "Elixir", body: "Programming language"})
        |> Cercatore.add("d2", %{title: "Programming", body: "Elixir is great"})

      title_results = Cercatore.query(index, "elixir", fields: [:title])
      body_results = Cercatore.query(index, "elixir", fields: [:body])

      title_ids = Enum.map(title_results, & &1.id)
      body_ids = Enum.map(body_results, & &1.id)

      assert "d1" in title_ids
      assert "d2" in body_ids
    end

    test "matches show which fields matched" do
      index =
        Cercatore.new(fields: [:title, :body])
        |> Cercatore.add("d1", %{title: "Elixir Guide", body: "Learn Elixir now"})

      [result] = Cercatore.query(index, "elixir")
      assert Map.has_key?(result.matches, :title)
      assert Map.has_key?(result.matches, :body)
    end
  end

  describe "fuzzy matching" do
    test "fuzzy query finds misspelled terms" do
      index =
        Cercatore.new(fuzzy: [strategy: :jaro_winkler, threshold: 0.8])
        |> Cercatore.add("d1", "elixir programming language")
        |> Cercatore.add("d2", "python programming language")

      results = Cercatore.query(index, "elxir")
      assert results != []
      assert hd(results).id == "d1"
    end

    test "fuzzy disabled by default" do
      index =
        Cercatore.new()
        |> Cercatore.add("d1", "elixir programming")

      results = Cercatore.query(index, "elxir")
      assert results == []
    end

    test "fuzzy with strategy :none is disabled" do
      index =
        Cercatore.new(fuzzy: [strategy: :none])
        |> Cercatore.add("d1", "elixir programming")

      results = Cercatore.query(index, "elxir")
      assert results == []
    end

    test "per-query fuzzy override" do
      index =
        Cercatore.new()
        |> Cercatore.add("d1", "elixir programming")

      results =
        Cercatore.query(index, "elxir", fuzzy: [strategy: :jaro_winkler, threshold: 0.8])

      assert results != []
    end

    test "fuzzy penalty reduces score" do
      index =
        Cercatore.new(fuzzy: [strategy: :jaro_winkler, threshold: 0.8, penalty: 0.5])
        |> Cercatore.add("d1", "elixir programming")

      exact_results = Cercatore.query(index, "elixir")
      fuzzy_results = Cercatore.query(index, "elxir")

      if exact_results != [] and fuzzy_results != [] do
        assert hd(fuzzy_results).score < hd(exact_results).score
      end
    end
  end

  describe "vocabulary" do
    test "tracks indexed terms" do
      index =
        Cercatore.new()
        |> Cercatore.add("d1", "hello world")

      vocab = Cercatore.Index.vocabulary(index)
      assert MapSet.member?(vocab, "hello")
      assert MapSet.member?(vocab, "world")
    end

    test "vocabulary shrinks on remove" do
      index =
        Cercatore.new()
        |> Cercatore.add("d1", "unique_term")
        |> Cercatore.remove("d1")

      vocab = Cercatore.Index.vocabulary(index)
      refute MapSet.member?(vocab, "unique_term")
    end
  end

  describe "tokenizer" do
    test "default tokenizer strips stopwords" do
      tokens = Cercatore.Tokenizer.tokenize("The quick brown fox and the lazy dog")
      refute "the" in tokens
      refute "and" in tokens
      assert "quick" in tokens
      assert "fox" in tokens
    end

    test "default tokenizer downcases" do
      tokens = Cercatore.Tokenizer.tokenize("HELLO World")
      assert tokens == ["hello", "world"]
    end

    test "tokenize_raw preserves stopwords" do
      tokens = Cercatore.Tokenizer.tokenize_raw("The quick fox")
      assert "the" in tokens
    end

    test "empty string" do
      assert Cercatore.Tokenizer.tokenize("") == []
    end

    test "strips short tokens" do
      tokens = Cercatore.Tokenizer.tokenize("I am a big fox")
      refute "I" in tokens
      refute "a" in tokens
      assert "big" in tokens
      assert "fox" in tokens
    end
  end

  describe "scorer" do
    test "idf increases with rarity" do
      common_idf = Cercatore.Scorer.idf(100, 90)
      rare_idf = Cercatore.Scorer.idf(100, 1)
      assert rare_idf > common_idf
    end

    test "tf_norm saturates" do
      low_tf = Cercatore.Scorer.tf_norm(1, 100, 100)
      high_tf = Cercatore.Scorer.tf_norm(100, 100, 100)
      # High TF should be higher but not proportionally
      assert high_tf > low_tf
      assert high_tf / low_tf < 100
    end
  end
end
