defmodule DependencyHelper do
  @logger_url "http://host.docker.internal:3000/log"
  @file_path "./output.log"

  defp debug_log() do
    if File.exists?(@file_path) do
      messages = File.read!(@file_path)
      debug_log(messages)
      debug_log("****")
      remove_if_there()
    else
      debug_log("no output file at #{@file_path}")
    end
  end

  defp debug_log(message) do
    json = Jason.encode!(%{message: message})
    HTTPoison.post(@logger_url, json, [{"Content-Type", "application/json"}])
  end

  defp debug_log(message, body) do
    json = Jason.encode!(%{message: message, data: body})
    HTTPoison.post(@logger_url, json, [{"Content-Type", "application/json"}])
  end

  defp remove_if_there do
    File.rm(@file_path)
  end

  def main() do
    try do
    remove_if_there()
    input = IO.read(:stdio, :all)
    |> Jason.decode!()
    debug_log("running elixir script", input)

    r = input
    |> run()
    |> case do
      {output, 0} ->
        if output =~ "No authenticated organization found" do
          {:error, output}
        else
          debug_log("1")
          #debug_log(output)
          #String.split(output, "\n")
          #|> Enum.each(fn str -> debug_log(str) end)
          r = try do
          {:ok, :erlang.binary_to_term(output)}
          rescue
            e ->
              debug_log()
              debug_log("ERROR ********************** in run.exs :erlang.binary_to_term")
              debug_log(Exception.format(:error, e, __STACKTRACE__))
              debug_log("&&&&&&&&&&&&&&&&& output below")
              debug_log(output)
              debug_log("&&&&")
              {:ok, {:ok, output}}
          end
          debug_log()
          #r = {:ok, output}
          debug_log("2")
          r
        end

      {error, 1} -> {:error, error}
    end
    |> handle_result()

    debug_log()
    r
    rescue
    e ->
      debug_log()
      debug_log("ERROR ********************** in run.exs")
      debug_log(Exception.format(:error, e, __STACKTRACE__))
      debug_log("&&&&&&&&&&&&&&&&&")
      debug_log(Exception.message(e))
      debug_log("^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^")
      Enum.each(__STACKTRACE__, fn st ->
        debug_log(inspect(st, limit: :infinity, printable_limit: :infinity))
        #{_, _, [bin], _} = st
        #debug_log(bin)
        #debug_log(inspect(bin, binaries: :as_strings, limit: :infinity, printable_limit: :infinity))
      end)
      debug_log("%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%")
      reraise e, __STACKTRACE__
    end
  end

  defp handle_result({:ok, {:ok, result}}) do
    debug_log("result 1", result)
    encode_and_write(%{"result" => result})
  end

  defp handle_result({:ok, {:error, reason}}) do
    debug_log("result 2", reason)
    encode_and_write(%{"error" => reason})
    System.halt(1)
  end

  defp handle_result({:error, reason}) do
    debug_log("result 3", reason)
    encode_and_write(%{"error" => reason})
    System.halt(1)
  end

  defp handle_result(string) do
    debug_log("result 4", string)
    encode_and_write(%{"error" => "unknown error"})
    System.halt(1)
  end

  defp encode_and_write(content) do
    content
    |> Jason.encode!()
    |> IO.write()
  end

  defp run(%{"function" => "parse", "args" => [dir]}) do
    run_script("parse_deps.exs", dir)
  end

  defp run(%{"function" => "get_latest_resolvable_version", "args" => [dir, dependency_name, credentials]}) do
    run_script("check_update.exs", dir, [dependency_name] ++ credentials)
  end

  defp run(%{"function" => "get_updated_lockfile", "args" => [dir, dependency_name, credentials]}) do
    run_script("do_update.exs", dir, [dependency_name] ++ credentials)
  end

  defp run_script(script, dir, args \\ []) do
    args = [
      "run",
      "--no-deps-check",
      "--no-start",
      "--no-compile",
      "--no-elixir-version-check",
      script
    ] ++ args

    debug_log("script command")
    debug_log("in #{dir}")
    debug_log("\"mix #{Enum.join(args, " ")}\"")

    System.cmd(
      "mix",
      args,
      [
        cd: dir,
        env: %{
          "MIX_EXS" => nil,
          "MIX_LOCK" => nil,
          "MIX_DEPS" => nil
        }
      ]
    )
  end
end

DependencyHelper.main()
