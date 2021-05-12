if Code.ensure_loaded?(Absinthe) do
  defmodule DarkPhoenix.Command.Validators.AbsintheTypesValidatorTest do
    @moduledoc """
    Test for `DarkPhoenix.Command.Validators.AbsintheTypesValidator`
    """
    use ExUnit.Case, async: true

    alias DarkPhoenix.Command.Validators.AbsintheTypesValidator

    defmodule AbsintheSimpleArgs do
      @moduledoc """
      Simple `Absinthe` `input_object`.
      """
      use Absinthe.Schema

      query do
        # Query type must exist
      end

      @desc "A command"
      input_object :command_args do
        field(:name, non_null(:string))
        field(:count, :integer)
      end
    end

    describe ".absinthe_fields_for/2" do
      @tag :not_implemented
      test "given AbsintheSimpleArgs and :command_args" do
        assert AbsintheTypesValidator.absinthe_fields_for(AbsintheSimpleArgs, :command_args) ==
                 []
      end
    end
  end
end
