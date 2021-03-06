defmodule SeedParser.Tokenizer do
  @moduledoc false

  alias SeedParser.Normalizer

  # We use integers instead of atoms to take advantage of the jump table
  # optimization
  @number 1
  @punct 2
  @text 3
  @user 4

  @digits '01234556789'
  @spaces '\s\t<>[]_()!*`'
  @punct './:,\n'

  def decode(line) do
    node(line, line, 0, [])
  end

  defp node(<<?<, ?@, ?!, byte, rest::bits>>, original, skip, stack) when byte in @digits do
    number(rest, original, skip + 3, [@user | stack], 1)
  end

  defp node(<<?<, ?@, byte, rest::bits>>, original, skip, stack) when byte in @digits do
    number(rest, original, skip + 2, [@user | stack], 1)
  end

  defp node(<<byte, rest::bits>>, original, skip, stack) when byte in @spaces do
    node(rest, original, skip + 1, stack)
  end

  defp node(<<byte, rest::bits>>, original, skip, stack) when byte in @punct do
    stack = [{:punct, <<byte>>} | stack]
    node(rest, original, skip + 1, stack)
  end

  defp node(<<byte, rest::bits>>, original, skip, stack) when byte in @digits do
    number(rest, original, skip, [@number | stack], 1)
  end

  defp node(<<_, rest::bits>>, original, skip, stack) do
    text(rest, original, skip, [@text | stack], 1)
  end

  defp node(<<>>, _original, _skip, stack) do
    stack
  end

  defp number(<<byte, rest::bits>>, original, skip, stack, len) when byte in @digits do
    number(rest, original, skip, stack, len + 1)
  end

  defp number(<<>>, original, skip, stack, len) do
    value =
      original
      |> binary_part(skip, len)
      |> String.to_integer()

    continue(<<>>, original, skip + len, stack, value)
  end

  defp number(<<_, _::bits>> = rest, original, skip, stack, len) do
    value =
      original
      |> binary_part(skip, len)
      |> String.to_integer()

    continue(rest, original, skip + len, stack, value)
  end

  # final point is often use for abreviations just ignore them
  defp text(<<?., rest::bits>>, original, skip, stack, len) do
    value =
      original
      |> binary_part(skip, len)

    continue(rest, original, skip + len + 1, stack, value)
  end

  defp text(<<byte, _::bits>> = rest, original, skip, stack, len)
       when byte in @spaces or byte in @punct do
    value =
      original
      |> binary_part(skip, len)

    continue(rest, original, skip + len, stack, value)
  end

  defp text(<<_, rest::bits>>, original, skip, stack, len) do
    text(rest, original, skip, stack, len + 1)
  end

  defp text(<<>>, original, skip, stack, len) do
    value =
      original
      |> binary_part(skip, len)

    continue(<<>>, original, skip + len, stack, value)
  end

  defp text_value(rest, original, skip, stack, value) do
    case Normalizer.normalize(value) do
      :text ->
        stack = [{:text, value} | stack]
        node(rest, original, skip, stack)

      {token, value} ->
        stack = [{token, value} | stack]
        node(rest, original, skip, stack)
    end
  end

  defp user_value(<<?>, rest::bits>>, original, skip, stack, value) do
    stack = [{:user, value} | stack]
    node(rest, original, skip + 1, stack)
  end

  defp user_value(rest, original, skip, stack, _value) do
    node(rest, original, skip, stack)
  end

  defp number_value(rest, original, skip, stack, value) do
    stack = [{:number, value} | stack]
    node(rest, original, skip, stack)
  end

  @compile {:inline, continue: 5}
  defp continue(rest, original, skip, stack, value) do
    case stack do
      [@number | stack] ->
        number_value(rest, original, skip, stack, value)

      [@text | stack] ->
        text_value(rest, original, skip, stack, value)

      [@user | stack] ->
        user_value(rest, original, skip, stack, value)
    end
  end
end
