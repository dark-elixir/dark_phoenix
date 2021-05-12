defmodule DarkPhoenix.Command.Stages.ValidateStage do
  @moduledoc """
  Stage for handling :validate
  """
  @behaviour DarkPhoenix.Command.StageBehaviour

  alias DarkPhoenix.Command
  alias DarkPhoenix.Command.Stage

  @type t() :: %Stage{
          name: Stage.name(),
          type: :validate,
          operation: validate_functor(),
          result: any(),
          opts: opts(),
          valid?: boolean()
        }

  @typedoc """
  Options to be passed to any stage evaluation
  """
  @type opts() :: %{
          optional(:retry_times) => pos_integer(),
          optional(:retry_backoff) => (() -> pos_integer())
        }

  @type validate_result() ::
          {:ok, any()}
          | {:error, any()}
          | :ok
          | :error
          | boolean()
  @type validate_functor() :: Command.functor(validate_result())

  @doc """
  Evaluate a single stage of a command evaluation
  """
  @impl DarkPhoenix.Command.StageBehaviour
  @spec evaluate(Command.t(), t()) :: Stage.stage_result()
  def evaluate(%Command{} = command, %Stage{type: :validate} = stage) do
    case Stage.apply_stage(command, stage) do
      {:ok, result} -> {:ok, result}
      {:error, reason} -> {:error, reason}
      result when result in [:ok, true] -> {:ok, result}
      result when result in [:error, false] -> {:error, result}
      any -> {:error, {:unsupported_validate_result, any}}
    end
  end

  @doc """
  Handle a success `result` based on the `command` and `stage`.
  """
  @impl DarkPhoenix.Command.StageBehaviour
  @spec handle_success(Command.t(), t(), result :: any()) :: Command.t()
  def handle_success(%Command{} = command, %Stage{type: :validate}, _result) do
    command
  end

  @doc """
  Handle an failure `error` based on the `command` and `stage`.
  """
  @impl DarkPhoenix.Command.StageBehaviour
  @spec handle_failure(Command.t(), t(), error :: any()) :: Command.t()
  def handle_failure(%Command{} = command, %Stage{type: :validate, name: name}, error) do
    %{command | valid?: false, failed_operation: name, failed_value: error}
  end
end
