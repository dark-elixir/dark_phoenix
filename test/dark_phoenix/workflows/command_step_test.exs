defmodule DarkPhoenix.ExampleCommand do
  @moduledoc false
end

defmodule DarkPhoenix.Workflows.CommandStepTest do
  @moduledoc """
  Tests for `DarkPhoenix.Workflows.CommandStep`.
  """

  use ExUnit.Case, async: true

  alias DarkPhoenix.Workflows.CommandStep

  describe ".module_method_atom/1" do
    test "given :DarkPhoenix.ExampleCommand" do
      module = DarkPhoenix.ExampleCommand

      assert CommandStep.module_method_atom(module) == :example_command
    end
  end
end
