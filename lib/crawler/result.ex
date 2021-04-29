defmodule Crawler.Result do
  def and_then({:ok, result}, fun), do: fun.(result)
  def and_then(:ok, fun), do: fun.()
  def and_then(result, _), do: result

  def otherwise({:error, error}, fun), do: fun.(error)
  def otherwise(result, _), do: result
end
