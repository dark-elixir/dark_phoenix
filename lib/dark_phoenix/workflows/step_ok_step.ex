defmodule DarkPhoenix.Workflows.StepOkStep do
  @moduledoc """
  Adds `:ok` tuple monad handling step to `Opus.Pipeline`.
  """

  alias DarkPhoenix.DarkWorkflow
  alias DarkPhoenix.Workflows.StepOkStep

  require Opus.Pipeline

  @type step_ok_fun() :: (map() -> any())
  @type wrapped_step_ok_fun() :: (map -> step_ok_result())

  @type step_ok_result() ::
          map()
          | :ok
          | {:ok, map()}
          | {:error, any()}
          | {:error, failed_operation :: atom(), failed_value :: any(), changes_so_far :: map()}

  @type failed_multi() :: %{
          failed_operation: atom(),
          failed_value: any(),
          changes_so_far: map()
        }

  @doc """
  Adds `step_ok` to the `Opus.Pipeline` allowing for `:ok` unboxing
  """
  defmacro step_ok(name, opts \\ []) when is_atom(name) do
    fallback_with =
      quote do
        &apply(unquote(__CALLER__.module), unquote(name), [&1])
      end

    quote do
      Opus.Pipeline.step(
        unquote(name),
        unquote(
          for {key, val} <- Keyword.put_new(opts, :with, fallback_with), into: [] do
            case key do
              :with -> {key, quote(do: StepOkStep.wrap_ok(unquote(val)))}
              _ -> {key, val}
            end
          end
        )
      )
    end
  end

  @doc """
  Handles unboxing `:ok` monads for ease-of-use with `Opus.Pipeline`.
  """
  @spec wrap_ok(step_ok_fun()) :: wrapped_step_ok_fun()
  def wrap_ok(fun) when is_function(fun, 1) do
    fn opus_context ->
      result = fun.(opus_context)
      handle_result(opus_context, result)
    end
  end

  @doc """
  Normalize the result of `:ok` monad steps
  """
  @spec handle_result(DarkWorkflow.opus_context(), step_ok_result()) :: DarkWorkflow.step_result()
  def handle_result(opus_context, :ok) when is_map(opus_context) do
    opus_context
  end

  def handle_result(opus_context, {:ok, results})
      when is_map(opus_context) and is_map(results) do
    Map.merge(opus_context, results)
  end

  def handle_result(opus_context, results) when is_map(opus_context) and is_map(results) do
    Map.merge(opus_context, results)
  end

  def handle_result(opus_context, {:error, failed_operation, failed_value, changes_so_far})
      when is_map(opus_context) and is_atom(failed_operation) and is_map(changes_so_far) do
    {:error,
     %{
       failed_operation: failed_operation,
       failed_value: failed_value,
       changes_so_far: changes_so_far
     }}
  end

  def handle_result(opus_context, {:error, failed_value})
      when is_map(opus_context) do
    {:error, failed_value}
  end
end
