defmodule DarkPhoenix.EventSourcing.CommandResults do
  @moduledoc """
  `DarkPhoenix.EventSourcing.CommandResults`
  """

  alias DarkPhoenix.EventSourcing.CommandContext
  alias DarkPhoenix.EventSourcing.Shorthand

  def cast(%CommandContext{} = init_context, result) do
    events = cast_command_result_to_events(result)
    context = hydrate(init_context, result)

    validate_context(context, events)
  end

  def cast_command_result_to_events({:ok, %{command: %{__struct__: module} = command}}) do
    opts = module.__dark_schema__()
    json_encoder = Keyword.get(opts, :json_encoder, [])
    except = Keyword.get(json_encoder, :except, [])

    data = command |> Map.drop(except)

    [
      %EventStore.EventData{
        # event_type: to_string(_module)
        event_type: nil,
        # metadata: %{user: "someuser@example.com"},
        data: data
      }
    ]
  end

  def cast_command_result_to_events(_) do
    []
  end

  def validate_target(shorthand) do
    cond do
      Shorthand.valid?(shorthand) ->
        %{shorthand | valid?: true}

      Shorthand.required?(shorthand) ->
        put_error(shorthand, {:required, [shorthand.name]})

      true ->
        shorthand
    end
  end

  def validate_link_stream(shorthand, targets) do
    valid_targets = Enum.filter(targets, &Shorthand.valid?/1)

    cond do
      targets == [] ->
        put_error(shorthand, {:target_not_present, []})

      valid_targets == [] ->
        [target] = targets
        put_error(shorthand, {:target_invalid, [target.name]})

      Shorthand.valid?(shorthand) ->
        %{shorthand | valid?: true}

      Shorthand.required?(shorthand) ->
        put_error(shorthand, {:required, [shorthand.name]})

      true ->
        shorthand
    end
  end

  def validate_context(
        %CommandContext{targets: targets, link_to_streams: link_to_streams} = context,
        events
      ) do
    %{
      context
      | events: events,
        targets: Enum.map(targets, &validate_target(&1)),
        link_to_streams: Enum.map(link_to_streams, &validate_link_stream(&1, targets))
    }
  end

  def hydrate_list(context, result, list) do
    for shorthand <- list do
      do_hydrate(context, shorthand, result, shorthand.target_path ++ shorthand.path)
    end
  end

  def hydrate(%CommandContext{targets: []} = context, {:ok, result}) when is_map(result) do
    %{context | ok?: true}
  end

  def hydrate(
        %CommandContext{targets: [%Shorthand{} = target], link_to_streams: link_to_streams} =
          context,
        {:ok, result}
      )
      when is_list(link_to_streams) and is_map(result) do
    context = %{context | ok?: true}

    hydrated_targets = hydrate_list(context, result, [target])
    hydrated_link_to_streams = hydrate_list(context, result, link_to_streams)
    %{context | targets: hydrated_targets, link_to_streams: hydrated_link_to_streams}
  end

  def hydrate(
        %CommandContext{targets: targets, link_to_streams: link_to_streams} = context,
        _error_result
      ) do
    hydrated_targets = Enum.map(targets, &put_error(&1, :command_failed))
    hydrated_link_to_streams = Enum.map(link_to_streams, &put_error(&1, :command_failed))
    %{context | ok?: false, targets: hydrated_targets, link_to_streams: hydrated_link_to_streams}
  end

  def do_hydrate(%CommandContext{}, %Shorthand{} = shorthand, %{stream_uuid: stream_uuid}, [])
      when is_binary(stream_uuid) do
    put_stream_uuid(shorthand, stream_uuid)
  end

  def do_hydrate(%CommandContext{}, %Shorthand{} = shorthand, %{stream_uuid: nil}, []) do
    put_error(shorthand, {:assoc_stream_uuid_nil, shorthand.path})
  end

  def do_hydrate(%CommandContext{}, %Shorthand{} = shorthand, current, [])
      when is_map(current) do
    put_error(shorthand, {:assoc_no_stream_uuid, shorthand.path})
  end

  def do_hydrate(
        %CommandContext{repo: repo} = context,
        %Shorthand{} = shorthand,
        current,
        [key | rest]
      )
      when is_map(current) and is_atom(key) do
    case Map.get(current, key) do
      %Ecto.Association.NotLoaded{} ->
        if shorthand.preload do
          do_hydrate(context, shorthand, repo.preload(current, [key | rest]), [key | rest])
        else
          put_error(shorthand, {:assoc_not_loaded, shorthand.path -- rest})
        end

      list when is_list(list) ->
        for next <- list, reduce: context do
          context -> do_hydrate(context, shorthand, next, rest)
        end

      next when is_map(next) ->
        do_hydrate(context, shorthand, next, rest)

      nil ->
        put_error(shorthand, {:assoc_nil, shorthand.path -- rest})
    end
  end

  def do_hydrate(%CommandContext{}, %Shorthand{} = shorthand, _current, path) do
    %{shorthand | valid?: false, failed_path: shorthand.path -- path}
  end

  def put_stream_uuid(%Shorthand{} = shorthand, stream_uuid) when is_binary(stream_uuid) do
    %{shorthand | valid?: true, stream_uuid: stream_uuid}
  end

  def put_error(%Shorthand{errors: errors} = shorthand, error) do
    %{shorthand | valid?: false, errors: errors ++ [error]}
  end
end
