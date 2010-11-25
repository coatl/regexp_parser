require File.expand_path("../../../helpers", __FILE__)

class TestSyntaxRuby_V19 < Test::Unit::TestCase
  include Regexp::Syntax::Token

  def setup
    @syntax = Regexp::Syntax.new 'ruby/1.9'
  end

  tests = {
    :implements => {
      :escape => [
        Escape::Backreference + Escape::ASCII + Escape::Meta
      ].flatten,

      :quantifier => [
        Quantifier::Greedy + Quantifier::Reluctant +
        Quantifier::Possessive
      ].flatten,
    },

    :excludes => {
    },
  }

  tests.each do |method, types|
    types.each do |type, tokens|
      tokens.each do |token|
        define_method "test_syntax_ruby_v19_#{method}_#{type}_#{token}" do
          assert_equal(
            method == :excludes ? false : true,
            @syntax.implements?(type, token)
          )
        end
      end
    end
  end

end
