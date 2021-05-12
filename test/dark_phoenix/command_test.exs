defmodule DarkPhoenix.CommandTest do
  @moduledoc """
  Tests for `DarkPhoenix.Command`.
  """

  use ExUnit.Case, async: true
  doctest DarkPhoenix.Command, import: true

  alias DarkPhoenix.Command
  alias DarkPhoenix.Command.Stage

  defmodule MockRepo do
    @moduledoc """
    Mock for `Ecto.Repo`.
    """

    def transaction(%Ecto.Multi{} = multi) do
      {:ok, {:mock, multi}}
    end
  end

  defmodule CommandTrueExample do
    @moduledoc """
    Fixture for returning simple `true` stage.
    """

    use DarkPhoenix.Command, repo: MockRepo

    @impl true
    def build(context \\ %{}) do
      context
      |> new()
      |> Command.validate(:validation_stage, fn -> true end)
    end
  end

  defmodule CommandFalseExample do
    @moduledoc """
    Fixture for returning simple `false` stage.
    """

    use DarkPhoenix.Command, repo: MockRepo

    @impl true
    def build(context \\ %{}) do
      context
      |> new()
      |> Command.validate(:validation_stage, fn -> false end)
    end
  end

  defmodule CommandMultiExample do
    @moduledoc """
    Fixture for returning `Ecto.Multi` stage.
    """

    use DarkPhoenix.Command, repo: MockRepo

    @impl true
    def build(context \\ %{}) do
      multi = multi_fixture()

      context
      |> new()
      |> Command.validate(:validation_stage, fn -> false end)
      |> Command.resolver(:user, fn -> {:ok, %{user: :name}} end)
      |> Command.multi(:multi_stage, multi)
      |> Command.multi(:multi_stage_fn0, fn -> multi end)
      |> Command.multi(:multi_stage_fn1, fn _ -> multi end)
      |> Command.multi(:multi_stage_fn2, fn _, _ -> multi end)
    end

    defp changeset_fixture do
      data = %{}
      types = %{name: :string, content: :string}
      payload = %{name: "Callum"}

      {data, types}
      |> Ecto.Changeset.cast(payload, Map.keys(types))
      |> Ecto.Changeset.validate_required([:name, :content])
      |> Ecto.Changeset.validate_length(:name, min: 20)
    end

    defp multi_fixture do
      Ecto.Multi.new()
      |> Ecto.Multi.insert(:example, changeset_fixture())
    end
  end

  describe ".new/1" do
    test "given a valid :caller" do
      caller = DarkPhoenix
      macro_opts = %{}

      assert Command.new({caller, macro_opts}) == %Command{
               caller: caller
             }
    end

    test "given a valid :caller and :repo" do
      caller = DarkPhoenix
      macro_opts = %{repo: :fake_repo}

      assert Command.new({caller, macro_opts}) == %Command{
               repo: :fake_repo,
               caller: caller
             }
    end
  end

  describe ".new/2" do
    test "given a valid :caller and :context" do
      caller = DarkPhoenix
      macro_opts = %{}
      context = %{args: []}

      assert Command.new({caller, macro_opts}, context) == %Command{
               caller: caller,
               caller_context: context,
               context: context
             }
    end

    test "given a valid :caller and :context and :repo" do
      caller = DarkPhoenix
      macro_opts = %{repo: :fake_repo}
      context = %{args: []}

      assert Command.new({caller, macro_opts}, context) == %Command{
               repo: :fake_repo,
               caller: caller,
               caller_context: context,
               context: context
             }
    end
  end

  describe ".perform/2" do
    test "given :CommandTrueExample" do
      args = %{arg: 1}
      job = %{job_id: 2}

      assert {:ok,
              %Command{
                caller: CommandTrueExample,
                valid?: true,
                job: job,
                context: args,
                caller_context: args,
                operations: [%Stage{name: :validation_stage, type: :validate, operation: func}],
                repo: MockRepo
              }} = CommandTrueExample.perform(args, job)
    end

    test "given :CommandFalseExample" do
      args = %{arg: 1}
      job = %{job_id: 2}

      assert {:error,
              %Command{
                caller: CommandFalseExample,
                valid?: false,
                failed_operation: :validation_stage,
                failed_value: false,
                job: job,
                operations: [%Stage{name: :validation_stage, type: :validate, operation: func}],
                repo: MockRepo
              }} = CommandFalseExample.perform(args, job)
    end
  end

  describe ".multi/3" do
    test "given a valid :command, :name, and :func (with :repo)" do
      command = %Command{repo: :repo}
      name = :test
      func = fn -> Ecto.Multi.new() end

      assert Command.multi(command, name, func) == %{
               command
               | operations: [%Stage{type: :multi, name: name, operation: func}]
             }
    end
  end

  describe ".multi/4" do
    test "given a valid :command, :name, :func, and :opts (with :repo)" do
      command = %Command{repo: :repo}
      name = :test
      func = fn -> Ecto.Multi.new() end
      opts = %{retry_times: 2}

      assert Command.multi(command, name, func, opts) == %{
               command
               | operations: [%Stage{type: :multi, name: name, operation: func, opts: opts}]
             }
    end
  end

  describe ".resolver/3" do
    test "given a valid :command, :name, and :func" do
      command = %Command{}
      name = :test
      func = fn -> :ok end

      assert Command.resolver(command, name, func) == %{
               command
               | operations: [%Stage{type: :resolver, name: name, operation: func}]
             }
    end
  end

  describe ".resolver/4" do
    test "given a valid :command, :name, :func, and :opts" do
      command = %Command{}
      name = :test
      func = fn -> :ok end
      opts = %{retry_times: 2}

      assert Command.resolver(command, name, func, opts) == %{
               command
               | operations: [%Stage{type: :resolver, name: name, operation: func, opts: opts}]
             }
    end
  end

  describe ".validate/3" do
    test "given a valid :command, :name, and :types" do
      command = %Command{}
      name = :test
      types = %{name: :string}

      assert %Command{
               operations: [%Stage{type: :validate, name: name, operation: func}]
             } = Command.validate(command, name, types)

      assert is_function(func, 1)
    end

    test "given a valid :command, :name, and :func" do
      command = %Command{}
      name = :test
      func = fn -> :ok end

      assert Command.validate(command, name, func) == %{
               command
               | operations: [%Stage{type: :validate, name: name, operation: func}]
             }
    end
  end

  describe ".validate/4" do
    test "given a valid :command, :name, :func, and :opts" do
      command = %Command{}
      name = :test
      func = fn -> :ok end
      opts = %{retry_times: 2}

      assert Command.validate(command, name, func, opts) == %{
               command
               | operations: [%Stage{type: :validate, name: name, operation: func, opts: opts}]
             }
    end

    test "given a valid :command, :name, :func, and :opts (without :repo) raises" do
      command = %Command{}
      name = :test
      func = fn -> Ecto.Multi.new() end
      opts = %{}

      assert_raise ArgumentError,
                   """
                   [DarkPhoenix.Command]

                   To call .multi #{name} you must pass a `:repo`

                   Usage:

                     defmodule MyCommand
                       use DarkPhoenix.Command, repo: ExampleApp.Repo
                     end

                   """,
                   fn ->
                     Command.multi(command, name, func, opts)
                   end
    end
  end

  describe ".evaluate/1" do
    test "given a valid :command with no steps" do
      command = %Command{}
      result = Command.evaluate(command)
      assert result.valid? == true
    end

    test "given a valid :command with :types validator" do
      context = %{name: %{}}
      types = %{name: :string}

      command =
        {:fake_command, %{}}
        |> Command.new(context)
        |> Command.validate(:type_validator, types)

      result = Command.evaluate(command)

      assert result.valid? == false
      assert result.failed_operation == :type_validator
      assert result.failed_value == %{name: ["is invalid"]}
    end
  end

  describe ".wrap_result/1" do
    test "given a valid :command" do
      command = %Command{valid?: true}
      assert Command.wrap_result(command) == {:ok, command}
    end

    test "given an invalid :command" do
      command = %Command{valid?: false}
      assert Command.wrap_result(command) == {:error, command}
    end
  end

  describe ".to_list/1" do
    test "given CommandTrueExample" do
      command = CommandTrueExample.build()
      assert [{:validation_stage, {:validate, _func, %{}}}] = Command.to_list(command)
    end

    test "given CommandFalseExample" do
      command = CommandFalseExample.build()
      assert [{:validation_stage, {:validate, _func, %{}}}] = Command.to_list(command)
    end

    test "given CommandMultiExample" do
      command = CommandMultiExample.build()

      assert [
               {:validation_stage, {:validate, _, %{}}},
               {:user, {:resolver, _, %{}}},
               {:multi_stage, {:multi, multi_stage_list, %{}}},
               {:multi_stage_fn0, {:multi, multi_stage_fn0_list, %{}}},
               {:multi_stage_fn1, {:multi, _, %{}}},
               {:multi_stage_fn2, {:multi, _, %{}}}
             ] = Command.to_list(command)

      assert [{:example, {:insert, %Ecto.Changeset{}, []}}] = multi_stage_list
      assert [{:example, {:insert, %Ecto.Changeset{}, []}}] = multi_stage_fn0_list
    end
  end

  describe ".run/1" do
    test "given CommandTrueExample" do
      context = %{}
      assert %Command{valid?: true} = CommandTrueExample.run(context)
    end

    test "given CommandFalseExample" do
      context = %{}
      assert %Command{valid?: false} = CommandFalseExample.run(context)
    end

    test "given CommandMultiExample" do
      context = %{}
      assert %Command{valid?: false} = CommandMultiExample.run(context)
    end
  end

  describe ".run_sync/1" do
    test "given CommandTrueExample" do
      context = %{}
      assert CommandTrueExample.run_sync(context) == {:ok, %{}}
    end

    test "given CommandFalseExample" do
      context = %{}

      assert CommandFalseExample.run_sync(context) ==
               {:error, {:validation_stage, false, %{}, %{}}}
    end

    test "given CommandMultiExample" do
      context = %{}

      assert CommandMultiExample.run_sync(context) ==
               {:error, {:validation_stage, false, %{}, %{}}}
    end
  end

  describe ".run_async/1" do
    test "given CommandTrueExample" do
      context = %{}
      assert %Task{} = CommandTrueExample.run_async(context)
    end

    test "given CommandFalseExample" do
      context = %{}
      assert %Task{} = CommandFalseExample.run_async(context)
    end

    test "given CommandMultiExample" do
      context = %{}
      assert %Task{} = CommandMultiExample.run_async(context)
    end
  end

  # describe ".rollback/2" do
  #     test "given a valid :args" do
  #       command = %Command{}
  #       opts = [from: :rollback_stage]
  #       assert Command.new(command, opts) == %{}
  #     end
  # end
end
