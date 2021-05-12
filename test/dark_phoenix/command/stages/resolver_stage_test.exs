defmodule DarkPhoenix.Command.Stages.ResolverStageTest do
  @moduledoc """
  Test for `DarkPhoenix.Command.Stages.ResolverStage`
  """

  use ExUnit.Case, async: true

  alias DarkPhoenix.Command
  alias DarkPhoenix.Command.Stage
  alias DarkPhoenix.Command.Stages.ResolverStage

  describe ".evaluate/3" do
    @action :resolver
    test "given a valid :command, :stage, and :func that returns {:ok, result}" do
      command = %Command{}
      result = %{result: :ok}
      stage = %Stage{type: @action, name: :test_stage, operation: fn _ -> {:ok, result} end}

      assert ResolverStage.evaluate(command, stage) == {:ok, result}
    end

    test "given a valid :command, :stage, and :func that returns {:error, result}" do
      command = %Command{}
      result = %{result: :error}
      stage = %Stage{type: @action, name: :test_stage, operation: fn _ -> {:error, result} end}

      assert ResolverStage.evaluate(command, stage) == {:error, result}
    end

    test "given a valid :command, :stage, and :func that returns unsupported shape" do
      command = %Command{}
      result = {:ok, :tuple3, %{data: true}}
      stage = %Stage{type: @action, name: :test_stage, operation: fn _ -> result end}

      assert ResolverStage.evaluate(command, stage) == {
               :error,
               {:unsupported_resolver_result, result}
             }
    end
  end

  describe ".handle_success/3" do
    test "given a valid :command and :result" do
      command = %Command{}
      stage = %Stage{type: :resolver, name: :test_stage}
      result = %{result: true}

      assert ResolverStage.handle_success(command, stage, result) == %{
               command
               | context: %{stage.name => result}
             }
    end
  end

  describe ".handle_failure/3" do
    test "given a valid :command and :result" do
      command = %Command{}
      stage = %Stage{type: :resolver, name: :test_stage}
      result = %{result: true}

      assert ResolverStage.handle_failure(command, stage, result) == %{
               command
               | failed_operation: stage.name,
                 failed_value: result,
                 valid?: false
             }
    end
  end
end
