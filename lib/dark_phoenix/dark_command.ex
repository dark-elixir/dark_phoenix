defmodule DarkPhoenix.DarkCommand do
  @moduledoc """
  `DarkPhoenix.DarkCommand`
  """

  @type acl() :: String.t()
  @type success_result() :: any()
  @type failure_result() :: any()

  @typedoc """
  * `:timeout` - The time in milliseconds to wait for the query call to
    finish. `:infinity` will wait indefinitely (default: 15000)
  * `:log` - When false, does not log the query
  * `:telemetry_event` - The telemetry event name to dispatch the event under.
  * `:telemetry_options` - Extra options to attach to telemetry event name.
  """
  @type ecto_repo_transaction_opt() ::
          {:log, boolean()}
          | {:timeout, pos_integer() | :infinity}
          | {:telemetry_event, atom() | [atom(), ...]}
          | {:telemetry_options, Keyword.t()}

  @type opt() ::
          {:acls, [acl()]}
          | {:job, Oban.Job.option()}
          # | {:repo, module()}
          | {:repo_transaction, [ecto_repo_transaction_opt()]}

  @type result() ::
          {:ok, map()}
          | {:error, Ecto.Changeset.t()}
          | {:error, Ecto.Multi.name(), any(), %{required(Ecto.Multi.name()) => any()}}

  @callback acls() :: [acl()]
  @callback job(payload :: map(), current_user :: any()) :: Oban.Job.t()
  @callback call(payload :: map(), current_user :: any()) :: result()
  @callback steps(Ecto.Multi.t(), Oban.Job.t()) :: Ecto.Multi.t()
  # @callback fetch_assocs(Ecto.Multi.t(), Oban.Job.t(), opts :: map()) :: Ecto.Multi.t()
  # @callback validate_assocs(Ecto.Multi.t(), Oban.Job.t(), opts :: map()) :: Ecto.Multi.t()
  # @callback before_steps_event_source_multi(Ecto.Multi.t(), Oban.Job.t()) :: Ecto.Multi.t()
  # @callback after_steps_event_source_multi(Ecto.Multi.t(), Oban.Job.t()) :: Ecto.Multi.t()
  # @callback handle_success_event_source(success_result()) :: :ok
  # @callback handle_failure_event_source(failure_result()) :: :ok

  # @callback handle_event_bus(any()) :: :ok

  @doc false
  @spec __using__([Oban.Job.option()]) :: any()
  defmacro __using__(opts \\ []) do
    repo = Application.fetch_env!(:dark_phoenix, :repo)

    # event_store = Application.fetch_env!(:dark_phoenix, :event_store)

    acls = Keyword.get(opts, :acls, [])
    job_opts = Keyword.get(opts, :job, [])
    repo_transaction_opts = Keyword.get(opts, :repo_transaction, [])

    quote location: :keep do
      use Oban.Worker, unquote(Macro.escape(job_opts))

      @behaviour DarkPhoenix.DarkCommand

      alias Ecto.Multi
      alias Oban.Job

      alias unquote(repo)

      @impl DarkPhoenix.DarkCommand
      def job(payload, current_user \\ nil) when is_map(payload) do
        %Oban.Job{args: %{"payload" => payload, "current_user" => current_user}}
      end

      @impl DarkPhoenix.DarkCommand
      def call(payload, current_user \\ nil) when is_map(payload) do
        payload
        |> job(current_user)
        |> perform()
      end

      @spec __dark_command__() :: [DarkPhoenix.DarkCommand.opt()]
      def __dark_command__ do
        unquote(Macro.escape(opts))
      end

      @doc """
      Required ACL's to perform the command.
      """
      @spec acls() :: [DarkPhoenix.DarkCommand.acl()]
      @impl DarkPhoenix.DarkCommand
      def acls do
        unquote(acls)
      end

      @doc """
      Implementation for the `c:Oban.Worker.perform/1` callback.
      """
      @impl Oban.Worker
      @spec perform(Oban.Job.t()) :: Oban.Worker.result()
      def perform(%Oban.Job{} = job) do
        Ecto.Multi.new()
        |> multi(job)
        |> unquote(repo).transaction(unquote(Macro.escape(repo_transaction_opts)))

        # |> case do
        # {:ok, changes} = result when is_map(changes) -> handle_success_event_source(result)
        # error -> handle_failure_event_source(error)
        # end
        # |> handle_event_bus()
      end

      def multi(%Ecto.Multi{} = multi, %Oban.Job{args: args} = job) when is_map(args) do
        multi
        |> Multi.run(:payload, fn _, _ -> {:ok, Map.get(args, "payload")} end)
        |> Multi.run(:current_user, fn _, _ -> {:ok, Map.get(args, "current_user")} end)
        |> Multi.run(:command, DarkPhoenix.DarkCommand.validate_command(__MODULE__, job))
        # |> before_steps_event_source_multi(job)
        # |> fetch_assocs(job, %{acls: unquote(acls)})
        # |> validate_assocs(job, %{acls: unquote(acls)})
        |> steps(job)

        # |> after_steps_event_source_multi(job)
      end

      # @impl DarkPhoenix.DarkCommand
      # def fetch_assocs(%Ecto.Multi{} = multi, %Oban.Job{} = job, opts) when is_map(opts) do
      #   DarkPhoenix.DarkCommand.fetch_assocs(__MODULE__, multi, job, opts)
      # end

      # @impl DarkPhoenix.DarkCommand
      # def validate_assocs(%Ecto.Multi{} = multi, %Oban.Job{} = job, opts) when is_map(opts) do
      #   DarkPhoenix.DarkCommand.validate_assocs(__MODULE__, multi, job, opts)
      # end

      # @impl DarkPhoenix.DarkCommand
      # def before_steps_event_source_multi(%Ecto.Multi{} = multi, %Oban.Job{} = job) do
      #   DarkPhoenix.DarkCommand.before_steps_event_source_multi(
      #     __MODULE__,
      #     multi,
      #     job,
      #     unquote(event_store)
      #   )
      # end

      # @impl DarkPhoenix.DarkCommand
      # def after_steps_event_source_multi(%Ecto.Multi{} = multi, %Oban.Job{} = job) do
      #   DarkPhoenix.DarkCommand.after_steps_event_source_multi(
      #     __MODULE__,
      #     multi,
      #     job,
      #     unquote(event_store)
      #   )
      # end

      def command_changeset_ok(payload, _current_user \\ nil) do
        payload
        |> payload_changeset()
        |> DarkPhoenix.DarkCommand.apply_changes_ok()
      end

      # @impl DarkPhoenix.DarkCommand
      # def handle_success_event_source({:ok, result}) when is_map(result) do
      #   # :ok
      # end

      # @impl DarkPhoenix.DarkCommand
      # def handle_failure_event_source(_result) do
      #   :ok
      # end

      # @impl DarkPhoenix.DarkCommand
      # def handle_event_bus(_result) do
      #   :ok
      # end

      # def perform(%Oban.Job{} = job) do
      #   DarkPhoenix.Worker.perform(__MODULE__, job)
      # end
    end
  end

  # def fetch_assocs(module, %Ecto.Multi{} = multi, %Oban.Job{} = _job, opts)
  #     when is_atom(module) and is_map(opts) do
  #   multi
  # end

  # def validate_assocs(module, %Ecto.Multi{} = multi, %Oban.Job{} = _job, opts)
  #     when is_atom(module) and is_map(opts) do
  #   multi
  # end

  @doc """
  Monadic `.apply_changes/1` wrapping

  ## Examples

      iex> apply_changes_ok(%Ecto.Changeset{valid?: true, data: %{}})
      {:ok, %{}}

      iex> apply_changes_ok(%Ecto.Changeset{valid?: false})
      {:error, %Ecto.Changeset{valid?: false}}
  """
  @spec apply_changes_ok(Ecto.Changeset.t()) :: {:ok, map()} | {:error, Ecto.Changeset.t()}
  def apply_changes_ok(%Ecto.Changeset{valid?: true} = changeset) do
    {:ok, Ecto.Changeset.apply_changes(changeset)}
  end

  def apply_changes_ok(%Ecto.Changeset{valid?: false} = changeset) do
    {:error, changeset}
  end

  # def before_steps_event_source_multi(
  #       module,
  #       %Ecto.Multi{} = multi,
  #       %Oban.Job{} = _job,
  #       event_store
  #     )
  #     when is_atom(module) and is_atom(event_store) do
  #   multi
  # end

  # def after_steps_event_source_multi(
  #       module,
  #       %Ecto.Multi{} = multi,
  #       %Oban.Job{} = _job,
  #       event_store
  #     )
  #     when is_atom(module) and is_atom(event_store) do
  #   multi
  # end

  def find(repo, schema, id, opts \\ []) do
    # preloads = Keyword.get(opts, :preload, [])

    # import Ecto.Query
    # query = from ^schema, preload: ^preloads

    # repo.get_ok(query, id)

    repo.get_ok(schema, id, opts)
  end

  @doc """
  Default implementation for the `c:Oban.Worker.perform/1` callback.
  """
  @spec perform(module(), Oban.Job.t()) :: Oban.Worker.result()
  def perform(module, %Oban.Job{args: %{"payload" => payload, "current_user" => _current_user}})
      when is_atom(module) and is_map(payload) do
    payload
    |> module.build_command()
    |> module.persist_command()
    |> module.execute()
    |> module.build_event()
    |> module.persist_event()
    |> module.handle_command_result()
  end

  def validate_command(module, %Oban.Job{
        args: %{"payload" => payload, "current_user" => current_user}
      }) do
    fn _repo, _changes_so_far -> module.command_changeset_ok(payload, current_user) end
  end

  def actor(%{id: id, first_name: first_name, last_name: last_name}) do
    "(#{id}) #{first_name} #{last_name}"
  end

  def actor(_) do
    nil
  end

  def job(payload, current_user \\ nil) when is_map(payload) do
    args = %{"payload" => payload, "current_user" => current_user}
    attempted_by = current_user |> actor() |> List.wrap()

    %Oban.Job{args: args, attempted_by: attempted_by}
  end
end
