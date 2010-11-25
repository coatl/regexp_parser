require File.expand_path("../../helpers", __FILE__)

class ScannerSets < Test::Unit::TestCase

  tests = {
    '[a]'                   => [0, :set,  :open,            '[',          0, 1],
    '[b]'                   => [2, :set,  :close,           ']',          2, 3],
    '[^n]'                  => [1, :set,  :negate,          '^',          1, 2],

    '[c]'                   => [1, :set,  :member,          'c',          1, 2],
    '[\b]'                  => [1, :set,  :backspace,       '\b',         1, 3],

    '[.]'                   => [1, :set,  :member,          '.',          1, 2],
    '[?]'                   => [1, :set,  :member,          '?',          1, 2],
    '[*]'                   => [1, :set,  :member,          '*',          1, 2],
    '[+]'                   => [1, :set,  :member,          '+',          1, 2],
    '[{]'                   => [1, :set,  :member,          '{',          1, 2],
    '[}]'                   => [1, :set,  :member,          '}',          1, 2],
    '[<]'                   => [1, :set,  :member,          '<',          1, 2],
    '[>]'                   => [1, :set,  :member,          '>',          1, 2],

    '[\.]'                  => [1, :set,  :escape,          '\.',         1, 3],
    '[\!]'                  => [1, :set,  :escape,          '\!',         1, 3],
    '[\#]'                  => [1, :set,  :escape,          '\#',         1, 3],
    '[\]]'                  => [1, :set,  :escape,          '\]',         1, 3],
    '[\\\]'                 => [1, :set,  :escape,          '\\\\',       1, 3],
    '[a\-c]'                => [2, :set,  :escape,          '\-',         2, 4],

    '[\d]'                  => [1, :set,  :type_digit,      '\d',         1, 3],
    '[\D]'                  => [1, :set,  :type_nondigit,   '\D',         1, 3],

    '[\h]'                  => [1, :set,  :type_hex,        '\h',         1, 3],
    '[\H]'                  => [1, :set,  :type_nonhex,     '\H',         1, 3],

    '[\s]'                  => [1, :set,  :type_space,      '\s',         1, 3],
    '[\S]'                  => [1, :set,  :type_nonspace,   '\S',         1, 3],

    '[\w]'                  => [1, :set,  :type_word,       '\w',         1, 3],
    '[\W]'                  => [1, :set,  :type_nonword,    '\W',         1, 3],

    '[a-c]'                 => [1, :set,  :range,           'a-c',        1, 4],
    '[a-c-]'                => [2, :set,  :member,          '-',          4, 6],
    '[a-c^]'                => [2, :set,  :member,          '^',          4, 5],
    '[a-cd-f]'              => [2, :set,  :range,           'd-f',        4, 7],

    '[a[:digit:]c]'         => [2, :set,  :class_digit,     '[:digit:]',  2, 11],
    '[[:digit:][:space:]]'  => [2, :set,  :class_space,     '[:space:]', 10, 19],

    '[a-d&&g-h]'            => [2, :set,  :intersection,    '&&',         4, 6],

    '[\\x20-\\x28]'         => [1, :set,  :range_hex,       '\x20-\x28',  1, 10],

    '[a\p{digit}c]'         => [2, :set,  :digit,           '\p{digit}',  2, 11],
    '[a\P{digit}c]'         => [2, :set,  :digit,           '\P{digit}',  2, 11],

    '[a\p{ALPHA}c]'         => [2, :set,  :alpha,           '\p{ALPHA}',  2, 11],
    '[a\p{P}c]'             => [2, :set,  :punct_any,       '\p{P}',      2, 7],
    '[a\p{P}\P{Z}c]'        => [3, :set,  :separator_any,   '\P{Z}',      7, 12],

    '[a-w&&[^c-g]z]'        => [3, :set,  :open,            '[',          6, 7],
    '[a-w&&[^c-h]z]'        => [4, :set,  :negate,          '^',          7, 8],
    '[a-w&&[^c-i]z]'        => [5, :set,  :range,           'c-i',        8, 11],
    '[a-w&&[^c-j]z]'        => [6, :set,  :close,           ']',          11, 12],
  }

  count = 0
  tests.each do |pattern, test|
    define_method "test_scan_#{test[1]}_#{test[2]}_#{count+=1}" do

      tokens = RS.scan(pattern)
      assert_equal( test[1,5], tokens[test[0]] )

    end
  end

end
