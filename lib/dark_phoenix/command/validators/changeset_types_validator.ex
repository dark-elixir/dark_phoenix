defmodule DarkPhoenix.Command.Validators.ChangesetTypesValidator do
  @moduledoc """
  Utils for validating params via a changeset.
  """

  @type validate_types() :: %{required(atom()) => validate_type()}
  @type validate_type() :: atom() | String.t() | {atom() | String.t(), validate_type_opts()}
  @type validate_type_opts() :: %{optional(:required) => boolean()}

  def changeset_from_types(context, types) do
    {ecto_types, required} = cast_ecto_types(types)

    {%{}, ecto_types, required}
    |> build_validate_types_changeset(context)
  end

  def validate_from_types(context, types) do
    context
    |> changeset_from_types(types)
    |> wrap_changeset()
  end

  def build_validate_by_types(types) when is_map(types) do
    # fn context, changes_so_far, %Command{} = command ->
    fn context ->
      validate_from_types(context, types)
    end
  end

  defp cast_ecto_types(types) do
    required = []
    {types, required}
  end

  defp build_validate_types_changeset({data, types, required}, params) do
    {data, types}
    |> Ecto.Changeset.cast(params, Map.keys(types))
    |> Ecto.Changeset.validate_required(required)
  end

  defp wrap_changeset(changeset) do
    case errors_on(changeset) do
      errors when errors == %{} -> :ok
      errors -> {:error, errors}
    end
  end

  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
