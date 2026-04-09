defmodule CercatorePropertyTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  defp short_text do
    StreamData.string(:alphanumeric, min_length: 3, max_length: 30)
  end

  defp doc_list do
    StreamData.list_of(
      StreamData.tuple({
        StreamData.string(:alphanumeric, length: 8),
        short_text()
      }),
      min_length: 1,
      max_length: 10
    )
    |> StreamData.map(fn docs ->
      # Ensure unique IDs
      docs
      |> Enum.uniq_by(&elem(&1, 0))
    end)
  end

  describe "index properties" do
    property "size equals number of unique docs added" do
      check all(docs <- doc_list()) do
        index = Cercatore.Index.add_all(Cercatore.new(), docs)
        assert Cercatore.Index.size(index) == length(docs)
      end
    end

    property "remove always decrements size (or no-op)" do
      check all(docs <- doc_list()) do
        index = Cercatore.Index.add_all(Cercatore.new(), docs)
        {id, _} = hd(docs)
        removed = Cercatore.remove(index, id)
        assert Cercatore.Index.size(removed) == Cercatore.Index.size(index) - 1
      end
    end

    property "removing non-existent doc preserves size" do
      check all(docs <- doc_list()) do
        index = Cercatore.Index.add_all(Cercatore.new(), docs)

        assert Cercatore.Index.size(Cercatore.remove(index, "nonexistent")) ==
                 Cercatore.Index.size(index)
      end
    end

    property "query scores are non-negative" do
      check all(
              docs <- doc_list(),
              query <- short_text()
            ) do
        index = Cercatore.Index.add_all(Cercatore.new(), docs)
        results = Cercatore.query(index, query)
        assert Enum.all?(results, fn r -> r.score >= 0.0 end)
      end
    end

    property "query results are sorted by score descending" do
      check all(
              docs <- doc_list(),
              query <- short_text()
            ) do
        index = Cercatore.Index.add_all(Cercatore.new(), docs)
        results = Cercatore.query(index, query)
        scores = Enum.map(results, & &1.score)
        assert scores == Enum.sort(scores, :desc)
      end
    end

    property "query results have unique IDs" do
      check all(
              docs <- doc_list(),
              query <- short_text()
            ) do
        index = Cercatore.Index.add_all(Cercatore.new(), docs)
        results = Cercatore.query(index, query)
        ids = Enum.map(results, & &1.id)
        assert ids == Enum.uniq(ids)
      end
    end

    property "re-adding a document keeps size at 1" do
      check all(
              text1 <- short_text(),
              text2 <- short_text()
            ) do
        index =
          Cercatore.new()
          |> Cercatore.add("same_id", text1)
          |> Cercatore.add("same_id", text2)

        assert Cercatore.Index.size(index) == 1
      end
    end

    property "limit option is respected" do
      check all(
              docs <- doc_list(),
              query <- short_text(),
              limit <- StreamData.integer(1..5)
            ) do
        index = Cercatore.Index.add_all(Cercatore.new(), docs)
        results = Cercatore.query(index, query, limit: limit)
        assert length(results) <= limit
      end
    end
  end

  describe "tokenizer properties" do
    property "tokenize returns a list of strings" do
      check all(text <- short_text()) do
        tokens = Cercatore.Tokenizer.tokenize(text)
        assert is_list(tokens)
        assert Enum.all?(tokens, &is_binary/1)
      end
    end

    property "all tokens are lowercase" do
      check all(text <- short_text()) do
        tokens = Cercatore.Tokenizer.tokenize(text)
        assert Enum.all?(tokens, fn t -> t == String.downcase(t) end)
      end
    end

    property "all tokens have length >= 2" do
      check all(text <- short_text()) do
        tokens = Cercatore.Tokenizer.tokenize(text)
        assert Enum.all?(tokens, fn t -> String.length(t) >= 2 end)
      end
    end
  end
end
