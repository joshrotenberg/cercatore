defmodule Cercatore.Store do
  @moduledoc """
  Persistence behaviour for Cercatore indexes.

  Implement `c:save/2` and `c:load/1` to provide custom persistence.
  Ships with `Cercatore.Store.File` for binary file storage.

  ## Example

      defmodule MyStore do
        @behaviour Cercatore.Store

        @impl true
        def save(index, ref) do
          # persist the index somewhere
          :ok
        end

        @impl true
        def load(ref) do
          # load and return the index
          {:ok, Cercatore.Index.new()}
        end
      end
  """

  @callback save(index :: Cercatore.Index.t(), ref :: term()) :: :ok | {:error, term()}
  @callback load(ref :: term()) :: {:ok, Cercatore.Index.t()} | {:error, term()}
end
