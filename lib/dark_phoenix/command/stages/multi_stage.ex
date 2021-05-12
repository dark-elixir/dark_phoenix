defmodule DarkPhoenix.Command.Stages.MultiStage do
  @moduledoc """
  Stage for handling :multi
  """
  @behaviour DarkPhoenix.Command.StageBehaviour

  alias DarkPhoenix.Command
  alias DarkPhoenix.Command.Stage

  @type t() :: %Stage{
          name: Stage.name(),
          type: :multi,
          operation: multi_functor(),
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

  @type multi_result() ::
          Ecto.Multi.t()
          | {:ok, Ecto.Multi.t()}
          | {:error, any()}

  @type multi_functor() :: Command.functor(multi_result())

  @doc """
  Evaluate a single stage of a command evaluation
  """
  @impl DarkPhoenix.Command.StageBehaviour
  @spec evaluate(Command.t(), t()) :: Stage.stage_result()
  def evaluate(%Command{} = command, %Stage{type: :multi} = stage) do
    case Stage.apply_stage(command, stage) do
      %Ecto.Multi{} = multi -> evaluate_multi_transaction(command, multi)
      {:ok, %Ecto.Multi{} = multi} -> evaluate_multi_transaction(command, multi)
      {:error, reason} -> {:error, reason}
      any -> {:error, {:unsupported_multi_result, any}}
    end
  end

  @doc """
  Handle a success `result` based on the `command` and `stage`.
  """
  @impl DarkPhoenix.Command.StageBehaviour
  @spec handle_success(Command.t(), t(), result :: any()) :: Command.t()
  def handle_success(%Command{} = command, %Stage{type: :multi, name: name}, result)
      when is_atom(name) do
    %{command | changes_so_far: Map.put(command.changes_so_far, name, result)}
  end

  @doc """
  Handle an failure `error` based on the `command` and `stage`.
  """
  @impl DarkPhoenix.Command.StageBehaviour
  @spec handle_failure(Command.t(), t(), error :: any()) :: Command.t()
  def handle_failure(%Command{} = command, %Stage{type: :multi, name: name}, error)
      when is_atom(name) do
    %{command | valid?: false, failed_operation: name, failed_value: error}
  end

  defp evaluate_multi_transaction(%Command{repo: repo}, %Ecto.Multi{} = multi) do
    case Kernel.apply(repo, :transaction, [multi]) do
      {:ok, result} ->
        {:ok, result}

      {:error, error} ->
        {:error, error}

      {:error, multi_stage, failed_value, changes_so_far} ->
        {:error, {multi_stage, failed_value, changes_so_far}}
    end
  end
end
