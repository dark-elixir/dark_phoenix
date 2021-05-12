defmodule DarkPhoenix.EventSourcing.Shorthand do
  @moduledoc """
  `DarkPhoenix.EventSourcing.Shorthand`
  """

  defstruct [
    :name,
    :type,
    :stream_uuid,
    version: :any_version,
    valid?: false,
    required: false,
    path: [],
    target_path: [],
    preload: false,
    preloads: [],
    errors: []
  ]

  @type t() :: %__MODULE__{
          name: atom(),
          type: :link_to_stream | :target,
          stream_uuid: String.t() | nil,
          version: version(),
          valid?: boolean(),
          required: boolean(),
          path: [atom(), ...],
          target_path: [atom(), ...],
          preload: boolean(),
          preloads: [atom()],
          errors: [error()]
        }

  @type error() ::
          {:command_failed, []}
          | {:target_not_present, []}
          | {:target_invalid, [name :: atom()]}
          | {:required, [name :: atom()]}
          | {:assoc_nil, [atom()]}
          | {:assoc_not_loaded, [atom()]}
          | {:assoc_no_stream_uuid, [atom()]}
          | {:assoc_stream_uuid_nil, [atom()]}

  @type version() :: :any_version | :no_stream | :stream_exists | non_neg_integer()

  @type shorthand() :: {name :: atom(), {version(), :optional | :required}}

  @type opt() ::
          {:event_store, module()}
          | {:targets, [shorthand()]}
          | {:link_to_streams, [shorthand()]}

  @versions [:any_version, :no_stream, :stream_exists]

  @defaults [
    target: [type: :target, version: :no_stream, required: true, preload: true],
    link_to_stream: [type: :link, version: :stream_exists]
  ]

  @types Keyword.keys(@defaults)

  def stream_uuid?(%__MODULE__{stream_uuid: nil}), do: false
  def stream_uuid?(%__MODULE__{stream_uuid: stream_uuid}) when is_binary(stream_uuid), do: true
  def valid?(%__MODULE__{valid?: false}), do: false
  def valid?(%__MODULE__{valid?: true} = shorthand), do: stream_uuid?(shorthand)
  def required?(%__MODULE__{required: false}), do: false
  def required?(%__MODULE__{required: true}), do: true
  def error?(%__MODULE__{} = shorthand), do: not valid?(shorthand) and required?(shorthand)

  def new(params \\ %{}) when is_map(params) do
    struct(__MODULE__, params)
  end

  def expand(item, type, defaults \\ []) when type in @types do
    []
    |> Keyword.merge(@defaults[type])
    |> Keyword.merge(defaults)
    |> Keyword.merge(do_expand(item))
    |> Enum.into(%{})
  end

  def parse_opts(opts) when is_list(opts) do
    target_opts = Keyword.get(opts, :targets, [])
    link_to_streams_opts = Keyword.get(opts, :link_to_streams, [])

    targets =
      List.wrap(target_opts)
      |> Enum.map(&expand(&1, :target, []))
      |> Enum.filter(& &1[:name])
      |> Enum.map(&Map.put(&1, :path, [&1[:name]]))

    if length(targets) > 1 do
      raise ArgumentError, """
      [DarkPhoenix.EventSourcing.Shorthand]

      Cannot have more than one :target

      ## Given:

      #{inspect(target_opts)}

      ## Expanded:

          #{inspect(targets)}
      """
    end

    target_path =
      case targets do
        [] -> []
        [%{name: name}] -> [name]
      end

    link_to_streams =
      link_to_streams_opts
      |> Enum.map(&expand(&1, :link_to_stream, target_path: target_path))
      |> Enum.filter(& &1[:name])
      |> Enum.map(&Map.put(&1, :path, [&1[:name]]))

    %{
      targets:
        targets
        |> Enum.map(&new/1)
        |> Enum.map(fn struct ->
          if struct.preloads == [] and struct.preload do
            preloads = Enum.map(link_to_streams, & &1.name)
            %{struct | preloads: preloads}
          else
            struct
          end
        end),
      link_to_streams: link_to_streams |> Enum.map(&new/1)
    }
  end

  defp do_expand([]) do
    []
  end

  defp do_expand(name) when is_atom(name) do
    [{:name, name} | walk([])]
  end

  defp do_expand([{name, {version, opts}}])
       when is_atom(name) and version in @versions and is_list(opts) do
    [{:name, name}, {:version, version} | walk(opts)]
  end

  defp do_expand([{name, {k, v}}]) when is_atom(name) and is_atom(k) do
    [{:name, name}, {k, v}]
  end

  defp do_expand([name | opts]) when is_atom(name) do
    [{:name, name} | walk(opts)]
  end

  defp do_expand({name, {version, opts}})
       when is_atom(name) and version in @versions and is_list(opts) do
    [{:name, name}, {:version, version} | walk(opts)]
  end

  defp do_expand({name, {k, v}}) when is_atom(name) and is_atom(k) do
    [{:name, name}, {k, v}]
  end

  defp do_expand({name, opt}) when is_atom(name) and is_atom(opt) do
    [{:name, name} | walk([opt])]
  end

  defp do_expand({name, opts}) when is_atom(name) and is_list(opts) do
    [{:name, name} | walk(opts)]
  end

  defp walk([version | opts]) when version in @versions do
    [{:version, version} | opts]
  end

  defp walk(opts) when is_list(opts) do
    opts
  end
end
