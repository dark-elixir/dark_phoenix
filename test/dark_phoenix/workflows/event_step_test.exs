defmodule DarkPhoenix.ExampleEvent do
  @moduledoc false
  defmodule SmsNotification do
    @moduledoc false
  end

  defmodule EmailNotification do
    @moduledoc false
  end

  defmodule SlackNotification do
    @moduledoc false
  end
end

defmodule DarkPhoenix.Workflows.EventStepTest do
  @moduledoc """
  Tests for `DarkPhoenix.Workflows.EventStep`.
  """

  use ExUnit.Case, async: true

  alias DarkPhoenix.Workflows.EventStep

  describe ".module_method_atom/1" do
    test "given :DarkPhoenix.ExampleEvent.SmsNotification" do
      module = DarkPhoenix.ExampleEvent.SmsNotification

      assert EventStep.module_method_atom(module) == :example_event_sms_notification
    end

    test "given :DarkPhoenix.ExampleEvent.EmailNotification" do
      module = DarkPhoenix.ExampleEvent.EmailNotification

      assert EventStep.module_method_atom(module) == :example_event_email_notification
    end

    test "given :DarkPhoenix.ExampleEvent.SlackNotification" do
      module = DarkPhoenix.ExampleEvent.SlackNotification

      assert EventStep.module_method_atom(module) == :example_event_slack_notification
    end
  end
end
