defmodule DarkPhoenix.EventSourcing.ShorthandTest do
  @moduledoc """
  Test for DarkPhoenix.EventSourcing.Shorthand`.
  """

  use ExUnit.Case, async: true

  alias DarkPhoenix.EventSourcing.Shorthand

  describe ".parse_opts/1" do
    test "given mixed target and link_to_streams with tuple syntax" do
      opts = [
        targets: [
          email_submission: {:no_stream, [required: true]}
        ],
        link_to_streams: [
          from_user: {:any_version, [preload: true]},
          broker_org: {:any_version, [preload: true]},
          funder_org: {:any_version, []}
        ]
      ]

      assert Shorthand.parse_opts(opts) == %{
               targets: [
                 %Shorthand{
                   type: :target,
                   name: :email_submission,
                   path: [:email_submission],
                   version: :no_stream,
                   required: true,
                   preload: true,
                   preloads: [:from_user, :broker_org, :funder_org]
                 }
               ],
               link_to_streams: [
                 %Shorthand{
                   type: :link,
                   name: :from_user,
                   path: [:from_user],
                   target_path: [:email_submission],
                   version: :any_version,
                   preload: true
                 },
                 %Shorthand{
                   type: :link,
                   name: :broker_org,
                   path: [:broker_org],
                   target_path: [:email_submission],
                   version: :any_version,
                   preload: true
                 },
                 %Shorthand{
                   type: :link,
                   name: :funder_org,
                   path: [:funder_org],
                   target_path: [:email_submission],
                   version: :any_version
                 }
               ]
             }
    end

    test "given mixed target and link_to_streams with list syntax" do
      opts = [
        targets: [email_submission: [version: :no_stream]],
        link_to_streams: [
          from_user: [],
          broker_org: [:no_stream, required: true],
          funder_org: [required: false]
        ]
      ]

      assert Shorthand.parse_opts(opts) == %{
               link_to_streams: [
                 %Shorthand{
                   type: :link,
                   name: :from_user,
                   path: [:from_user],
                   target_path: [:email_submission],
                   version: :stream_exists
                 },
                 %Shorthand{
                   type: :link,
                   name: :broker_org,
                   path: [:broker_org],
                   target_path: [:email_submission],
                   version: :no_stream,
                   required: true
                 },
                 %Shorthand{
                   type: :link,
                   name: :funder_org,
                   path: [:funder_org],
                   target_path: [:email_submission],
                   version: :stream_exists
                 }
               ],
               targets: [
                 %Shorthand{
                   type: :target,
                   name: :email_submission,
                   path: [:email_submission],
                   version: :no_stream,
                   required: true,
                   preload: true,
                   preloads: [:from_user, :broker_org, :funder_org]
                 }
               ]
             }
    end

    test "given more than one target" do
      opts = [
        targets: [
          from_user: [],
          broker_org: [:no_stream, required: true],
          funder_org: [required: false]
        ]
      ]

      assert_raise ArgumentError, fn ->
        Shorthand.parse_opts(opts)
      end
    end

    test "given empty list" do
      opts = []

      assert Shorthand.parse_opts(opts) == %{
               targets: [],
               link_to_streams: []
             }
    end
  end
end
