defmodule UpdateChecker do
  @file_path "./output.log"
  def debug_log(message) do
    File.write(@file_path, message <> "\n", [:append])
  end

  def run(dependency_name, credentials) do
    debug_log("check_update.exs run 1")
    set_credentials(credentials)
    debug_log("check_update.exs run 2")

    # Update the lockfile in a session that we can time out
    task = Task.async(fn -> do_resolution(dependency_name) end)
    debug_log("check_update.exs run 3 (sleeping 1 second)")
#    Process.sleep(1000)
    case Task.yield(task, 30000) || Task.shutdown(task) do
#    case Task.await(task, 30000) do
      {:ok, {:ok, :resolution_successful}} ->
        debug_log("check_update.exs run 4.1")
        # Read the new lock
        {updated_lock, _updated_rest_lock} =
          Map.split(Mix.Dep.Lock.read(), [String.to_atom(dependency_name)])
        debug_log("check_update.exs run 4.2 updated_lock:\n#{inspect updated_lock}")

        # Get the new dependency version
        version =
          updated_lock
          |> Map.get(String.to_atom(dependency_name))
          |> elem(2)
        debug_log("check_update.exs run 4.3 version: #{version}")
        {:ok, version}

      {:ok, {:error, error}} ->
        debug_log("check_update.exs run 5.1")
        {:error, error}

      nil ->
        debug_log("check_update.exs run 6.1")
        {:error, :dependency_resolution_timed_out}

      {:exit, reason} ->
        debug_log("check_update.exs run 7.1")
        {:error, reason}
    end
  end

  def set_credentials(credentials) do
    credentials
    |> Enum.reduce([], fn cred, acc ->
      if List.last(acc) == nil || List.last(acc)[:token] do
        List.insert_at(acc, -1, %{organization: cred})
      else
        {item, acc} = List.pop_at(acc, -1)
        item = Map.put(item, :token, cred)
        List.insert_at(acc, -1, item)
      end
    end)
    |> Enum.each(fn cred ->
      hexpm = Hex.Repo.get_repo("hexpm")

      repo = %{
        url: hexpm.url <> "/repos/#{cred.organization}",
        public_key: nil,
        auth_key: cred.token
      }

      Hex.Config.read()
      |> Hex.Config.read_repos()
      |> Map.put("hexpm:#{cred.organization}", repo)
      |> Hex.Config.update_repos()
    end)
  end

  defp do_resolution(dependency_name) do
    debug_log("check_update.exs do_resolution 1")
    # Fetch dependencies that needs updating
    {dependency_lock, rest_lock} =
      Map.split(Mix.Dep.Lock.read(), [String.to_atom(dependency_name)])
    debug_log("check_update.exs do_resolution 2")

    try do
      Mix.Dep.Fetcher.by_name([dependency_name], dependency_lock, rest_lock, [])
      debug_log("check_update.exs do_resolution 3")
      {:ok, :resolution_successful}
    rescue
      error ->
        debug_log("check_update.exs do_resolution 4")
        {:error, error}
    end
  end
end

[dependency_name | credentials] = System.argv()

UpdateChecker.debug_log("check_update.exs fetching deps")
System.cmd(
  "mix",
  [
    "deps.get",
    "--no-compile",
    "--no-elixir-version-check",
  ],
  [
    env: %{
      "MIX_EXS" => nil,
      "MIX_LOCK" => nil,
      "MIX_DEPS" => nil
    }
  ]
)
UpdateChecker.debug_log("check_update.exs done fetching deps")

case UpdateChecker.run(dependency_name, credentials) do
  {:ok, version} ->
    UpdateChecker.debug_log("check_update.exs return OK: #{version}")
    #version = version
    version = :erlang.term_to_binary({:ok, version})
    IO.write(:stdio, version)

  {:error, %Hex.Version.InvalidRequirementError{} = error}  ->
    UpdateChecker.debug_log("check_update.exs return ERROR 1")
#    result = {:error, "Invalid requirement: #{error.requirement}"}
    result = :erlang.term_to_binary({:error, "Invalid requirement: #{error.requirement}"})
    IO.write(:stdio, result)

  {:error, %Mix.Error{} = error} ->
    UpdateChecker.debug_log("check_update.exs return ERROR 2")
#    result = {:error, "Dependency resolution failed: #{error.message}"}
    result = :erlang.term_to_binary({:error, "Dependency resolution failed: #{error.message}"})
    IO.write(:stdio, result)

  {:error, :dependency_resolution_timed_out} ->
    UpdateChecker.debug_log("check_update.exs return ERROR 3")
    # We do nothing here because Hex is already printing out a message in stdout
    nil

  {:error, error} ->
    UpdateChecker.debug_log("check_update.exs return ERROR 4")
#    result = {:error, "Unknown error in check_update: #{inspect(error)}"}
    result = :erlang.term_to_binary({:error, "Unknown error in check_update: #{inspect(error)}"})
    IO.write(:stdio, result)
end

#UpdateChecker.debug_log("dependency_name: #{dependency_name}")
#UpdateChecker.debug_log("before set credentials: #{inspect credentials}")
#UpdateChecker.set_credentials(credentials)
#UpdateChecker.debug_log("after set credentials")
#IO.write(:erlang.term_to_binary({:ok, "1.1.4"}))

