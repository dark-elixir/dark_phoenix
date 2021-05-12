defmodule DarkPhoenix.Command.Stage do
  @moduledoc """
  Stage
  """

  alias DarkPhoenix.Command
  alias DarkPhoenix.Command.Stages.MultiStage
  alias DarkPhoenix.Command.Stages.ResolverStage
  alias DarkPhoenix.Command.Stages.ValidateStage

  @type_callees %{
    multi: MultiStage,
    resolver: ResolverStage,
    validate: ValidateStage
  }
  @types Map.keys(@type_callees)

  defstruct [
    :name,
    :type,
    :operation,
    :result,
    opts: %{},
    valid?: true
  ]

  @type t() :: %__MODULE__{
          name: name(),
          type: type(),
          operation: Command.functor(),
          result: any(),
          opts: %{required(atom) => any()},
          valid?: boolean()
        }
  @type name() :: atom()
  @type type() :: :multi | :resolver | :validate

  @typedoc """
  Options to be passed to any stage evaluation
  """
  @type opts() :: %{
          optional(:retry_times) => pos_integer(),
          optional(:retry_backoff) => (() -> pos_integer())
        }

  @type stage_result() :: {:ok, any()} | {:error, any()}

  @doc """
  Evaluate a single stage of a command evaluation
  """
  @spec evaluate_stage(Command.t(), t()) :: stage_result()
  def evaluate_stage(%Command{} = command, %__MODULE__{type: type} = stage) when type in @types do
    @type_callees[type].evaluate(command, stage)
  end

  @doc """
  Conditionally build arguments based on the `func` arity.
  """
  @spec args_to_apply(Command.t(), t()) :: [
          Command.context()
          | Command.changes_so_far()
          | Command.t()
        ]
  def args_to_apply(%Command{} = _command, %__MODULE__{operation: func})
      when is_function(func, 0),
      do: []

  def args_to_apply(%Command{} = command, %__MODULE__{operation: func})
      when is_function(func, 1),
      do: [command.context]

  def args_to_apply(%Command{} = command, %__MODULE__{operation: func})
      when is_function(func, 2),
      do: [command.context, command.changes_so_far]

  def args_to_apply(%Command{} = command, %__MODULE__{operation: func})
      when is_function(func, 3),
      do: [command.context, command.changes_so_far, command]

  @doc """
  Applies a function and list of args to the `func`.
  """
  @spec apply_stage(Command.t(), t()) :: any()
  def apply_stage(%Command{} = command, %__MODULE__{operation: operation} = stage) do
    result = Kernel.apply(operation, args_to_apply(command, stage))

    # IO.inspect(operation)
    # IO.inspect(result)
    result
  rescue
    e -> handle_exception({e, System.stacktrace()}, command.opts)
  end

  @doc """
  Handle a success `result` based on the `stage` and `action`.
  """
  @spec handle_exception({Exception.t(), Exception.stacktrace()}, opts :: any()) ::
          {:error, %{error: Exception.t(), stacktrace: Exception.stacktrace()}}
  def handle_exception({e, stacktrace}, _opts) do
    {:error, %{error: e, stacktrace: stacktrace}}
  end

  @doc """
  Handle a success `result` based on the `stage` and `action`.
  """
  @spec handle_success(Command.t(), t(), any()) :: Command.t()
  def handle_success(%Command{} = command, %__MODULE__{type: type} = stage, result)
      when type in @types do
    @type_callees[type].handle_success(command, stage, result)
  end

  @doc """
  Handle an error `result` based on the `stage` and `action`.
  """
  @spec handle_failure(Command.t(), t(), any()) :: Command.t()
  def handle_failure(%Command{} = command, %__MODULE__{type: type} = stage, result)
      when type in @types do
    @type_callees[type].handle_failure(command, stage, result)
  end
end
