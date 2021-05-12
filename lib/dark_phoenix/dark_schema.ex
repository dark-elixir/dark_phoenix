defmodule DarkPhoenix.DarkSchema do
  @moduledoc """
  `DarkPhoenix.DarkSchema`.
  """

  alias DarkEcto.Reflections.EctoSchemaReflection

  defstruct assocs: [],
            embeds: [],
            pk_fields: [],
            fk_fields: [],
            assoc_fields: [],
            one_assoc_fields: [],
            many_assoc_fields: [],
            embed_fields: [],
            one_embed_fields: [],
            many_embed_fields: [],
            virtual_fields: [],
            non_virtual_fields: []

  @type acl() :: atom()
  @type prop_schema_opts() :: %{
          optional(:default) => any(),
          optional(:required) => boolean(),
          optional(atom()) => any()
        }
  @type prop_schema_field() ::
          {EctoSchemaReflection.field(), {EctoSchemaReflection.ecto_type(), prop_schema_opts()}}
  @type prop_schema_fields() :: [prop_schema_field()]

  @type fields() :: [EctoSchemaReflection.field()]
  @type embed_fields() :: [EctoSchemaReflection.field()]

  @type t() :: %__MODULE__{
          assocs: [EctoSchemaReflection.assoc()],
          embeds: [EctoSchemaReflection.embed()],
          pk_fields: [prop_schema_field()],
          fk_fields: [prop_schema_field()],
          assoc_fields: [prop_schema_field()],
          one_assoc_fields: [prop_schema_field()],
          many_assoc_fields: [prop_schema_field()],
          embed_fields: [prop_schema_field()],
          one_embed_fields: [prop_schema_field()],
          many_embed_fields: [prop_schema_field()],
          virtual_fields: [prop_schema_field()],
          non_virtual_fields: [prop_schema_field()]
        }

  # @callback ecto_schema_reflection() :: EctoSchemaReflection.t()
  @callback fields() :: [field :: atom()]
  @callback assoc_fields() :: [field :: atom()]
  @callback embed_fields() :: [field :: atom()]
  @callback required_fields() :: [field :: atom()]
  @callback __dark_schema__() :: Keyword.t()
  # @callback primary_key_fields() :: fields()
  # @callback fk_fields() :: fields()
  # @callback virtual_fields() :: fields()
  # @callback non_virtual_fields() :: fields()
  # @callback one_assoc_fields() :: fields()
  # @callback many_assoc_fields() :: fields()

  @doc false
  defmacro __using__(opts \\ []) do
    default_dark_schema_opts = [command: true]
    json_encoder_opts = Keyword.get(opts, :json_encoder, [])

    dark_schema_opts =
      default_dark_schema_opts
      |> Keyword.merge(opts)
      |> Keyword.merge(json_encoder_opts)

    quote location: :keep do
      @behaviour DarkPhoenix.DarkSchema

      use PropSchema
      import Ecto.Changeset

      # @derive {Jason.Encoder, unquote(Macro.escape(json_encoder_opts))}

      @impl DarkPhoenix.DarkSchema
      def __dark_schema__ do
        unquote(Macro.escape(dark_schema_opts))
      end

      @impl DarkPhoenix.DarkSchema
      def fields do
        DarkPhoenix.DarkSchema.fields(__MODULE__, __prop_schema__())
      end

      @impl DarkPhoenix.DarkSchema
      def assoc_fields do
        DarkPhoenix.DarkSchema.assoc_fields(__MODULE__, __prop_schema__())
      end

      @impl DarkPhoenix.DarkSchema
      def embed_fields do
        DarkPhoenix.DarkSchema.embed_fields(__MODULE__, __prop_schema__())
      end

      @impl DarkPhoenix.DarkSchema
      def required_fields do
        DarkPhoenix.DarkSchema.required_fields(__MODULE__, __prop_schema__())
      end

      @doc """
      Builds a changeset based on the `params`.
      """
      def payload_changeset(params \\ %{}, _current_user \\ nil) do
        fields = fields()
        embed_fields = embed_fields()
        assoc_fields = assoc_fields()
        required_fields = required_fields()

        cast_fields = fields -- (embed_fields ++ assoc_fields)
        validate_required_fields = required_fields -- (embed_fields ++ assoc_fields)

        changeset =
          __MODULE__
          |> struct()
          |> DarkEcto.strip_ecto_assoc_not_loaded()
          |> Ecto.Changeset.cast(params, cast_fields)

        changeset =
          for field <- embed_fields, reduce: changeset do
            changeset -> cast_embed(changeset, field, required: field in required_fields)
          end

        changeset =
          for field <- assoc_fields, reduce: changeset do
            changeset -> cast_assoc(changeset, field, required: field in required_fields)
          end

        changeset
        |> Ecto.Changeset.validate_required(validate_required_fields)
      end

      @doc """
      Builds a changeset based on the `params`.
      """
      def validate_payload_ok(payload \\ %{}, current_user \\ nil) do
        case payload_changeset(payload, current_user) do
          %Ecto.Changeset{valid?: true} -> {:ok, payload}
          changeset -> {:error, changeset}
        end
      end
    end
  end

  @doc """
  Definition for reflected `DarkPhoenix.Schema`.
  """
  @spec dark_schema_definition(module(), prop_schema_fields()) :: prop_schema_fields()
  def dark_schema_definition(module, prop_schema_fields)
      when is_atom(module) and is_map(prop_schema_fields) do
    reflection = ecto_schema_reflection(module)
    definition = prop_schema_fields

    %EctoSchemaReflection{
      primary_key_fields: primary_key_fields,
      #  foreign_key_fields: foreign_key_fields,
      assocs: assoc_fields,
      #  one_assoc_fields: one_assoc_fields,
      #  many_assoc_fields: many_assoc_fields,
      embeds: embed_fields,
      #  one_embed_fields: one_embed_fields,
      #  many_embed_fields: many_embed_fields,
      virtual_fields: virtual_fields,
      non_virtual_fields: non_virtual_fields
    } = reflection

    pk_field_keys = Keyword.keys(primary_key_fields)
    #  fk_field_keys = Keyword.keys(foreign_key_fields)
    assoc_field_keys = assoc_fields |> Enum.map(& &1.field)
    #  one_assoc_field_keys =  one_assoc_fields |> Enum.map(& &1.field)
    #  many_assoc_field_keys =  many_assoc_fields |> Enum.map(& &1.field)
    embed_field_keys = embed_fields |> Enum.map(& &1.field)
    #  one_embed_field_keys =  one_embed_fields |> Enum.map(& &1.field)
    #  many_embed_field_keys =  many_embed_fields |> Enum.map(& &1.field)
    virtual_field_keys = virtual_fields
    non_virtual_field_keys = non_virtual_fields

    %__MODULE__{
      pk_fields: definition |> Map.take(pk_field_keys) |> Enum.into([]),
      #  fk_fields: definition |> Map.take(fk_field_keys) |> Enum.into([]),
      assoc_fields: definition |> Map.take(assoc_field_keys) |> Enum.into([]),
      # assoc_fields: assoc_fields |> Enum.map(& &1.field),
      #  one_assoc_fields: definition |> Map.take(one_assoc_field_keys) |> Enum.into([]),
      #  many_assoc_fields: definition |> Map.take(many_assoc_field_keys) |> Enum.into([]),
      embed_fields: definition |> Map.take(embed_field_keys) |> Enum.into([]),
      #  one_embed_fields: definition |> Map.take(one_embed_field_keys) |> Enum.into([]),
      #  many_embed_fields: definition |> Map.take(many_embed_field_keys) |> Enum.into([]),
      virtual_fields: definition |> Map.take(virtual_field_keys) |> Enum.into([]),
      non_virtual_fields: definition |> Map.take(non_virtual_field_keys) |> Enum.into([])
    }
  end

  @doc """
  Derived options from the `PropSchema` definition

  Sorted by field name.
  """
  @spec ecto_schema_reflection(module()) :: EctoSchemaReflection.t()
  def ecto_schema_reflection(module) when is_atom(module) do
    EctoSchemaReflection.describe(module)
  end

  @doc """
  Derived fields from the `PropSchema` definition.

  Sorted by field name.
  """
  @spec fields(module(), prop_schema_fields()) :: [fields :: atom()]
  def fields(module, prop_schema_fields) when is_atom(module) and is_map(prop_schema_fields) do
    reflection = ecto_schema_reflection(module)

    []
    |> Enum.concat(reflection.virtual_fields)
    |> Enum.concat(Keyword.keys(reflection.primary_key_fields))
    |> Enum.concat(Keyword.keys(reflection.non_virtual_fields))
    |> Enum.concat(Enum.map(reflection.assocs, & &1.field))
    |> Enum.concat(Enum.map(reflection.embeds, & &1.field))
    |> Enum.uniq()
    |> Enum.sort()
  end

  @doc """
  Derived assoc fields from the `PropSchema` definition.

  Sorted by field name.
  """
  @spec assoc_fields(module(), prop_schema_fields()) :: [fields :: atom()]
  def assoc_fields(module, prop_schema_fields)
      when is_atom(module) and is_map(prop_schema_fields) do
    reflection = ecto_schema_reflection(module)

    reflection.assocs
    |> Enum.map(& &1.field)
    |> Enum.sort()
  end

  @doc """
  Derived embed fields from the `PropSchema` definition.

  Sorted by field name.
  """
  @spec embed_fields(module(), prop_schema_fields()) :: [fields :: atom()]
  def embed_fields(module, prop_schema_fields)
      when is_atom(module) and is_map(prop_schema_fields) do
    reflection = ecto_schema_reflection(module)

    reflection.embeds
    |> Enum.map(& &1.field)
    |> Enum.sort()
  end

  @doc """
  Derived required fields from the `PropSchema` definition.

  Sorted by field name.
  """
  @spec required_fields(module(), prop_schema_fields()) :: [fields :: atom()]
  def required_fields(module, prop_schema_fields)
      when is_atom(module) and is_map(prop_schema_fields) do
    reflection = ecto_schema_reflection(module)

    for {field, {ecto_type, opts}} <- prop_schema_fields,
        opts[:required] == true,
        field = get_assoc_field({field, {ecto_type, opts}}, reflection),
        uniq: true do
      field
    end
    |> Enum.sort()
  end

  defp get_assoc_field({field, {_ecto_type, opts}}, reflection) do
    if opts[:define_field] == false do
      Enum.find_value(reflection.assocs, nil, fn assoc ->
        if Map.get(assoc, :owner_key) == field do
          assoc.field
        else
          nil
        end
      end)
    else
      field
    end
  end
end
