defmodule SoundexTest do
  use ExUnit.Case
  import Soundex

  test "Simple names give expected output." do
    assert soundex("Robert") == "R163"
    assert soundex("Rubin") == "R150"
  end

  test "Names with fewer than 4 letters get padded zeros." do
    assert soundex("Ma") == "M000"
  end

  test "If first letter is vowel, it isn't removed." do
    assert soundex("Abrams") == "A165"
  end
  
  test "Adjacent same letters are treated as one." do
    assert soundex("Guitierrez") == "G362"
  end

  test "Adjacent differing letters with same codes are treated as one." do
    assert soundex("Pfister") == "P236"
    assert soundex("Jackson") == "J250"
  end

  test "Space-separate prefixes are included." do
    assert soundex("Van Deusen") == "V532"
  end
  
  test "Punctuation in names is ignored." do
    assert soundex("O'Brien") == "O165"
  end
  
  test "Letters with the same code, separated by vowels, are repeated." do
    assert soundex("Tymczak") == "T522"
  end

  test "Letters with the same code, separated by H or W, are treated as one." do
    assert soundex("Ashcraft") == "A261"
  end
  
  test "Non-alphabetic strings return a blank string." do
    assert soundex("123.45") == ""
  end

  test "A blank string returns a blank string." do
    assert soundex("") == ""
    assert soundex(" ") == ""
  end

  test "Unicode characters are usually ignored." do
    assert soundex("Piñata") == soundex("Piata")
    assert soundex("Garçon") == soundex("Garon")
  end
  
  test "But not the Esszet, which is treated as a ligature for two S's" do
    assert soundex("Straßer") == soundex("Strasser")
  end
    
  test "Passing binaries of character codes works." do
    assert soundex(<<79,39,66,114,105,101,110>>) == "O165"
    assert soundex(<<65,115,104,99,114,111,102,116>>) == "A261"
    assert soundex(<<49,50,51,46,52,53>>) == ""
    assert soundex(<<32>>) == ""
  end

  test "Passing non-character binaries returns a blank string." do
    assert soundex(<<225, 0, 200>>) == ""
  end
  
end

