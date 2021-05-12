defmodule DarkPhoenix.Workflows.EventStep do
  @moduledoc """
  Adds `DarkPhoenix.DarkEvent` dispatch to `Opus.Pipeline`.
  """

  import DarkPhoenix.Workflows.StepOkStep, only: [step_ok: 2]

  alias DarkEvents.Behaviours.EventDispatcher
  alias DarkPhoenix.DarkWorkflow
  alias DarkPhoenix.Workflows.EventStep

  require Opus.Pipeline

  @doc """
  Adds a `:event` step to execute `DarkPhoenix.DarkEvent` in an `Opus.Pipeline`.
  """
  # defmacro event(module, opts \\ []) when is_atom(module) do
  defmacro event(module_or_alias, opts \\ []) do
    module = Macro.expand(module_or_alias, __CALLER__)
    method = module_method_atom(module)

    quote do
      def unquote(method)(payload) do
        EventStep.call(unquote(module), payload)
      end

      step_ok(unquote(method), unquote(opts))
    end
  end

  @doc """
  Builds the `DarkEvents` payload struct and delivers the event in an `Opus.Pipeline`.
  """
  @spec call(module(), DarkWorkflow.opus_context()) :: EventDispatcher.delivery_result()

  def call(module, payload) when is_map(payload) do
    payload
    |> module.build()
    |> DarkEvents.deliver()
  end

  @doc """
  Returns the method atom for the given event `module`.
  """
  @spec module_method_atom(module()) :: atom()
  def module_method_atom(module) when is_atom(module) do
    module
    |> Module.split()
    |> Enum.take(-2)
    |> Enum.join()
    |> Macro.underscore()
    |> String.to_atom()
  end
end
