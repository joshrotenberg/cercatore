defmodule Cercatore.Result do
  @moduledoc """
  A search result with document ID, BM25 score, and match details.

  ## Examples

      iex> %Cercatore.Result{id: "doc1", score: 1.5, matches: %{title: ["fox"]}}
      %Cercatore.Result{id: "doc1", score: 1.5, matches: %{title: ["fox"]}}
  """

  @type t :: %__MODULE__{
          id: term(),
          score: float(),
          matches: %{atom() => [String.t()]}
        }

  defstruct [:id, score: 0.0, matches: %{}]
end
