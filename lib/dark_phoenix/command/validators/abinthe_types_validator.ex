if Code.ensure_loaded?(Absinthe) do
  defmodule DarkPhoenix.Command.Validators.AbsintheTypesValidator do
    @moduledoc """
    Utils for validating params via a changeset.
    """

    def absinthe_fields_for(module, field) when is_atom(module) and is_atom(field) do
      module.__absinthe_types__(:all)
    end

    def absinthe_field(module, field) when is_atom(module) and is_atom(field) do
      module.__absinthe_type__(field)
    end
  end
end
