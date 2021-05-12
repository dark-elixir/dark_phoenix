defmodule DarkPhoenix.Command.CommandBehaviour do
  @moduledoc """
  This module provides behaviours for commands
  """

  alias DarkPhoenix.Command

  # alias Oban.Job

  @doc """
  Initializes a `DarkPhoenix.Command` struct with `opts` from the use macro
  """
  @callback new() :: Command.t()

  @doc """
  Initializes a `DarkPhoenix.Command` struct with `context` and `opts` from the use macro.
  """
  @callback new(Command.context()) :: Command.t()

  @doc """
  Creates a `DarkPhoenix.Command` struct
  """
  @callback build() :: Command.t()

  @doc """
  Creates a `DarkPhoenix.Command` struct from `context`.
  """
  @callback build(Command.context()) :: Command.t()

  # @doc """
  # Issues a job
  # """
  # @callback perform(Job.args(), Job.t()) :: Command.perform_result()

  @doc """
  Issues a `command` to run and return the command monad.
  """
  @callback run(Command.context()) :: Command.run_result()

  # @callback run(Command.context()) :: {:ok, any()} | {:error, any()}

  @doc """
  Issues a `command` to run syncronously
  """
  @callback run_sync(Command.context()) :: Command.run_sync_result()

  # @callback run_sync(Command.context()) :: {:ok, any()} | {:error, any()}

  @doc """
  Issues a `command` to run asyncronously
  """
  @callback run_async(Command.context(), task_opts :: Keyword.t()) :: Command.run_async_result()
  # @callback run_async(Command.context(), task_opts :: Keyword.t()) :: Task.t()
end
