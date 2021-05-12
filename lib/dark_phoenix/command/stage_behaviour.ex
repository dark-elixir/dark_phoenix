defmodule DarkPhoenix.Command.StageBehaviour do
  @moduledoc """
  This module provides behaviours for command stages
  """

  alias DarkPhoenix.Command
  alias DarkPhoenix.Command.Stage

  @doc """
  Evaluates a given stage and function
  """
  @callback evaluate(Command.t(), Stage.t()) :: Stage.stage_result()

  @doc """
  Handler for success evaluations
  """
  @callback handle_success(Command.t(), Stage.t(), result :: any()) :: Command.t()

  @doc """
  Handler for failure evaluations
  """
  @callback handle_failure(Command.t(), Stage.t(), error :: any()) :: Command.t()
end
