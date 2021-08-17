defmodule UpdateChecker do
  @file_path "./output.log"
  def debug_log(message) do
    File.write(@file_path, message <> "\n", [:append])
  end
end

UpdateChecker.debug_log("do_update.exs 1")
[dependency_name | credentials] = System.argv()
UpdateChecker.debug_log("do_update.exs 2")

grouped_creds = Enum.reduce credentials, [], fn cred, acc ->
  if List.last(acc) == nil || List.last(acc)[:token] do
    List.insert_at(acc, -1, %{ organization: cred })
  else
    { item, acc } = List.pop_at(acc, -1)
    item = Map.put(item, :token, cred)
    List.insert_at(acc, -1, item)
  end
end
UpdateChecker.debug_log("do_update.exs 3")

Enum.each grouped_creds, fn cred ->
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
end
UpdateChecker.debug_log("do_update.exs 4")

# dependency atom
dependency = String.to_atom(dependency_name)
UpdateChecker.debug_log("do_update.exs 5")

# Fetch dependencies that needs updating
{dependency_lock, rest_lock} = Map.split(Mix.Dep.Lock.read(), [dependency])
UpdateChecker.debug_log("do_update.exs 6")
Mix.Dep.Fetcher.by_name([dependency_name], dependency_lock, rest_lock, [])
UpdateChecker.debug_log("do_update.exs 7")

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
UpdateChecker.debug_log("do_update.exs 8")

lockfile_content =
  "mix.lock"
  |> File.read()
  |> :erlang.term_to_binary()
UpdateChecker.debug_log("do_update.exs 9")

IO.write(:stdio, lockfile_content)
UpdateChecker.debug_log("do_update.exs 10")
