defmodule DarkPhoenix.EventSourcing.CommandContext do
  @moduledoc """
  `DarkPhoenix.EventSourcing.CommandContext`
  """

  # alias DarkPhoenix.EventSourcing.CommandResults
  # alias DarkPhoenix.EventSourcing.Shorthand

  defstruct [
    :repo,
    :event_store,
    :result,
    ok?: false,
    valid?: false,
    targets: [],
    link_to_streams: [],
    errors: [],
    events: []
  ]
end
