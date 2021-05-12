defmodule DarkPhoenix.Command do
  @moduledoc """
  Command
  """

  alias DarkPhoenix.Command.Stage
  alias DarkPhoenix.Command.Validators.ChangesetTypesValidator

  alias Oban.Job

  defstruct [
    :caller,
    :failed_operation,
    :failed_value,
    :job,
    :repo,
    caller_context: %{},
    changes_so_far: %{},
    context: %{},
    operations: [],
    opts: %{},
    valid?: true
  ]

  @type t() :: %__MODULE__{
          caller_context: context(),
          caller: atom(),
          changes_so_far: changes_so_far(),
          context: context(),
          failed_operation: atom() | nil,
          failed_value: any(),
          job: Job.t() | nil,
          operations: [Stage.t()],
          opts: map(),
          repo: ecto_repo :: module() | nil,
          valid?: boolean()
        }

  @type action() :: :validate | :resolver | :multi
  @type stage() :: atom()
  @type context() :: map()
  @type changes_so_far() :: %{required(atom()) => any()}

  @type functor() ::
          functor(validate_result())
          | functor(resolver_result())
          | functor(multi_result())

  @type functor(arg) ::
          functor1(arg)
          | functor2(arg)
          | functor3(arg)

  @type functor1(arg) :: (context() -> arg)
  @type functor2(arg) :: (context(), changes_so_far() -> arg)
  @type functor3(arg) :: (context(), changes_so_far(), t() -> arg)

  @type multi_result() :: Ecto.Multi.t() | {:ok, Ecto.Multi.t()} | {:error, any()}
  @type resolver_result() :: {:ok, any()} | {:error, any()}
  @type validate_result() :: :ok | {:ok, any()} | boolean() | :error | {:error, any()}

  @type perform_result() :: {:ok, t()} | {:error, t()}
  @type run_result() :: t()
  @type run_sync_result() :: {:ok, t()} | {:error, t()}
  @type run_async_result() :: Task.t()

  @type macro_opts() :: %{optional(:repo) => atom()}
  @type stage_opts() :: %{required(atom()) => any()} | Keyword.t()

  @doc false
  defmacro __using__(opts \\ []) do
    repo = Keyword.get(opts, :repo, nil)

    # oban = Keyword.get(opts, :oban, [])

    quote location: :keep do
      @behaviour DarkPhoenix.Command.CommandBehaviour

      # use Oban.Worker, unquote(Macro.escape(oban))

      alias DarkPhoenix.Command

      # Ecto Repo
      @repo unquote(repo)

      @doc false
      @impl DarkPhoenix.Command.CommandBehaviour
      @spec new(Command.context()) :: Command.t()
      def new(context \\ %{}) when is_map(context) do
        macro_opts = %{repo: @repo}

        {__MODULE__, macro_opts}
        |> Command.new(context)
      end

      # @impl Oban.Worker
      # @spec perform(Oban.Job.args(), Oban.Job.t()) :: Command.perform_result()

      @doc false
      def perform(args, job) do
        args
        |> build()
        |> Command.evaluate()
        |> Command.wrap_result()
      end

      @doc false
      @impl DarkPhoenix.Command.CommandBehaviour
      @spec run(Command.context()) :: Command.run_result()
      def run(context \\ %{}) when is_map(context) do
        context
        |> build()
        |> Command.evaluate()
      end

      @doc false
      @impl DarkPhoenix.Command.CommandBehaviour
      @spec run_sync(Command.context()) :: Command.run_sync_result()
      def run_sync(context \\ %{}) when is_map(context) do
        context
        |> run()
        |> Command.wrap_result()
        |> Command.handle_result()
      end

      @doc false
      @impl DarkPhoenix.Command.CommandBehaviour
      @spec run_async(Command.context(), task_opts :: Keyword.t()) :: Command.run_async_result()
      def run_async(context \\ %{}, opts \\ []) when is_map(context) and is_list(opts) do
        Task.async(fn -> run_sync(context) end)
      end
    end
  end

  @doc """
  Instiantiate a new `DarkPhoenix.Command`.
  """
  @spec new({atom(), macro_opts()}, context()) :: t()
  def new({caller, macro_opts}, context \\ %{})
      when is_atom(caller) and is_map(macro_opts) and is_map(context) do
    __MODULE__
    |> struct(
      macro_opts
      |> Map.merge(%{
        caller: caller,
        caller_context: context,
        context: context
      })
    )
  end

  @doc """
  Creates a new validate operation named `stage`.
  """
  @spec validate(
          t(),
          stage(),
          ChangesetTypesValidator.validate_types() | functor(validate_result()),
          stage_opts()
        ) :: t()
  def validate(command, stage, validator, opts \\ %{})

  def validate(%__MODULE__{} = command, stage, func, opts)
      when is_atom(stage) and is_function(func) do
    put_operation(command, stage, :validate, func, opts)
  end

  def validate(%__MODULE__{} = command, stage, types, opts)
      when is_atom(stage) and is_map(types) do
    put_operation(
      command,
      stage,
      :validate,
      ChangesetTypesValidator.build_validate_by_types(types),
      opts
    )
  end

  @doc """
  Creates a new resolver operation with `context` key `stage`.
  """
  @spec resolver(t(), stage(), functor(resolver_result()), stage_opts()) :: t()
  def resolver(%__MODULE__{} = command, stage, func, opts \\ %{})
      when is_atom(stage) and is_function(func) do
    put_operation(command, stage, :resolver, func, opts)
  end

  @doc """
  Creates a new `Ecto.Multi` operation with `changes_so_far` key `stage`.

  Raises `ArgumentError` if a `:repo` is not passed as an option in the use macro.
  """
  @spec multi(t(), stage(), Ecto.Multi.t() | functor(multi_result()), stage_opts()) :: t()
  def multi(command, stage, func, opts \\ %{})

  def multi(%__MODULE__{repo: nil}, stage, _func, _opts) do
    raise ArgumentError, """
    [DarkPhoenix.Command]

    To call .multi #{stage} you must pass a `:repo`

    Usage:

      defmodule MyCommand
        use DarkPhoenix.Command, repo: ExampleApp.Repo
      end

    """
  end

  def multi(%__MODULE__{} = command, stage, %Ecto.Multi{} = multi, opts)
      when is_atom(stage) do
    put_operation(command, stage, :multi, fn -> multi end, opts)
  end

  def multi(%__MODULE__{} = command, stage, func, opts)
      when is_atom(stage) and is_function(func) do
    put_operation(command, stage, :multi, func, opts)
  end

  defp put_operation(%__MODULE__{operations: operations} = command, name, type, func, opts)
       when is_list(operations) and is_atom(name) and is_function(func) and
              (is_map(opts) or is_list(opts)) do
    operation = %Stage{
      name: name,
      type: type,
      operation: func,
      opts: Enum.into(%{}, opts)
    }

    %{command | operations: Enum.concat(operations, [operation])}
  end

  @spec evaluate(t()) :: t()
  def evaluate(%__MODULE__{operations: operations} = command) when is_list(operations) do
    operations
    |> Enum.reduce_while(command, fn stage, command ->
      case Stage.evaluate_stage(command, stage) do
        {:ok, result} ->
          {:cont, Stage.handle_success(command, stage, result)}

        {:error, error} ->
          # rollback(command, from: stage)
          {:halt, Stage.handle_failure(command, stage, error)}
      end
    end)
  end

  @doc """
  Generates a list representation of a `DarkPhoenix.Command` struct.
  """
  @spec to_list(t()) :: list()
  def to_list(%__MODULE__{operations: operations}) do
    for %Stage{type: type, name: name, opts: opts, operation: operation} <- operations do
      {name, {type, do_to_list(type, operation), opts}}
    end
  end

  defp do_to_list(:multi, %Ecto.Multi{} = multi), do: Ecto.Multi.to_list(multi)
  defp do_to_list(:multi, func) when is_function(func, 0), do: do_to_list(:multi, func.())
  defp do_to_list(_type, func) when is_function(func), do: func

  @doc """
  Transforms the given `command` into either `{:ok, command}` or `{:error, command}` based on the `boolean` `:valid?`
  """
  @spec wrap_result(t()) :: perform_result()
  def wrap_result(%__MODULE__{valid?: true} = command), do: {:ok, command}
  def wrap_result(%__MODULE__{valid?: false} = command), do: {:error, command}

  # def rollback(%__MODULE__{} = command, from: stage) do
  #   {:ok, command}
  # end

  def handle_result({:ok, %__MODULE__{} = command}) do
    data =
      %{}
      |> Map.merge(command.context)
      |> Map.merge(command.changes_so_far)

    {:ok, data}
  end

  def handle_result({:error, %__MODULE__{} = command}) do
    {:error,
     {command.failed_operation, command.failed_value, command.context, command.changes_so_far}}
  end

  def handle_result(any) do
    {:error, {:unhandled, any}}
  end
end
