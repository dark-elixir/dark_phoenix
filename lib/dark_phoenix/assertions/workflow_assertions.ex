defmodule DarkPhoenix.Assertions.WorkflowAssertions do
  @moduledoc """
  ExUnit assertions for `DarkPhoenix.DarkWorkflow` tests.
  """

  import ExUnit.Assertions

  alias DarkPhoenix.Assertions.CommandAssertions
  alias DarkPhoenix.DarkWorkflow

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
  Returns the `Ecto.Changeset` errors or the `%{failed_operation => failed_value}`.
  """
  @spec workflow_errors_on(DarkWorkflow.result()) :: map()
  def workflow_errors_on({:ok, results}) when is_map(results) do
    %{}
  end

  def workflow_errors_on(
        {:error,
         %Opus.PipelineError{
           error: %{
             failed_operation: failed_operation,
             failed_value: failed_value,
             changes_so_far: changes_so_far
           }
         }}
      ) do
    CommandAssertions.command_errors_on({:error, failed_operation, failed_value, changes_so_far})
  end

  def workflow_errors_on({:error, %Opus.PipelineError{error: error}}) do
    CommandAssertions.command_errors_on({:error, error})
  end

  @doc """
  Returns the steps that have been successfully called so far.
  """
  @spec workflow_steps_so_far(DarkWorkflow.result()) :: [atom()]
  def workflow_steps_so_far({:ok, results}) when is_map(results) do
    Map.keys(results)
  end

  def workflow_steps_so_far({:ok, _result}) do
    [:all]
  end

  def workflow_steps_so_far({:error, _result}) do
    [:error_unknown]
  end

  def workflow_steps_so_far({:error, failed_operation, _failed_value, changes_so_far})
      when is_atom(failed_operation) and is_map(changes_so_far) do
    Map.keys(changes_so_far)
  end

  def workflow_steps_so_far(_result) do
    [:unknown]
  end

  @doc """
  Returns the steps that have been successfully called so far.
  """
  @spec workflow_failed_operation(DarkWorkflow.result()) :: [atom()]
  def workflow_failed_operation({:ok, results}) when is_map(results) do
    nil
  end

  def workflow_failed_operation({:ok, _result}) do
    nil
  end

  def workflow_failed_operation({:error, _result}) do
    :failed_operation_non_resolvable
  end

  def workflow_failed_operation({:error, failed_operation, _failed_value, changes_so_far})
      when is_atom(failed_operation) and is_map(changes_so_far) do
    failed_operation
  end

  def workflow_failed_operation(_result) do
    :failed_operation_non_resolvable
  end

  @doc """
  Asserts the result of a workflow `.perform/2` call was ok.
  """
  @spec assert_workflow_ok(DarkWorkflow.result()) :: DarkWorkflow.result() | no_return()
  def assert_workflow_ok(resp) do
    assert CommandAssertions.ok?(resp),
      message: """
      Expected:

        `{:ok, results}`

      Failed operation:

        #{display(workflow_failed_operation(resp))}

      Steps so far:

        #{display(workflow_steps_so_far(resp))}

      Errors:

        #{display(workflow_errors_on(resp))}
      """

    resp
  end

  @doc """
  Asserts the result of a workflow `.perform/2` call errored.
  """
  @spec assert_workflow_error(DarkWorkflow.result()) :: DarkWorkflow.result() | no_return()
  def assert_workflow_error(resp) do
    assert not CommandAssertions.ok?(resp), """
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
