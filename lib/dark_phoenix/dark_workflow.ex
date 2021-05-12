defmodule DarkPhoenix.DarkWorkflow do
  @moduledoc """
  `DarkPhoenix.DarkWorkflow`
  """

  alias Opus.PipelineError

  alias DarkPhoenix.Workflows.CommandStep
  alias DarkPhoenix.Workflows.EventStep
  alias DarkPhoenix.Workflows.StepOkStep

  @type opus_context() :: %{
          required(atom()) => any(),
          optional(:current_user) => struct() | nil
        }

  @type step_result() :: map() | {:error, any()}

  @type result() :: map() | {:error, PipelineError.t()}

  @type macro_opts() :: Keyword.t()

  @doc false
  @spec __using__(macro_opts()) :: any()
  defmacro __using__(_opts \\ []) do
    quote location: :keep do
      use Opus.Pipeline

      import StepOkStep, only: [step_ok: 1, step_ok: 2]
      import CommandStep, only: [command: 1, command: 2]
      import EventStep, only: [event: 1, event: 2]
    end
  end
end
