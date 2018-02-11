defmodule SeedParserDecoderTest do
  @moduledoc false

  use ExUnit.Case, async: true
  doctest SeedParser.Decoder
  alias SeedParser.Decoder

  test "thalipedes template" do
    {:ok, text} = File.read("./test/fixtures/thalipedes.md")

    metadata = %SeedParser{
      date: ~D[2018-01-01],
      time: ~T[22:00:00],
      type: :mix,
      seeds: 60
    }

    today = ~D[2018-01-01]

    assert Decoder.decode(text, today: today) == {:ok, metadata}
  end

  test "format" do
    text = "text ```md text again ```"
    output = "text\n```md\ntext again\n```\n"
    assert Decoder.format(text) == output

    text = "```md text ``````md text again ```"
    output = "\n```md\ntext\n```\n\n```md\ntext again\n```\n"
    assert Decoder.format(text) == output
  end

  test "sholenar template" do
    {:ok, text} = File.read("./test/fixtures/sholenar.md")

    metadata = %SeedParser{
      date: ~D[2018-01-22],
      time: ~T[21:00:00],
      seeds: 100,
      type: :mix
    }

    today = ~D[2018-01-01]

    assert Decoder.decode(text, today: today) == {:ok, metadata}
  end

  test "sholenar template (us version)" do
    {:ok, text} = File.read("./test/fixtures/us_date.md")

    metadata = %SeedParser{
      date: ~D[2018-01-22],
      time: ~T[21:00:00],
      seeds: 100,
      type: :mix
    }

    today = ~D[2018-01-01]

    assert Decoder.decode(text, today: today, date: :us) == {:ok, metadata}
  end
end
