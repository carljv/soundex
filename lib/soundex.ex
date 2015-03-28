defmodule Soundex do
  @doc """
  Compute Soundex codes for strings.  

  Soundex is an algorithm for representing (mainly English) names as short phonetic codes. 
  A Soundex code begins with the first letter of the name, followed by three digits.
  They are typically used to match like-sounding names.

  For more information, see [the Wikipedia entry](http://en.wikipedia.org/wiki/soundex/).

  ## Examples:

      iex> Soundex.soundex("Morris")
      "M620"
      
      iex> Soundex.soundex("Harris")
      "H620"  

      iex> Soundex.soundex("Morrison")
      "M625"

      iex> Soundex.soundex("Smith")
      "S530"

      iex> Soundex.soundex("Smithie")
      "S530"           


  ## Details

  Soundex only encodes letters from the English alphabet. So, for example, 
  punctuation in names is ignored:

      iex> Soundex.soundex("O\'Brien") == Soundex.soundex("OBrien")
      true

  As are spaces:

      iex> Soundex.soundex("Van Dyke") == Soundex.soundex("Vandyke")

  Unicode letters are also ignored:

      iex> Soundex.soundex("Piñata") == Soundex.soundex("Pinata")
      false

      iex> Soundex.soundex("Piñata") == Soundex.soundex("Piata")
      true

  One exception to this is the German *esszet*, which Unicode treats as two Ss:

      iex> Soundex.soundex("Straßer") == Soundex.soundex("Strasser")
      true

  """

  @soundex_codes %{["B", "F", "P", "V"] => 1,
                   ["C", "G", "J", "K", "Q", "S", "X", "Z"] => 2,
                   ["D", "T"] => 3,
                   ["L"] => 4,
                   ["M", "N"] => 5,
                   ["R"] => 6,
                   # H & W are not soundex codes, but are used to
                   # determine how to compress characters around them
                   ["H", "W"] => :hw,
                   # Vowels
                   ["A", "E", "I", "O", "U", "Y"] => :vowel}
 


  @doc """
  Compute the Soundex code of a string. 

  For details, see (http://en.wikipedia.org/wiki/soundex)[the Wikipedia entry].
  The Soundex algorithm is only defined for strings with ASCII characters.
 
  Returns a string.

  ## Examples: 

      iex> Soundex.soundex("Jackson")
      "J250"
      iex> Soundex.soundex("O\'Brien")  # Punctuation is ignored.
      "O165"
      iex> Soundex.soundex("Pinata")  
      "P530"
      iex> Soundex.soundex("Piata")
      "P300"
      iex> Soundex.soundex("Piñata")    # The ñ is ignored, not treated as n.
      "P300"

  """
  def soundex(s) when is_binary(s), do: _soundex(tag_string(s))

  defp _soundex([]), do: ""
  defp _soundex(codes) when is_list(codes) do
    compressed = codes
    |> compress_tags
    |> compress_hws

    if compressed == codes do
      [{l, _}|t] = compressed
      l <> concat_tags_to_code(t, 3)
    else
      _soundex(compressed)
    end
  end

  
  # Tag the letters in a string with their Soundex codes.
  # Tags vowels, the letters "H" and "W", and numbers, which
  # do not have Soundex codes, but does not tag punctuation or
  # other non alphabetic symbols.
  # `tag_string("O\'Brien")`
  # `[{"O", :vowel}, {"B", 1}, {"R", 6}, {"I", :vowel}, {"E", :vowel}, {"N", 5}]`
  defp tag_string(s) do
    s
    |> String.upcase
    |> keep_alpha
    |> String.codepoints
    |> Enum.map(&tag_codepoint/1)
  end


  # If two consecutive letters have the same code, then only keep the first.
  defp compress_tags(tags) do
    tags
    |> Enum.reduce([],
                   fn (x, []) -> [x]
                      (x, acc=[h|_]) -> if same_tag?(x, h) do acc else [x|acc] end
                   end)
    |> Enum.reverse
  end

  
  # If two tags with an "H" or "W" in between have the same code, only
  # keep the first one.  
  defp compress_hws([]), do: []

  defp compress_hws([x|[y={_, :hw}|[z|t]]]) do
    case same_tag?(x, z) do
      true -> compress_hws([x|[y|t]])
      false -> [x|[y|compress_hws([z|t])]]
    end
  end
  
  defp compress_hws([h|t]), do: [h|compress_hws(t)]

  
  # Nix all non-alphabetic characters from a string
  defp keep_alpha(s), do: Regex.replace(~r/[^A-Za-z]/, s, "")


  # Tag a codepoint--a length-1 binary string--with its Soundex code.
  # Only (English) alphabet codepoints get specific tags. Everything
  # else is tagged with 0.
  def tag_codepoint(c) when byte_size(c) == 1 do
    key = @soundex_codes
    |> Map.keys
    |> Enum.find(&(String.upcase(c) in ))

    {c, Map.get(@soundex_codes, key, 0)}
  end


  # Just get the tag of the codepoint.
  defp get_codepoint_tag(c) when is_binary(c) and byte_size(c) == 1 do
    {_, tag} = tag_codepoint(c)
    tag
  end
   

  # Returns true if a tag is associated with a Soundex codes
  # For instance, returns false for vowels, numbers, etc.
  defp soundex_tag?({_, x}), do: 1 <= x and x <= 6


  # Filter to keep only tags with Soundex codes.
  defp select_soundex_tags(tags) do
    Enum.filter(tags , &soundex_tag?/1)
  end

  
  # An equality check on tags. Two tags are equal if they
  # are the same code, regardless of the letter.
  defp same_tag?({_, x1}, {_, x2}), do: x1 == x2

  # Tag equality for strings
  defp same_tag?(x, y) do
    get_codepoint_tag(x) == get_codepoint_tag(y)
  end

  
  # Assemble a word string from a list of tagged letters.
  # `untag(tag_string("Foo")) == "FOO"`
  #
  # NB that this doesn't preserve the original capitalization,
  # and `untag(tag_string(x))` is equivalent to `String.upcase(x)`
  defp untag(tags) do
    Enum.reduce(tags, "", fn ({l, _}, s) -> s <> l end)
  end

  
  # Assemble the numeric part of a Soundex code from
  # a string from a list of tagged letters.
  # Returns a string of length `code_len`, with 0s padded
  # if there are fewer letters than `code_len`
  defp concat_tags_to_code(tags, code_len) do
    tags
    |> select_soundex_tags
    |> Enum.take(code_len)
    |> Enum.reduce("", fn ({_, x}, s) -> s <> Integer.to_string(x) end)
    |> pad_right_zeros(code_len)
  end

  defp concat_tags_to_code(tags) do
    soundex_tags = select_soundex_tags(tags)
    concat_tags_to_code(soundex_tags, length(soundex_tags))
  end

  # Add "0" to the end of a string until it reaches `maxlen`
  defp pad_right_zeros(s, maxlen) do
    cond do
      String.length(s) <  maxlen -> pad_right_zeros(s <> "0", maxlen)
      String.length(s) >= maxlen -> s
    end
  end
  
end 
