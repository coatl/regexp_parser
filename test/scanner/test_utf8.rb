require File.expand_path("../../helpers", __FILE__)

class ScannerUTF8 < Test::Unit::TestCase

  tests = {
    # 2 byte wide characters, Arabic
    'aاbبcت' => {
      0     => [:literal,     :literal,       'aاbبcت',   0, 9],
    },

    'aاbبت?' => {
      0     => [:literal,     :literal,       'aاbبت',    0, 8],
      1     => [:quantifier,  :zero_or_one,   '?',        8, 9],
    },

    'aا?bبcت+' => {
      0     => [:literal,     :literal,       'aا',       0, 3],
      1     => [:quantifier,  :zero_or_one,   '?',        3, 4],
      2     => [:literal,     :literal,       'bبcت',     4, 10],
      3     => [:quantifier,  :one_or_more,   '+',        10, 11],
    },

    'a(اbب+)cت?' => {
      0     => [:literal,     :literal,       'a',        0, 1],
      1     => [:group,       :capture,       '(',        1, 2],
      2     => [:literal,     :literal,       'اbب',      2, 7],
      3     => [:quantifier,  :one_or_more,   '+',        7, 8],
      4     => [:group,       :close,         ')',        8, 9],
      5     => [:literal,     :literal,       'cت',       9, 12],
      6     => [:quantifier,  :zero_or_one,   '?',        12, 13],
    },

    # 3 byte wide characters, Japanese
    'ab?れます+cd' => {
      0     => [:literal,     :literal,       'ab',       0, 2],
      1     => [:quantifier,  :zero_or_one,   '?',        2, 3],
      2     => [:literal,     :literal,       'れます',   3, 12],
      3     => [:quantifier,  :one_or_more,   '+',        12, 13],
      4     => [:literal,     :literal,       'cd',       13, 15],
    },

    # 4 byte wide characters, Osmanya
    '𐒀𐒁?𐒂ab+𐒃' => {
      0     => [:literal,     :literal,       '𐒀𐒁',       0, 8],
      1     => [:quantifier,  :zero_or_one,   '?',        8, 9],
      2     => [:literal,     :literal,       '𐒂ab',      9, 15],
      3     => [:quantifier,  :one_or_more,   '+',        15, 16],
      4     => [:literal,     :literal,       '𐒃',        16, 20],
    },

    'mu𝄞?si*𝄫c+' => {
      0     => [:literal,     :literal,       'mu𝄞',      0, 6],
      1     => [:quantifier,  :zero_or_one,   '?',        6, 7],
      2     => [:literal,     :literal,       'si',       7, 9],
      3     => [:quantifier,  :zero_or_more,  '*',        9, 10],
      4     => [:literal,     :literal,       '𝄫c',       10, 15],
      5     => [:quantifier,  :one_or_more,   '+',        15, 16],
    },
  }

  count = 0
  tests.each do |pattern, checks|
    define_method "test_scan_utf8_runs_#{count+=1}" do

      tokens = RS.scan(pattern)
      checks.each do |offset, token|
        assert_equal( token, tokens[offset] )
      end

    end
  end

end
