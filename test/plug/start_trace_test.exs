defmodule StartTracePlugTest do
  use ExUnit.Case

  import RouterHelper

  alias SpandexPhoenix.Plug.StartTrace

  describe "SpandexPhoenix.Plug.StartTrace" do
    test "starts a trace using the default Tracer module by default" do
      refute TestTracer.current_span()
      call(StartTrace, :get, "/", [])
      assert %Spandex.Span{name: "request"} = TestTracer.current_span()
    end

    test "allows the tracer to be overridden" do
      defmodule AnotherTracer do
        use Spandex.Tracer, otp_app: :another_app
      end

      config = [
        adapter: TestAdapter,
        service: :another_service,
        type: :web
      ]

      Application.put_env(:another_app, __MODULE__.AnotherTracer, config)

      refute TestTracer.current_span()
      call(StartTrace, :get, "/", tracer: AnotherTracer)
      assert %Spandex.Span{service: :another_service} = AnotherTracer.current_span()
      refute TestTracer.current_span()
    end

    test "only starts a trace if the provided filter_traces function returns a truthy value" do
      defmodule Filter do
        def filter_traces(conn) do
          conn.method in ~w(DELETE GET POST PUT)
        end
      end

      refute TestTracer.current_span()
      call(StartTrace, :head, "/", filter_traces: &Filter.filter_traces/1)
      refute TestTracer.current_span()
      call(StartTrace, :get, "/", filter_traces: &Filter.filter_traces/1)
      assert {:ok, %Spandex.SpanContext{}} = TestTracer.current_context()
    end

    test "defaults the root span name to 'request'" do
      call(StartTrace, :get, "/", [])
      assert %Spandex.Span{name: "request"} = TestTracer.current_span()
    end

    test "allows the root span name to be overriden" do
      call(StartTrace, :get, "/", span_name: "my root span name")
      assert %Spandex.Span{name: "my root span name"} = TestTracer.current_span()
    end

    test "raises an exception when unexpected options are set" do
      assert_raise ArgumentError, "Opt Validation Error: spam_name - is not allowed (no extra keys)", fn ->
        call(StartTrace, :get, "/", spam_name: "Eggs.Sausage.Spam")
      end
    end
  end
end