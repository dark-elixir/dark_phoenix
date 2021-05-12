defmodule DarkPhoenix.EventSourcing.CommandResultsTest do
  @moduledoc """
  Test for DarkPhoenix.EventSourcing.CommandResults`.
  """

  use ExUnit.Case, async: true

  alias DarkPhoenix.EventSourcing.CommandContext
  alias DarkPhoenix.EventSourcing.CommandResults
  alias DarkPhoenix.EventSourcing.Shorthand

  @stream_uuid "12354"

  defmodule MockRepoOneAssocPresent do
    @moduledoc false

    @stream_uuid "12354"

    def preload(assoc, [key]) when is_map(assoc) and is_atom(key) do
      %{assoc | key => %{stream_uuid: @stream_uuid}}
    end
  end

  defmodule MockRepoOneAssocNotPresent do
    @moduledoc false

    def preload(assoc, [key]) when is_map(assoc) and is_atom(key) do
      %{assoc | key => nil}
    end
  end

  describe ".cast/1" do
    test "given a context with one loaded target with depth 1 and {:ok, command_results}" do
      [path1] = [:path]

      target = %Shorthand{name: :resource, path: [path1]}
      context = %CommandContext{targets: [target]}
      command_result = {:ok, %{path1 => %{stream_uuid: @stream_uuid}}}

      assert CommandResults.cast(context, command_result) == %{
               context
               | ok?: true,
                 targets: [%{target | valid?: true, stream_uuid: @stream_uuid}]
             }
    end

    test "given a context with one loaded target with depth 2 and {:ok, command_results}" do
      [path1, path2] = [:path1, :path2]

      target = %Shorthand{name: :resource, path: [path1, path2]}
      context = %CommandContext{targets: [target]}
      command_result = {:ok, %{path1 => %{path2 => %{stream_uuid: @stream_uuid}}}}

      assert CommandResults.cast(context, command_result) == %{
               context
               | ok?: true,
                 targets: [%{target | valid?: true, stream_uuid: @stream_uuid}]
             }
    end

    test "given a context with one unloaded but present target with depth 2 and {:ok, command_results}" do
      [path1, path2] = [:path1, :path2]

      target = %Shorthand{name: :resource, path: [path1, path2], preload: true}
      context = %CommandContext{targets: [target], repo: MockRepoOneAssocPresent}
      command_result = {:ok, %{path1 => %{path2 => %Ecto.Association.NotLoaded{}}}}

      assert CommandResults.cast(context, command_result) == %{
               context
               | ok?: true,
                 targets: [%{target | valid?: true, stream_uuid: @stream_uuid}]
             }
    end

    test "given a context with one unloaded and not present target with depth 1 and {:ok, command_results}" do
      [path1, path2] = [:path1, :path2]

      target = %Shorthand{name: :resource, path: [path1, path2]}
      context = %CommandContext{targets: [target], repo: MockRepoOneAssocNotPresent}
      command_result = {:ok, %{path1 => %Ecto.Association.NotLoaded{}}}

      assert CommandResults.cast(context, command_result) == %{
               context
               | ok?: true,
                 targets: [
                   %{target | valid?: false, errors: [{:assoc_not_loaded, [:path1]}]}
                 ]
             }
    end

    test "given a context with one unloaded and not present target with depth 1 and required and {:ok, command_results}" do
      [path1, path2] = [:path1, :path2]

      target = %Shorthand{name: :resource, path: [path1, path2], required: true}
      context = %CommandContext{targets: [target], repo: MockRepoOneAssocNotPresent}
      command_result = {:ok, %{path1 => %Ecto.Association.NotLoaded{}}}

      assert CommandResults.cast(context, command_result) == %{
               context
               | ok?: true,
                 targets: [
                   %{
                     target
                     | valid?: false,
                       errors: [{:assoc_not_loaded, [:path1]}, {:required, [:resource]}]
                   }
                 ]
             }
    end

    test "given a context with one unloaded and not present target with depth 2 and {:ok, command_results}" do
      [path1, path2] = [:path1, :path2]

      target = %Shorthand{name: :resource, path: [path1, path2]}
      context = %CommandContext{targets: [target], repo: MockRepoOneAssocNotPresent}
      command_result = {:ok, %{path1 => %{path2 => %Ecto.Association.NotLoaded{}}}}

      assert CommandResults.cast(context, command_result) == %{
               context
               | ok?: true,
                 targets: [
                   %{target | valid?: false, errors: [{:assoc_not_loaded, [:path1, :path2]}]}
                 ]
             }
    end

    test "given a context with one loaded target with depth 3 and {:ok, command_results}" do
      [path1, path2, path3] = [:path1, :path2, :path3]

      target = %Shorthand{name: :resource, path: [path1, path2, path3]}
      context = %CommandContext{targets: [target]}
      command_result = {:ok, %{path1 => %{path2 => %{path3 => %{stream_uuid: @stream_uuid}}}}}

      assert CommandResults.cast(context, command_result) == %{
               context
               | ok?: true,
                 targets: [%{target | valid?: true, stream_uuid: @stream_uuid}]
             }
    end

    test "given a context with one unloaded and not present target with depth 1 and 1 link and {:ok, command_results}" do
      [path1, path2] = [:path1, :path2]

      target = %Shorthand{name: :resource, path: [path1, path2]}
      link_to_stream1 = %Shorthand{path: [path1]}

      context = %CommandContext{
        targets: [target],
        link_to_streams: [link_to_stream1],
        repo: MockRepoOneAssocNotPresent
      }

      command_result = {:ok, %{path1 => %Ecto.Association.NotLoaded{}}}

      assert CommandResults.cast(context, command_result) == %{
               context
               | ok?: true,
                 targets: [
                   %{target | valid?: false, errors: [{:assoc_not_loaded, [:path1]}]}
                 ],
                 link_to_streams: [
                   %{
                     link_to_stream1
                     | valid?: false,
                       errors: [{:assoc_not_loaded, [:path1]}, {:target_invalid, [:resource]}]
                   }
                 ]
             }
    end

    test "given a context with one unloaded and not present target with depth 1 and 1 required link and {:ok, command_results}" do
      [path1, path2] = [:path1, :path2]

      target = %Shorthand{name: :resource, path: [path1, path2]}
      link_to_stream1 = %Shorthand{path: [path1], required: true}

      context = %CommandContext{
        targets: [target],
        link_to_streams: [link_to_stream1],
        repo: MockRepoOneAssocNotPresent
      }

      command_result = {:ok, %{path1 => %Ecto.Association.NotLoaded{}}}

      assert CommandResults.cast(context, command_result) == %{
               context
               | ok?: true,
                 targets: [
                   %{target | valid?: false, errors: [{:assoc_not_loaded, [:path1]}]}
                 ],
                 link_to_streams: [
                   %{
                     link_to_stream1
                     | valid?: false,
                       errors: [{:assoc_not_loaded, [:path1]}, {:target_invalid, [:resource]}]
                   }
                 ]
             }
    end

    test "given a context with one unloaded and not present target with depth 2 and 1 link {:ok, command_results}" do
      [path1, path2] = [:path1, :path2]

      target = %Shorthand{name: :resource, path: [path1, path2]}
      link_to_stream1 = %Shorthand{path: [path1]}

      context = %CommandContext{
        targets: [target],
        link_to_streams: [link_to_stream1],
        repo: MockRepoOneAssocNotPresent
      }

      command_result =
        {:ok, %{path1 => %{:stream_uuid => @stream_uuid, path2 => %Ecto.Association.NotLoaded{}}}}

      assert CommandResults.cast(context, command_result) == %{
               context
               | ok?: true,
                 targets: [
                   %{target | valid?: false, errors: [{:assoc_not_loaded, [:path1, :path2]}]}
                 ],
                 link_to_streams: [
                   %{
                     link_to_stream1
                     | valid?: false,
                       stream_uuid: @stream_uuid,
                       errors: [{:target_invalid, [:resource]}]
                   }
                 ]
             }
    end

    test "given an empty context and {:ok, command_results}" do
      context = %CommandContext{}
      command_result = {:ok, %{}}
      assert CommandResults.cast(context, command_result) == %{context | ok?: true}
    end

    test "given an empty context and {:error, command_results}" do
      context = %CommandContext{}
      command_result = {:error, %{}}
      assert CommandResults.cast(context, command_result) == %{context | ok?: false}
    end

    test "given an empty context and {:error, failed_operation, failed_value, changes_so_far}" do
      context = %CommandContext{}
      command_result = {:error, :failed_operation, %{}, %{}}
      assert CommandResults.cast(context, command_result) == %{context | ok?: false}
    end
  end

  describe ".hydrate/1" do
    test "given a context with one loaded target with depth 1 and {:ok, command_results}" do
      [path1] = [:path]

      target = %Shorthand{name: :resource, path: [path1]}
      context = %CommandContext{targets: [target]}
      command_result = {:ok, %{path1 => %{stream_uuid: @stream_uuid}}}

      assert CommandResults.hydrate(context, command_result) == %{
               context
               | ok?: true,
                 targets: [%{target | valid?: true, stream_uuid: @stream_uuid}]
             }
    end

    test "given a context with one loaded target with depth 2 and {:ok, command_results}" do
      [path1, path2] = [:path1, :path2]

      target = %Shorthand{name: :resource, path: [path1, path2]}
      context = %CommandContext{targets: [target]}
      command_result = {:ok, %{path1 => %{path2 => %{stream_uuid: @stream_uuid}}}}

      assert CommandResults.hydrate(context, command_result) == %{
               context
               | ok?: true,
                 targets: [%{target | valid?: true, stream_uuid: @stream_uuid}]
             }
    end

    test "given a context with one unloaded but present target with depth 2 and {:ok, command_results}" do
      [path1, path2] = [:path1, :path2]

      target = %Shorthand{name: :resource, path: [path1, path2], preload: true}
      context = %CommandContext{targets: [target], repo: MockRepoOneAssocPresent}
      command_result = {:ok, %{path1 => %{path2 => %Ecto.Association.NotLoaded{}}}}

      assert CommandResults.hydrate(context, command_result) == %{
               context
               | ok?: true,
                 targets: [%{target | valid?: true, stream_uuid: @stream_uuid}]
             }
    end

    test "given a context with one unloaded and not present target with depth 1 and {:ok, command_results}" do
      [path1, path2] = [:path1, :path2]

      target = %Shorthand{name: :resource, path: [path1, path2]}
      context = %CommandContext{targets: [target], repo: MockRepoOneAssocNotPresent}
      command_result = {:ok, %{path1 => %Ecto.Association.NotLoaded{}}}

      assert CommandResults.hydrate(context, command_result) == %{
               context
               | ok?: true,
                 targets: [%{target | valid?: false, errors: [{:assoc_not_loaded, [:path1]}]}]
             }
    end

    test "given a context with one unloaded and not present target with depth 2 and {:ok, command_results}" do
      [path1, path2] = [:path1, :path2]

      target = %Shorthand{name: :resource, path: [path1, path2]}
      context = %CommandContext{targets: [target], repo: MockRepoOneAssocNotPresent}
      command_result = {:ok, %{path1 => %{path2 => %Ecto.Association.NotLoaded{}}}}

      assert CommandResults.hydrate(context, command_result) == %{
               context
               | ok?: true,
                 targets: [
                   %{target | valid?: false, errors: [{:assoc_not_loaded, [:path1, :path2]}]}
                 ]
             }
    end

    test "given a context with one loaded target with depth 3 and {:ok, command_results}" do
      [path1, path2, path3] = [:path1, :path2, :path3]

      target = %Shorthand{name: :resource, path: [path1, path2, path3]}
      context = %CommandContext{targets: [target]}
      command_result = {:ok, %{path1 => %{path2 => %{path3 => %{stream_uuid: @stream_uuid}}}}}

      assert CommandResults.hydrate(context, command_result) == %{
               context
               | ok?: true,
                 targets: [%{target | valid?: true, stream_uuid: @stream_uuid}]
             }
    end

    test "given a context with one unloaded and not present target with depth 1 and 1 link and {:ok, command_results}" do
      [path1, path2] = [:path1, :path2]

      target = %Shorthand{name: :resource, path: [path1, path2]}
      link_to_stream1 = %Shorthand{path: [path1]}

      context = %CommandContext{
        targets: [target],
        link_to_streams: [link_to_stream1],
        repo: MockRepoOneAssocNotPresent
      }

      command_result = {:ok, %{path1 => %Ecto.Association.NotLoaded{}}}

      assert CommandResults.hydrate(context, command_result) == %{
               context
               | ok?: true,
                 targets: [%{target | valid?: false, errors: [{:assoc_not_loaded, [:path1]}]}],
                 link_to_streams: [
                   %{link_to_stream1 | valid?: false, errors: [{:assoc_not_loaded, [:path1]}]}
                 ]
             }
    end

    test "given a context with one unloaded and not present target with depth 2 and 1 link {:ok, command_results}" do
      [path1, path2] = [:path1, :path2]

      target = %Shorthand{name: :resource, path: [path1, path2]}
      link_to_stream1 = %Shorthand{path: [path1]}

      context = %CommandContext{
        targets: [target],
        link_to_streams: [link_to_stream1],
        repo: MockRepoOneAssocNotPresent
      }

      command_result =
        {:ok, %{path1 => %{:stream_uuid => @stream_uuid, path2 => %Ecto.Association.NotLoaded{}}}}

      assert CommandResults.hydrate(context, command_result) == %{
               context
               | ok?: true,
                 targets: [
                   %{target | valid?: false, errors: [{:assoc_not_loaded, [:path1, :path2]}]}
                 ],
                 link_to_streams: [
                   %{link_to_stream1 | valid?: true, stream_uuid: @stream_uuid}
                 ]
             }
    end

    test "given an empty context and {:ok, command_results}" do
      context = %CommandContext{}
      command_result = {:ok, %{}}
      assert CommandResults.hydrate(context, command_result) == %{context | ok?: true}
    end

    test "given an empty context and {:error, command_results}" do
      context = %CommandContext{}
      command_result = {:error, %{}}
      assert CommandResults.hydrate(context, command_result) == %{context | ok?: false}
    end

    test "given an empty context and {:error, failed_operation, failed_value, changes_so_far}" do
      context = %CommandContext{}
      command_result = {:error, :failed_operation, %{}, %{}}
      assert CommandResults.hydrate(context, command_result) == %{context | ok?: false}
    end
  end
end
