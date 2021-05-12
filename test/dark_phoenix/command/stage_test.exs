defmodule DarkPhoenix.Command.StageTest do
  @moduledoc """
  Tests for `DarkPhoenix.Command`.
  """

  use ExUnit.Case, async: true

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

  describe ".evaluate_stage/3 (:multi)" do
    @action :multi
    test "given a valid :command, :stage, and :func that returns Ecto.Multi" do
      command = %Command{repo: MockRepo}
      multi = Ecto.Multi.new()
      stage = %Stage{type: @action, name: :test_stage, operation: fn _ -> multi end}

      assert Stage.evaluate_stage(command, stage) == {:ok, {:mock, multi}}
    end

    test "given a valid :command, :stage, and :func that returns {:ok, Ecto.Multi}" do
      command = %Command{repo: MockRepo}
      multi = Ecto.Multi.new()

      stage = %Stage{
        type: @action,
        name: :test_stage,
        operation: fn _ -> {:ok, multi} end
      }

      assert Stage.evaluate_stage(command, stage) == {:ok, {:mock, multi}}
    end

    test "given a valid :command, :stage, and :func that returns (:error, :invalid)" do
      command = %Command{repo: MockRepo}
      stage = %Stage{type: @action, name: :test_stage, operation: fn _ -> {:error, :invalid} end}

      assert Stage.evaluate_stage(command, stage) == {:error, :invalid}
    end
  end

  describe ".evaluate_stage/3 (:resolver)" do
    @action :resolver
    test "given a valid :command, :stage, and :func that returns {:ok, result}" do
      command = %Command{}
      result = %{result: :ok}
      stage = %Stage{type: @action, name: :test_stage, operation: fn _ -> {:ok, result} end}

      assert Stage.evaluate_stage(command, stage) == {:ok, result}
    end

    test "given a valid :command, :stage, and :func that returns {:error, result}" do
      command = %Command{}
      result = %{result: :error}
      stage = %Stage{type: @action, name: :test_stage, operation: fn _ -> {:error, result} end}

      assert Stage.evaluate_stage(command, stage) == {:error, result}
    end

    test "given a valid :command, :stage, and :func that returns unsupported shape" do
      command = %Command{}
      result = {:ok, :tuple3, %{data: true}}
      stage = %Stage{type: @action, name: :test_stage, operation: fn _ -> result end}

      assert Stage.evaluate_stage(command, stage) == {
               :error,
               {:unsupported_resolver_result, result}
             }
    end
  end

  describe ".evaluate_stage/3 (:validate)" do
    @action :validate

    test "given a valid :command, :stage, and :func that returns {:ok, result}" do
      command = %Command{}
      result = %{result: :ok}
      stage = %Stage{type: @action, name: :test_stage, operation: fn _ -> {:ok, result} end}

      assert Stage.evaluate_stage(command, stage) == {:ok, result}
    end

    test "given a valid :command, :stage, and :func that returns {:error, result}" do
      command = %Command{}
      result = %{result: :error}
      stage = %Stage{type: @action, name: :test_stage, operation: fn _ -> {:error, result} end}

      assert Stage.evaluate_stage(command, stage) == {:error, result}
    end

    test "given a valid :command, :stage, and :func that returns unsupported shape" do
      command = %Command{}
      result = {:ok, :tuple3, %{data: true}}
      stage = %Stage{type: @action, name: :test_stage, operation: fn _ -> result end}

      assert Stage.evaluate_stage(command, stage) == {
               :error,
               {:unsupported_validate_result, result}
             }
    end
  end

  describe ".args_to_apply/3" do
    test "given a valid :command and :func with arity 0" do
      command = %Command{}
      stage = %Stage{type: :validate, operation: fn -> :ok end}

      assert Stage.args_to_apply(command, stage) == []
    end

    test "given a valid :command and :func with arity 1" do
      command = %Command{}
      stage = %Stage{type: :validate, operation: fn _ -> :ok end}

      assert Stage.args_to_apply(command, stage) == [command.context]
    end

    test "given a valid :command and :func with arity 2" do
      command = %Command{}
      stage = %Stage{type: :validate, operation: fn _, _ -> :ok end}

      assert Stage.args_to_apply(command, stage) == [
               command.context,
               command.changes_so_far
             ]
    end

    test "given a valid :command and :func with arity 3" do
      command = %Command{}
      stage = %Stage{type: :validate, operation: fn _, _, _ -> :ok end}

      assert Stage.args_to_apply(command, stage) == [
               command.context,
               command.changes_so_far,
               command
             ]
    end
  end

  describe ".apply_stage/3 (:multi)" do
    test "given a valid :command, :action, and :func" do
      command = %Command{}
      stage = %Stage{type: :multi, operation: fn _ -> :ok end}

      assert Stage.apply_stage(command, stage) == :ok
    end

    test "given a valid :command, :action, and :func (error response)" do
      command = %Command{}
      stage = %Stage{type: :multi, operation: fn _ -> {:error, :fail} end}

      assert Stage.apply_stage(command, stage) == {:error, :fail}
    end

    test "given a valid :command, :action, and :func (raises)" do
      command = %Command{}
      stage = %Stage{type: :multi, operation: fn _ -> raise ArgumentError, "failure" end}

      assert {:error, %{error: %ArgumentError{message: "failure"}, stacktrace: [_ | _]}} =
               Stage.apply_stage(command, stage)
    end
  end

  describe ".apply_stage/3 (:resolver)" do
    test "given a valid :command, :action, and :func" do
      command = %Command{}
      stage = %Stage{type: :resolver, operation: fn _ -> :ok end}

      assert Stage.apply_stage(command, stage) == :ok
    end

    test "given a valid :command, :action, and :func (error response)" do
      command = %Command{}
      stage = %Stage{type: :resolver, operation: fn _ -> {:error, :fail} end}

      assert Stage.apply_stage(command, stage) == {:error, :fail}
    end

    test "given a valid :command, :action, and :func (raises)" do
      command = %Command{}
      stage = %Stage{type: :resolver, operation: fn _ -> raise ArgumentError, "failure" end}

      assert {:error, %{error: %ArgumentError{message: "failure"}, stacktrace: [_ | _]}} =
               Stage.apply_stage(command, stage)
    end
  end

  describe ".apply_stage/3 (:validate)" do
    test "given a valid :command, :action, and :func" do
      command = %Command{}
      stage = %Stage{type: :validate, operation: fn _ -> :ok end}

      assert Stage.apply_stage(command, stage) == :ok
    end

    test "given a valid :command, :action, and :func (error response)" do
      command = %Command{}
      stage = %Stage{type: :validate, operation: fn _ -> {:error, :fail} end}

      assert Stage.apply_stage(command, stage) == {:error, :fail}
    end

    test "given a valid :command, :action, and :func (raises)" do
      command = %Command{}
      stage = %Stage{type: :validate, operation: fn _ -> raise ArgumentError, "failure" end}

      assert {:error, %{error: %ArgumentError{message: "failure"}, stacktrace: [_ | _]}} =
               Stage.apply_stage(command, stage)
    end
  end

  describe ".handle_exception/3" do
    test "given a valid :stage" do
      e = ArgumentError
      stacktrace = []
      opts = %{}

      assert Stage.handle_exception({e, stacktrace}, opts) ==
               {:error, %{error: ArgumentError, stacktrace: []}}
    end
  end

  describe ".handle_success/3" do
    test "given a valid :command and :result (:validate)" do
      command = %Command{}
      stage = %Stage{type: :validate, name: :test_stage}
      result = %{result: true}

      assert Stage.handle_success(command, stage, result) == command
    end

    test "given a valid :command and :result (:resolver)" do
      command = %Command{}
      stage = %Stage{type: :resolver, name: :test_stage}
      result = %{result: true}

      assert Stage.handle_success(command, stage, result) == %{
               command
               | context: %{stage.name => result}
             }
    end

    test "given a valid :command and :result (:multi)" do
      command = %Command{}
      stage = %Stage{type: :multi, name: :test_stage}
      result = %{result: true}

      assert Stage.handle_success(command, stage, result) == %{
               command
               | changes_so_far: %{stage.name => result}
             }
    end
  end

  describe ".handle_failure/3" do
    test "given a valid :command and :result (:validate)" do
      command = %Command{}
      stage = %Stage{type: :validate, name: :test_stage}
      result = %{result: true}

      assert Stage.handle_failure(command, stage, result) == %{
               command
               | failed_operation: stage.name,
                 failed_value: result,
                 valid?: false
             }
    end

    test "given a valid :command and :result (:resolver)" do
      command = %Command{}
      stage = %Stage{type: :validate, name: :test_stage}
      result = %{result: true}

      assert Stage.handle_failure(command, stage, result) == %{
               command
               | failed_operation: stage.name,
                 failed_value: result,
                 valid?: false
             }
    end

    test "given a valid :command and :result (:multi)" do
      command = %Command{}
      stage = %Stage{type: :multi, name: :test_stage}
      result = %{result: true}

      assert Stage.handle_failure(command, stage, result) == %{
               command
               | failed_operation: stage.name,
                 failed_value: result,
                 valid?: false
             }
    end
  end
end
