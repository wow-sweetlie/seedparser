defmodule SeedParser.Decoder do
  @moduledoc false
  require Logger

  alias SeedParser.Tokenizer

  @elements [:date, :seeds, :time, :type]
  @type type ::
          :starlight_rose
          | :mix
          | :foxflower
  @type seeds :: integer

  def decode(data) do
    today = Date.utc_today()
    decode(data, today)
  end

  def decode(data, today) do
    data
    |> String.split("\n")
    |> decode_line([], today)
    |> Enum.into(%{})
    |> validity_check(data)
  end

  def format(data) do
    Regex.replace(~r/\n?\s*(```\w*)\s*\n?/, data, "\n\\1\n")
  end

  defp validity_check(metadata, data) do
    case metadata
         |> Map.to_list()
         |> has_all_elements? do
      true ->
        {:ok, struct(%SeedParser{content: data}, metadata)}

      false ->
        missing_error(@elements, metadata)
    end
  end

  defp missing_error([element | rest], metadata) do
    case metadata |> Map.has_key?(element) do
      true ->
        missing_error(rest, metadata)

      false ->
        {:error, "could not parse #{element}"}
    end
  end

  defp decode_line([], stack, _), do: stack

  defp decode_line([line | lines], stack, today) do
    stack =
      line
      |> Tokenizer.decode()
      |> decode_tokens(stack, today)

    decode_line(lines, stack, today)
  end

  defp decode_tokens([], stack, _), do: stack

  defp decode_tokens([{:type, type}, {:number, seeds} | rest], stack, today) do
    case stack |> Keyword.fetch(:type) do
      {:ok, _} ->
        decode_tokens(rest, stack, today)

      :error ->
        stack = [{:type, type}, {:seeds, seeds} | stack]
        decode_tokens(rest, stack, today)
    end
  end

  defp decode_tokens(
         [{:number, year}, {:punct, "/"}, {:number, month}, {:punct, "/"}, {:number, day} | rest],
         stack,
         today
       ) do
    case stack |> Keyword.fetch(:date) do
      {:ok, _} ->
        decode_tokens(rest, stack, today)

      :error ->
        stack = stack |> insert_if_valid_date(year, month, day, today)
        continue(rest, stack, today)
    end
  end

  defp decode_tokens(
         [
           {:number, month},
           {:punct, "."},
           {:number, day},
           {:punct, ","},
           {:weekday, _weekday} | rest
         ],
         stack,
         today
       ) do
    case stack |> Keyword.fetch(:date) do
      {:ok, _} ->
        decode_tokens(rest, stack, today)

      :error ->
        stack = stack |> insert_if_valid_date(today.year, month, day, today)
        continue(rest, stack, today)
    end
  end

  defp decode_tokens([{:number, day}, {:month, month} | rest], stack, today) do
    case stack |> Keyword.fetch(:date) do
      {:ok, _} ->
        decode_tokens(rest, stack, today)

      :error ->
        stack = stack |> insert_if_valid_date(today.year, month, day, today)
        continue(rest, stack, today)
    end
  end

  defp decode_tokens([{:number, minute}, {:punct, ":"}, {:number, hour} | rest], stack, today) do
    case stack |> Keyword.fetch(:time) do
      {:ok, _} ->
        decode_tokens(rest, stack, today)

      :error ->
        stack = stack |> insert_if_valid_time(hour, minute)
        continue(rest, stack, today)
    end
  end

  defp decode_tokens([_any | tokens], stack, today) do
    decode_tokens(tokens, stack, today)
  end

  defp insert_if_valid_time(stack, hour, minute) do
    case Time.new(hour, minute, 0) do
      {:ok, time} ->
        [{:time, time} | stack]

      _ ->
        stack
    end
  end

  defp insert_if_valid_date(stack, year, month, day, today) do
    fullyear =
      case year do
        thisyear when thisyear < 2000 ->
          thisyear + 2000

        thisyear ->
          thisyear
      end

    case Date.new(fullyear, month, day) do
      {:ok, date} ->
        case Date.diff(date, today) do
          days when days in -7..45 ->
            [{:date, date} | stack]

          _ ->
            stack
        end
    end
  end

  defp has_all_elements?(stack) do
    @elements
    |> Enum.all?(fn element -> stack |> Keyword.has_key?(element) end)
  end

  defp continue(rest, stack, today) do
    case stack |> has_all_elements? do
      true ->
        stack

      false ->
        decode_tokens(rest, stack, today)
    end
  end
end
