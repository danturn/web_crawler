defmodule ProcessKiller do
  def terminate(pid) do
    Process.monitor(pid)
    Process.exit(pid, :kill)

    receive do
      {:DOWN, _, _, ^pid, :noproc} -> :ok
    after
      1000 ->
        {:error, "Process: #{inspect(pid)} was not killed!"}
    end
  end
end
