defmodule ExceptionTest do
  use ExUnit.Case
  use Plug.Test

  defmodule TestException do
    defexception plug_status: 403, message: "oops"
  end

  defmodule ErrorRaisingPlug do
    defmacro __using__(_env) do
      quote do
        def call(conn, _opts) do
          raise Plug.Conn.WrapperError, conn: conn,
          kind: :error, stack: [],
          reason: TestException.exception([])
        end
      end
    end
  end

  defmodule TestPlug do
    use NewRelixir.Plug.Exception
    use ErrorRaisingPlug
  end

  defmodule FakeReporter do
    def record_error(transaction, exception) do
      send self(), {:record_error, {transaction, exception}}
    end
  end

  setup do
    Application.put_env(:new_relixir, :reporter, FakeReporter)
  end

  test "Raising an error on failure" do
    conn = conn(:get, "/path")

    assert_raise Plug.Conn.WrapperError, fn ->
      TestPlug.call(conn, [])
    end

    assert_received {:record_error, {"path#GET", {:error, %TestException{}}}}
  end

  test "Includes request data in report" do
    conn = conn(:get, "/some_path")

    catch_error TestPlug.call(conn, [])
    assert_received {:record_error, {transaction, {:error, %TestException{}}}}

    assert transaction == "some_path#GET"
  end
end
