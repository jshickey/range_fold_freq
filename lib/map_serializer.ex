defmodule MapSerializer do
  @doc """
  Serializes a list of maps to a binary file.

  ## Parameters
    - maps: List of maps to serialize
    - file_path: String path to the output file

  ## Returns
    - :ok on success
    - {:error, reason} on failure
  """
  def write_maps(maps, file_path) when is_list(maps) and is_binary(file_path) do
    try do
      binary = :erlang.term_to_binary(maps)
      File.write(file_path, binary)
      maps
    rescue
      e -> {:error, e}
    end
  end

  @doc """
  Reads a serialized list of maps from a file.

  ## Parameters
    - file_path: String path to the input file

  ## Returns
    - {:ok, maps} on success, where maps is the list of maps
    - {:error, reason} on failure
  """
  def read_maps(file_path) when is_binary(file_path) do
    try do
      case File.read(file_path) do
        {:ok, binary} ->
          maps = :erlang.binary_to_term(binary)
          if is_list(maps), do: {:ok, maps}, else: {:error, :invalid_data}

        error ->
          error
      end
    rescue
      e -> {:error, e}
    end
  end
end

# Example usage:
# maps = [%{id: 1, name: "Alice"}, %{id: 2, name: "Bob"}]
# MapSerializer.write_maps(maps, "maps.bin")
# {:ok, deserialized_maps} = MapSerializer.read_maps("maps.bin")
