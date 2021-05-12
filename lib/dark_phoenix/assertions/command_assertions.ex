defmodule DarkPhoenix.Assertions.CommandAssertions do
  @moduledoc """
  ExUnit assertions for `DarkPhoenix.DarkCommand` tests.
  """

  import ExUnit.Assertions

  alias DarkEcto.Changesets
  alias DarkPhoenix.DarkCommand
  alias DarkPhoenix.EventSourcing.Shorthand
  alias Ecto.Changeset
  alias Ecto.Multi

  @inspect_opts %Inspect.Opts{
    # binaries: :as_strings,
    # char_lists: :as_char_lists,
    # charlists: :as_charlists,
    pretty: true,
    # limit: :infinity,
    # printable_limit: :infinity,
    width: 80
  }

  defp display(any, %Inspect.Opts{} = inspect_opts \\ @inspect_opts) do
    opts = inspect_opts |> Map.from_struct() |> Enum.into([])
    inspect(any, opts)
  end

  @doc """
  Returns the steps in an `Ecto.Multi`.
  """
  @spec multi_steps(module(), map()) :: [atom()]
  def multi_steps(module, payload \\ %{}) do
    Multi.new()
    |> module.multi(DarkCommand.job(payload))
    |> Multi.to_list()
    |> Keyword.keys()
  end

  @doc """
  Returns if the `result` matches the expected `{:ok, map()}` shape.
  """
  @spec ok?(DarkCommand.result()) :: boolean()
  def ok?(result) do
    match?({:ok, map} when is_map(map), result)
  end

  @doc """
  Returns the `Ecto.Changeset` errors or the `%{failed_operation => failed_value}`.
  """
  @spec command_errors_on(DarkCommand.result()) :: map()
  def command_errors_on({:ok, results}) when is_map(results) do
    %{}
  end

  def command_errors_on({:error, %Changeset{} = changeset}) do
    Changesets.errors_on(changeset)
  end

  def command_errors_on({:error, failed_operation, %Changeset{} = changeset, changes_so_far})
      when is_atom(failed_operation) and is_map(changes_so_far) do
    %{failed_operation => Changesets.errors_on(changeset)}
  end

  def command_errors_on({:error, failed_operation, failed_value, changes_so_far})
      when is_atom(failed_operation) and is_map(changes_so_far) do
    %{failed_operation => failed_value}
  end

  def command_errors_on({:error, failed_value}) when is_map(failed_value) do
    failed_value
  end

  def command_errors_on({:error, failed_value}) do
    %{error: failed_value}
  end

  @doc """
  Returns the steps that have been successfully called so far.
  """
  @spec command_steps_so_far(DarkCommand.result()) :: [atom()]
  def command_steps_so_far({:ok, results}) when is_map(results) do
    Map.keys(results)
  end

  def command_steps_so_far({:ok, _result}) do
    [:all]
  end

  def command_steps_so_far({:error, _result}) do
    [:error_unknown]
  end

  def command_steps_so_far({:error, failed_operation, _failed_value, changes_so_far})
      when is_atom(failed_operation) and is_map(changes_so_far) do
    Map.keys(changes_so_far)
  end

  def command_steps_so_far(_result) do
    [:unknown]
  end

  @doc """
  Returns the steps that have been successfully called so far.
  """
  @spec command_failed_operation(DarkCommand.result()) :: [atom()]
  def command_failed_operation({:ok, results}) when is_map(results) do
    nil
  end

  def command_failed_operation({:ok, _result}) do
    nil
  end

  def command_failed_operation({:error, _result}) do
    :failed_operation_non_resolvable
  end

  def command_failed_operation({:error, failed_operation, _failed_value, changes_so_far})
      when is_atom(failed_operation) and is_map(changes_so_far) do
    failed_operation
  end

  def command_failed_operation(_result) do
    :failed_operation_non_resolvable
  end

  def targets_on(module) do
    dark_event_source = module.__dark_event_source__()

    for shorthand <- dark_event_source.targets, into: %{} do
      expected = %{type: :target}
      {shorthand.name, describe_shorthand(shorthand, expected)}
    end
  end

  def link_to_streams_on(module) do
    dark_event_source = module.__dark_event_source__()

    for shorthand <- dark_event_source.link_to_streams, into: %{} do
      expected = %{type: :link}
      {shorthand.name, describe_shorthand(shorthand, expected)}
    end
  end

  def describe_shorthand(shorthand, expected \\ %{}) do
    include = [:version, :required]
    exclude = [:name, :path, :target_path]
    default_shorthand = struct(Shorthand, expected)

    for {k, v} <- Map.from_struct(shorthand),
        k not in exclude,
        k in include or v != Map.get(default_shorthand, k),
        into: %{resolve_path: shorthand.target_path ++ shorthand.path} do
      {k, v}
    end
  end

  @doc """
  Asserts the result of a command `.perform/2` call was ok.
  """
  @spec assert_ok(DarkCommand.result()) :: DarkCommand.result() | no_return()
  def assert_ok(resp) do
    assert ok?(resp),
      message: """
      Expected:

        `{:ok, results}`

      Failed operation:

        #{display(command_failed_operation(resp))}

      Steps so far:

        #{display(command_steps_so_far(resp))}

      Errors:

        #{display(command_errors_on(resp))}
      """

    resp
  end

  @doc """
  Asserts the result of a command `.perform/2` call errored.
  """
  @spec assert_error(DarkCommand.result()) :: DarkCommand.result() | no_return()
  def assert_error(resp) do
    assert not ok?(resp), """
    Expected:

      `{:error, any()}`
      `{:error, Ecto.Changeset.t()}`
      `{:error, failed_operation :: atom(), failed_value :: any(), changes_so_far :: map()}`
      `{:error, failed_operation :: atom(), failed_value :: Ecto.Changeset.t(), changes_so_far :: map()}`

    Received:

      {:ok, results}

    Results:

      #{display(elem(resp, 1))}
    """

    resp
  end
end
