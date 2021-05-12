defmodule DarkPhoenix.Command.Stages.ResolverStage do
  @moduledoc """
  Stage for handling :resolver
  """
  @behaviour DarkPhoenix.Command.StageBehaviour

  alias DarkPhoenix.Command
  alias DarkPhoenix.Command.Stage

  @type t() :: %Stage{
          name: Stage.name(),
          type: :resolver,
          operation: resolver_functor(),
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

  @type resolver_result() ::
          {:ok, any()}
          | {:error, any()}
  @type resolver_functor() :: Command.functor(resolver_result())

  @doc """
  Evaluate a single stage of a command evaluation
  """
  @impl DarkPhoenix.Command.StageBehaviour
  @spec evaluate(Command.t(), t()) :: Stage.stage_result()
  def evaluate(%Command{} = command, %Stage{type: :resolver} = stage) do
    case Stage.apply_stage(command, stage) do
      {:ok, result} -> {:ok, result}
      {:error, reason} -> {:error, reason}
      any -> {:error, {:unsupported_resolver_result, any}}
    end
  end

  @doc """
  Handle a success `result` based on the `command` and `stage`.
  """
  @impl DarkPhoenix.Command.StageBehaviour
  @spec handle_success(Command.t(), t(), result :: any()) :: Command.t()
  def handle_success(%Command{} = command, %Stage{type: :resolver, name: name}, result) do
    %{command | context: Map.put(command.context, name, result)}
  end

  @doc """
  Handle an failure `error` based on the `command` and `stage`.
  """
  @impl DarkPhoenix.Command.StageBehaviour
  @spec handle_failure(Command.t(), t(), error :: any()) :: Command.t()
  def handle_failure(%Command{} = command, %Stage{type: :resolver, name: name}, error) do
    %{command | valid?: false, failed_operation: name, failed_value: error}
  end
end
