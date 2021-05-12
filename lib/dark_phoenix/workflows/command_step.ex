defmodule DarkPhoenix.Workflows.CommandStep do
  @moduledoc """
  Adds `DarkPhoenix.DarkCommand` dispatch to `Opus.Pipeline`.
  """

  import DarkPhoenix.Workflows.StepOkStep, only: [step_ok: 2]

  alias DarkPhoenix.DarkCommand
  alias DarkPhoenix.DarkWorkflow
  alias DarkPhoenix.Workflows.CommandStep

  require Opus.Pipeline

  @doc """
  Adds a `:command` step to execute `DarkPhoenix.DarkCommand` in an `Opus.Pipeline`.
  """
  # defmacro command(module, opts \\ []) when is_atom(module) do
  defmacro command(module_or_alias, opts \\ []) do
    module = Macro.expand(module_or_alias, __CALLER__)
    method = module_method_atom(module)

    quote do
      def unquote(method)(payload) do
        CommandStep.call(unquote(module), payload)
      end

      step_ok(unquote(method), unquote(opts))
    end
  end

  @doc """
  Executes the `DarkPhoenix.DarkCommand` in an `Opus.Pipeline`.
  """
  @spec call(module(), DarkWorkflow.opus_context()) :: DarkCommand.result()
  def call(module, %{current_user: current_user} = payload) do
    module.call(payload, current_user)
  end

  def call(module, payload) when is_map(payload) do
    module.call(payload)
  end

  @doc """
  Returns the method atom for the given command `module`.
  """
  @spec module_method_atom(module()) :: atom()
  def module_method_atom(module) when is_atom(module) do
    module
    |> Module.split()
    |> List.last()
    # |> String.trim_trailing("Command")
    |> Macro.underscore()
    |> String.to_atom()
  end
end
