defmodule Cercatore.Store.File do
  @moduledoc """
  File-based persistence using `:erlang.term_to_binary`.

  Saves the index struct to a file path. Simple and portable.

  ## Examples

      iex> index = Cercatore.Index.new()
      iex> path = Path.join(System.tmp_dir!(), "cercatore_test_#{System.unique_integer()}")
      iex> :ok = Cercatore.Store.File.save(index, path)
      iex> {:ok, loaded} = Cercatore.Store.File.load(path)
      iex> Cercatore.Index.size(loaded)
      0
      iex> File.rm(path)
      :ok
  """

  @behaviour Cercatore.Store

  @impl true
  @spec save(Cercatore.Index.t(), Path.t()) :: :ok | {:error, term()}
  def save(index, path) do
    binary = :erlang.term_to_binary(index)
    File.write(path, binary)
  end

  @impl true
  @spec load(Path.t()) :: {:ok, Cercatore.Index.t()} | {:error, term()}
  def load(path) do
    case File.read(path) do
      {:ok, binary} ->
        {:ok, :erlang.binary_to_term(binary)}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
