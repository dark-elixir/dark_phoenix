defmodule DarkPhoenix.DarkEventSource do
  @moduledoc """
  `DarkPhoenix.DarkEventSource`
  """

  alias DarkPhoenix.EventSourcing.CommandContext
  alias DarkPhoenix.EventSourcing.CommandResults
  alias DarkPhoenix.EventSourcing.Shorthand

  @type macro_opt() ::
          {:repo, module()}
          | {:event_store, module()}
          | {:targets, [Shorthand.shorthand()]}
          | {:link_to_streams, [Shorthand.shorthand()]}

  @type dark_event_source_opt() ::
          {:repo, module()}
          | {:event_store, module()}
          | {:targets, [Keyword.t(Shorthand.t())]}
          | {:link_to_streams, [Keyword.t(Shorthand.t())]}

  @type event() :: EventStore.EventData.t()

  @type stream_uuid() :: String.t()

  @callback __dark_event_source__() :: [dark_event_source_opt(), ...]
  @callback read_stream_forward(stream_uuid()) :: :ok
  @callback append_to_stream(stream_uuid(), Shorthand.version(), [event(), ...]) :: :ok
  @callback link_to_stream(stream_uuid(), Shorthand.version(), [event(), ...]) :: :ok
  @callback command_to_event_structs(struct()) :: [event(), ...]

  @doc false
  @spec __using__([macro_opt()]) :: any()
  defmacro __using__(opts \\ []) do
    # # enqueuer = Application.fetch_env!(:dark_phoenix, :enqueuer)
    repo = Application.fetch_env!(:dark_phoenix, :repo)
    event_store = Application.fetch_env!(:dark_phoenix, :event_store)
    %{targets: targets, link_to_streams: link_to_streams} = Shorthand.parse_opts(opts)

    quote location: :keep do
      @behaviour DarkPhoenix.DarkEventSource

      @impl DarkPhoenix.DarkEventSource
      def __dark_event_source__ do
        %DarkPhoenix.EventSourcing.CommandContext{
          repo: unquote(repo),
          event_store: unquote(event_store),
          targets: unquote(Macro.escape(targets)),
          link_to_streams: unquote(Macro.escape(link_to_streams))
        }
      end

      @impl DarkPhoenix.DarkEventSource
      def read_stream_forward(stream_uuid) when is_binary(stream_uuid) do
        unquote(event_store).read_stream_forward(stream_uuid)
      end

      @impl DarkPhoenix.DarkEventSource
      def append_to_stream(stream_uuid, version, events)
          when is_binary(stream_uuid) and is_list(events) do
        unquote(event_store).append_to_stream(stream_uuid, version, events)
      end

      @impl DarkPhoenix.DarkEventSource
      def link_to_stream(stream_uuid, version, events)
          when is_binary(stream_uuid) and is_list(events) do
        unquote(event_store).link_to_stream(stream_uuid, version, events)
      end

      @impl DarkPhoenix.DarkEventSource
      def command_to_event_structs(command) when is_map(command) do
        CommandResults.cast_command_result_to_events(command)
      end

      def append_event_sourcing(%Ecto.Multi{} = multi) do
        multi
        |> Ecto.Multi.run(:event_sourcing, fn _repo, changes_so_far ->
          handle_event_source_result({:ok, changes_so_far})
        end)
      end

      def handle_event_source_result({:ok, result}) when is_map(result) do
        alias DarkPhoenix.EventSourcing.CommandContext
        alias DarkPhoenix.EventSourcing.CommandResults

        context = __dark_event_source__()

        case CommandResults.cast(context, {:ok, result}) do
          %CommandContext{
            ok?: true,
            events: [_ | _] = events,
            targets: [%Shorthand{valid?: true, stream_uuid: stream_uuid, version: version}],
            link_to_streams: link_to_streams
          } = command_context ->
            :ok = append_to_stream(stream_uuid, version, events)

            valid_link_to_streams =
              for %{valid?: true} = shorthand <- link_to_streams do
                shorthand
              end

            link_to_streams_results =
              if valid_link_to_streams == [] do
                []
              else
                {:ok, recorded_source_events} = read_stream_forward(stream_uuid)

                for %{valid?: true, stream_uuid: stream_uuid, version: version} <-
                      link_to_streams do
                  link_to_stream(stream_uuid, version, recorded_source_events)
                end
              end

            event_source_result = %{
              targets: [:ok],
              link_to_streams: link_to_streams_results
            }

            # {:ok,
            #  Map.merge(result, %{
            #    event_source_result: event_source_result,
            #    command_context: command_context
            #  })}

            {:ok,
             %{
               event_source_result: event_source_result,
               command_context: command_context
             }}

          command_context ->
            # IO.inspect(command_results.targets)
            # IO.inspect(command_results.link_to_streams)
            {:error, command_context}
        end
      end
    end
  end
end
