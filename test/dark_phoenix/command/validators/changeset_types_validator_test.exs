defmodule DarkPhoenix.Command.Validators.ChangesetTypesValidatorTest do
  @moduledoc """
  Test for `DarkPhoenix.Command.Validators.ChangesetTypesValidator`
  """

  use ExUnit.Case, async: true

  alias DarkEcto.Changesets
  alias DarkPhoenix.Command.Validators.ChangesetTypesValidator

  describe ".changeset_from_types/3" do
    test "given empty :types" do
      types = %{}
      context = %{}

      changeset = ChangesetTypesValidator.changeset_from_types(context, types)

      assert Changesets.changes_on(changeset) == %{}
      assert Changesets.errors_on(changeset) == %{}
    end

    test "given valid :types" do
      types = %{name: :string, int: :integer, float: :float}
      context = %{name: "name", int: 1, float: 3.14}

      changeset = ChangesetTypesValidator.changeset_from_types(context, types)

      assert Changesets.changes_on(changeset) == context
      assert Changesets.errors_on(changeset) == %{}
    end

    test "given invalid :types" do
      types = %{name: :string, int: :integer, float: :float}
      context = %{name: %{}, int: %{}, float: %{}}

      changeset = ChangesetTypesValidator.changeset_from_types(context, types)

      assert Changesets.changes_on(changeset) == %{}

      assert Changesets.errors_on(changeset) == %{
               float: ["is invalid"],
               int: ["is invalid"],
               name: ["is invalid"]
             }

      assert changeset.errors == [
               {:float, {"is invalid", [type: :float, validation: :cast]}},
               {:int, {"is invalid", [type: :integer, validation: :cast]}},
               {:name, {"is invalid", [type: :string, validation: :cast]}}
             ]
    end
  end

  describe ".validate_from_types/3" do
    test "given empty :types" do
      types = %{}
      context = %{}
      assert ChangesetTypesValidator.validate_from_types(context, types) == :ok
    end

    test "given valid :types" do
      types = %{name: :string, int: :integer, float: :float}
      context = %{name: "name", int: 1, float: 3.14}

      assert ChangesetTypesValidator.validate_from_types(context, types) == :ok
    end

    test "given invalid :types" do
      types = %{name: :string, int: :integer, float: :float}
      context = %{name: %{}, int: %{}, float: %{}}

      assert ChangesetTypesValidator.validate_from_types(context, types) ==
               {:error,
                %{
                  float: ["is invalid"],
                  int: ["is invalid"],
                  name: ["is invalid"]
                }}
    end
  end

  describe ".build_validate_by_types/3" do
    test "given empty :types" do
      types = %{}
      context = %{}

      validator = ChangesetTypesValidator.build_validate_by_types(types)
      assert is_function(validator, 1)
      assert validator.(context) == :ok
    end

    test "given valid :types" do
      types = %{name: :string, int: :integer, float: :float}
      context = %{name: "name", int: 1, float: 3.14}

      validator = ChangesetTypesValidator.build_validate_by_types(types)
      assert is_function(validator, 1)

      assert validator.(context) == :ok
    end

    test "given invalid :types" do
      types = %{name: :string, int: :integer, float: :float}
      context = %{name: %{}, int: %{}, float: %{}}

      validator = ChangesetTypesValidator.build_validate_by_types(types)
      assert is_function(validator, 1)

      assert validator.(context) ==
               {:error,
                %{
                  float: ["is invalid"],
                  int: ["is invalid"],
                  name: ["is invalid"]
                }}
    end
  end
end
