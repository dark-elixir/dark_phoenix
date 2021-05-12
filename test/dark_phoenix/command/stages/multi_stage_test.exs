defmodule DarkPhoenix.Command.Stages.MultiStageTest do
  @moduledoc """
  Test for `DarkPhoenix.Command.Stages.MultiStage`
  """

  use ExUnit.Case, async: true

  alias DarkPhoenix.Command
  alias DarkPhoenix.Command.Stage
  alias DarkPhoenix.Command.Stages.MultiStage

  defmodule MockRepo do
    @moduledoc """
    Mock for `Ecto.Repo`.
    """

    def transaction(%Ecto.Multi{} = multi) do
      {:ok, {:mock, multi}}
    end
  end

  describe ".evaluate/3" do
    @action :multi
    test "given a valid :command, :stage, and :func that returns Ecto.Multi" do
      command = %Command{repo: MockRepo}
      multi = Ecto.Multi.new()
      stage = %Stage{type: @action, name: :test_stage, operation: fn _ -> multi end}

      assert MultiStage.evaluate(command, stage) == {:ok, {:mock, multi}}
    end

    test "given a valid :command, :stage, and :func that returns {:ok, Ecto.Multi}" do
      command = %Command{repo: MockRepo}

      multi = Ecto.Multi.new()

      stage = %Stage{
        type: @action,
        name: :test_stage,
        operation: fn _ -> {:ok, multi} end
      }

      assert MultiStage.evaluate(command, stage) == {:ok, {:mock, multi}}
    end

    test "given a valid :command, :stage, and :func that returns (:error, :invalid)" do
      command = %Command{repo: MockRepo}
      stage = %Stage{type: @action, name: :test_stage, operation: fn _ -> {:error, :invalid} end}

      assert MultiStage.evaluate(command, stage) == {:error, :invalid}
    end
  end

  describe ".handle_success/3" do
    test "given a valid :command and :result" do
      command = %Command{}
      stage = %Stage{type: :multi, name: :test_stage}
      result = %{result: true}

      assert MultiStage.handle_success(command, stage, result) == %{
               command
               | changes_so_far: %{stage.name => result}
             }
    end
  end

  describe ".handle_failure/3" do
    test "given a valid :command and :result" do
      command = %Command{}
      stage = %Stage{type: :multi, name: :test_stage}
      result = %{result: true}

      assert MultiStage.handle_failure(command, stage, result) == %{
               command
               | failed_operation: stage.name,
                 failed_value: result,
                 valid?: false
             }
    end
  end
end
