%%{
  machine re_scanner;

  dot                   = '.';
  backslash             = '\\';
  alternation           = '|';
  beginning_of_line     = '^';
  end_of_line           = '$';

  range_open            = '{';
  range_close           = '}';
  curlies               = range_open | range_close;

  group_open            = '(';
  group_close           = ')';
  parantheses           = group_open | group_close;

  set_open              = '[';
  set_close             = ']';
  brackets              = set_open | set_close;

  class_name_posix      = 'alnum' | 'alpha' | 'blank' |
                          'cntrl' | 'digit' | 'graph' |
                          'lower' | 'print' | 'punct' |
                          'space' | 'upper' | 'xdigit' |
                          'word'  | 'ascii';

  # Property names are being treated as case-insensitive, but it is not clear
  # yet if this applies to all flavors and in all encodings. A bug has just
  # been filed against ruby regarding this issue.
  # http://redmine.ruby-lang.org/issues/show/4014
  property_char         = [pP];

  property_name_unicode = 'alnum'i | 'alpha'i | 'any'i   | 'ascii'i | 'blank'i |
                          'cntrl'i | 'digit'i | 'graph'i | 'lower'i | 'print'i |
                          'punct'i | 'space'i | 'upper'i | 'word'i  | 'xdigit'i;

  property_name_ruby    = 'any'i | 'assigned'i | 'newline'i;

  property_name         = property_name_unicode | property_name_ruby;

  category_letter       = [Ll] . [ultmo]?;
  category_mark         = [Mm] . [nce]?;
  category_number       = [Nn] . [dlo]?;
  category_punctuation  = [Pp] . [cdseifo]?;
  category_symbol       = [Ss] . [mcko]?;
  category_separator    = [Zz] . [slp]?;
  category_codepoint    = [Cc] . [cfson]?;

  general_category      = category_letter | category_mark |
                          category_number | category_punctuation |
                          category_symbol | category_separator |
                          category_codepoint;

  property_sequence     = property_char.'{'.(property_name | general_category).'}';



  class_posix           = '[:' . class_name_posix . ':]';

  char_type             = [dDhHsSwW];

  line_anchor           = beginning_of_line | end_of_line;
  anchor_char           = [AbBzZG];

  escaped_char          = [abefnrstv];
  octal_sequence        = [0-7]{1,3};

  hex_sequence          = 'x' . xdigit{1,2};
  wide_hex_sequence     = 'x' . '{' . xdigit{1,8} . '}';

  codepoint_single      = 'u' . xdigit{4};
  codepoint_list        = 'u{' . (xdigit{4} . space?)+'}';
  codepoint_sequence    = codepoint_single | codepoint_list;

  control_sequence      = ('c' | 'C-') . alpha;
  meta_sequence         = 'M-' . alpha; # FIXME: incorrect, and can include escapes

  zero_or_one           = '?' | '??' | '?+';
  zero_or_more          = '*' | '*?' | '*+';
  one_or_more           = '+' | '+?' | '++';

  quantifier_greedy     = '?'  | '*'  | '+';
  quantifier_reluctant  = '??' | '*?' | '+?';
  quantifier_possessive = '?+' | '*+' | '++';
  quantifier_mode       = '?'  | '+';

  quantifier_range      = range_open . (digit+)? . ','? . (digit+)? .
                          range_close . quantifier_mode?;

  quantifier_range_bre  = backslash . range_open . (digit+)? . ','? . (digit+)? .
                          backslash . range_close;

  quantifiers           = quantifier_greedy | quantifier_reluctant |
                          quantifier_possessive | quantifier_range;


  group_comment         = '?#' . [^)]+ . group_close;

  group_atomic          = '?>';
  group_passive         = '?:';

  assertion_lookahead   = '?=';
  assertion_nlookahead  = '?!';
  assertion_lookbehind  = '?<=';
  assertion_nlookbehind = '?<!';

  group_options         = '?' . ([mix]{1,3})? . '-' . ([mix]{1,3})? . ':'?;

  group_name            = alpha . alnum+;
  group_named           = ('?<' . group_name . '>') | ('?\'' . group_name . '\'');

  group_type            = group_atomic | group_passive | group_named;

  assertion_type        = assertion_lookahead  | assertion_nlookahead |
                          assertion_lookbehind | assertion_nlookbehind;

  # characters that 'break' a literal
  meta_char             = dot | backslash | alternation |
                          curlies | parantheses | brackets |
                          line_anchor | quantifier_greedy;

  ascii_print           = ((0x20..0x7e) - meta_char)+;
  ascii_nonprint        = (0x01..0x1f | 0x7f)+;

  utf8_2_byte           = (0xc2..0xdf 0x80..0xbf)+;
  utf8_3_byte           = (0xe0..0xef 0x80..0xbf 0x80..0xbf)+;
  utf8_4_byte           = (0xf0..0xf4 0x80..0xbf 0x80..0xbf 0x80..0xbf)+;
  utf8_byte_sequence    = utf8_2_byte | utf8_3_byte | utf8_4_byte;


  # EOF error, used where it can be detected
  action premature_end_error { raise "Premature end of pattern" }

  # group (nesting) and set open/close actions
  action group_opened { in_group += 1 }
  action group_closed { in_group -= 1 }

  action set_opened { in_set = true }
  action set_closed { in_set = false }


  # Character set scanner, continues consuming characters until it meets the
  # closing bracket of the set.
  # --------------------------------------------------------------------------
  character_set := |*
    ']' %set_closed {
      self.emit(:set, :close, data[ts..te-1].pack('c*'), ts, te)
      fret;
    };

    '-]' %set_closed { # special case, emits two tokens
      self.emit(:set, :member, data[ts..te-2].pack('c*'), ts, te)
      self.emit(:set, :close,  data[ts+1..te-1].pack('c*'), ts, te)
      fret;
    };

    '^' {
      text = data[ts..te-1].pack('c*')
      if @tokens.last[1] == :open
        self.emit(:set, :negate, text, ts, te)
      else
        self.emit(:set, :member, text, ts, te)
      end
    };

    alnum . '-' . alnum { # TODO: add properties
      self.emit(:set, :range, data[ts..te-1].pack('c*'), ts, te)
    };

    '&&' {
      self.emit(:set, :intersection, data[ts..te-1].pack('c*'), ts, te)
    };

    '\\' {
      fcall set_escape_sequence;
    };

    class_posix @err(premature_end_error) {
      case text = data[ts..te-1].pack('c*')
      when '[:alnum:]';  self.emit(:set, :class_alnum,  text, ts, te)
      when '[:alpha:]';  self.emit(:set, :class_alpha,  text, ts, te)
      when '[:ascii:]';  self.emit(:set, :class_ascii,  text, ts, te)
      when '[:blank:]';  self.emit(:set, :class_blank,  text, ts, te)
      when '[:cntrl:]';  self.emit(:set, :class_cntrl,  text, ts, te)
      when '[:digit:]';  self.emit(:set, :class_digit,  text, ts, te)
      when '[:graph:]';  self.emit(:set, :class_graph,  text, ts, te)
      when '[:lower:]';  self.emit(:set, :class_lower,  text, ts, te)
      when '[:print:]';  self.emit(:set, :class_print,  text, ts, te)
      when '[:punct:]';  self.emit(:set, :class_punct,  text, ts, te)
      when '[:space:]';  self.emit(:set, :class_space,  text, ts, te)
      when '[:upper:]';  self.emit(:set, :class_upper,  text, ts, te)
      when '[:word:]';   self.emit(:set, :class_word,   text, ts, te)
      when '[:xdigit:]'; self.emit(:set, :class_xdigit, text, ts, te)
      else raise "Unsupported character posixe class at #{text} (char #{ts})"
      end
    };

    meta_char {
      self.emit(:set, :member, data[ts..te-1].pack('c*'), ts, te)
    };

    any            |
    ascii_nonprint |
    utf8_2_byte    |
    utf8_3_byte    |
    utf8_4_byte    {
      self.emit(:set, :member, data[ts..te-1].pack('c*'), ts, te)
    };
  *|;

  # set escapes scanner
  # --------------------------------------------------------------------------
  set_escape_sequence := |*
    'b' {
      self.emit(:set, :backspace, data[ts-1..te-1].pack('c*'), ts-1, te)
      fret;
    };

    char_type {
      case text = data[ts-1..te-1].pack('c*')
      when '\d'; self.emit(:set, :type_digit,     text, ts-1, te)
      when '\D'; self.emit(:set, :type_nondigit,  text, ts-1, te)
      when '\h'; self.emit(:set, :type_hex,       text, ts-1, te)
      when '\H'; self.emit(:set, :type_nonhex,    text, ts-1, te)
      when '\s'; self.emit(:set, :type_space,     text, ts-1, te)
      when '\S'; self.emit(:set, :type_nonspace,  text, ts-1, te)
      when '\w'; self.emit(:set, :type_word,      text, ts-1, te)
      when '\W'; self.emit(:set, :type_nonword,   text, ts-1, te)
      end
      fret;
    };

    hex_sequence . '-\\' . hex_sequence {
      self.emit(:set, :range_hex, data[ts-1..te-1].pack('c*'), ts-1, te)
      fret;
    };

    hex_sequence {
      self.emit(:set, :member_hex, data[ts-1..te-1].pack('c*'), ts-1, te)
      fret;
    };

    [\\\]\-\,] {
      self.emit(:set, :escape, data[ts-1..te-1].pack('c*'), ts-1, te)
      fret;
    };

    meta_char {
      self.emit(:set, :escape, data[ts-1..te-1].pack('c*'), ts-1, te)
      fret;
    };

    property_char > (escaped_set_alpha, 2) {
      fhold; fcall unicode_property;
    };

    # special case exclusion of escaped dash, could be cleaner.
    (ascii_print - char_type -- [\-]) > (escaped_set_alpha, 1) |
    ascii_nonprint            |
    utf8_2_byte               |
    utf8_3_byte               |
    utf8_4_byte               {
      self.emit(:set, :escape, data[ts-1..te-1].pack('c*'), ts-1, te)
      fret;
    };
  *|;


  # escape sequence scanner
  # --------------------------------------------------------------------------
  escape_sequence := |*
    [1-9] {
      text = data[ts-1..te-1].pack('c*')
      self.emit(:backref, :digit, text, ts-1, te)
      fret;
    };

    meta_char {
      case text = data[ts-1..te-1].pack('c*')
      when '\.';  self.emit(:escape, :dot,               text, ts-1, te)
      when '\|';  self.emit(:escape, :alternation,       text, ts-1, te)
      when '\^';  self.emit(:escape, :beginning_of_line, text, ts-1, te)
      when '\$';  self.emit(:escape, :end_of_line,       text, ts-1, te)
      when '\?';  self.emit(:escape, :zero_or_one,       text, ts-1, te)
      when '\*';  self.emit(:escape, :zero_or_more,      text, ts-1, te)
      when '\+';  self.emit(:escape, :one_or_more,       text, ts-1, te)
      when '\(';  self.emit(:escape, :group_open,        text, ts-1, te)
      when '\)';  self.emit(:escape, :group_close,       text, ts-1, te)
      when '\{';  self.emit(:escape, :interval_open,     text, ts-1, te)
      when '\}';  self.emit(:escape, :interval_close,    text, ts-1, te)
      when '\[';  self.emit(:escape, :set_open,          text, ts-1, te)
      when '\]';  self.emit(:escape, :set_close,         text, ts-1, te)
      when "\\\\";
        self.emit(:escape, :backslash, text, ts-1, te)
      end
      fret;
    };

    escaped_char > (escaped_alpha, 8) {
      # \b is a backspace only inside a character set
      case text = data[ts-1..te-1].pack('c*')
      when '\a'; self.emit(:escape, :bell,           text, ts-1, te)
      when '\e'; self.emit(:escape, :escape,         text, ts-1, te)
      when '\f'; self.emit(:escape, :form_feed,      text, ts-1, te)
      when '\n'; self.emit(:escape, :newline,        text, ts-1, te)
      when '\r'; self.emit(:escape, :carriage,       text, ts-1, te)
      when '\s'; self.emit(:escape, :space,          text, ts-1, te)
      when '\t'; self.emit(:escape, :tab,            text, ts-1, te)
      when '\v'; self.emit(:escape, :vertical_tab,   text, ts-1, te)
      end
      fret;
    };

    codepoint_sequence > (escaped_alpha, 7) {
      text = data[ts-1..te-1].pack('c*')
      if text[2].chr == '{'
        self.emit(:escape, :codepoint_list, text, ts-1, te)
      else
        self.emit(:escape, :codepoint,      text, ts-1, te)
      end
      fret;
    };

    octal_sequence {
      self.emit(:escape, :octal, data[ts-1..te-1].pack('c*'), ts-1, te)
      fret;
    };

    hex_sequence > (escaped_alpha, 6) {
      self.emit(:escape, :hex, data[ts-1..te-1].pack('c*'), ts-1, te)
      fret;
    };

    # FIXME: scanner returns nil
    wide_hex_sequence > (escaped_alpha, 5) {
      self.emit(:escape, :hex_wide, data[ts-1..te-1].pack('c*'), ts-1, te)
      fret;
    };

    control_sequence > (escaped_alpha, 4) {
      self.emit(:escape, :control, data[ts-1..te-1].pack('c*'), ts-1, te)
      fret;
    };

    meta_sequence > (escaped_alpha, 3) {
      # TODO: add escapes
      self.emit(:escape, :meta, data[ts-1..te-1].pack('c*'), ts-1, te)
      fret;
    };

    property_char > (escaped_alpha, 2) {
      fhold; fcall unicode_property; fret;
    };

    any > (escaped_alpha, 1)  {
      self.emit(:escape, :literal, data[ts-1..te-1].pack('c*'), ts-1, te)
      fret;
    };
  *|;


  # Unicode properties scanner
  # --------------------------------------------------------------------------
  unicode_property := |*
    property_sequence < err(premature_end_error) {
      text = data[ts-1..te-1].pack('c*')

      if in_set
        type = :set
        pref = text[1,1] == 'p' ? :property : :nonproperty
      else
        type = text[1,1] == 'p' ? :property : :nonproperty
        pref = ''
      end
      # TODO: add ^ for property negation, :nonproperty_caret

      case name = data[ts+2..te-2].pack('c*').downcase

      # Named
      when 'alnum';   self.emit(type, :alnum,       text, ts-1, te)
      when 'alpha';   self.emit(type, :alpha,       text, ts-1, te)
      when 'any';     self.emit(type, :any,         text, ts-1, te)
      when 'ascii';   self.emit(type, :ascii,       text, ts-1, te)
      when 'blank';   self.emit(type, :blank,       text, ts-1, te)
      when 'cntrl';   self.emit(type, :cntrl,       text, ts-1, te)
      when 'digit';   self.emit(type, :digit,       text, ts-1, te)
      when 'graph';   self.emit(type, :graph,       text, ts-1, te)
      when 'lower';   self.emit(type, :lower,       text, ts-1, te)
      when 'newline'; self.emit(type, :newline,     text, ts-1, te)
      when 'print';   self.emit(type, :print,       text, ts-1, te)
      when 'punct';   self.emit(type, :punct,       text, ts-1, te)
      when 'space';   self.emit(type, :space,       text, ts-1, te)
      when 'upper';   self.emit(type, :upper,       text, ts-1, te)
      when 'word';    self.emit(type, :word,        text, ts-1, te)
      when 'xdigit';  self.emit(type, :xdigit,      text, ts-1, te)

      # Letters
      when 'l';  self.emit(type, :letter_any,       text, ts-1, te)
      when 'lu'; self.emit(type, :letter_uppercase, text, ts-1, te)
      when 'll'; self.emit(type, :letter_lowercase, text, ts-1, te)
      when 'lt'; self.emit(type, :letter_titlecase, text, ts-1, te)
      when 'lm'; self.emit(type, :letter_modifier,  text, ts-1, te)
      when 'lo'; self.emit(type, :letter_other,     text, ts-1, te)

      # Marks
      when 'm';  self.emit(type, :mark_any,         text, ts-1, te)
      when 'mn'; self.emit(type, :mark_nonspacing,  text, ts-1, te)
      when 'mc'; self.emit(type, :mark_spacing,     text, ts-1, te)
      when 'me'; self.emit(type, :mark_enclosing,   text, ts-1, te)

      # Numbers
      when 'n';  self.emit(type, :number_any,       text, ts-1, te)
      when 'nd'; self.emit(type, :number_decimal,   text, ts-1, te)
      when 'nl'; self.emit(type, :number_letter,    text, ts-1, te)
      when 'no'; self.emit(type, :number_other,     text, ts-1, te)

      # Punctuation
      when 'p';  self.emit(type, :punct_any,        text, ts-1, te)
      when 'pc'; self.emit(type, :punct_connector,  text, ts-1, te)
      when 'pd'; self.emit(type, :punct_dash,       text, ts-1, te)
      when 'ps'; self.emit(type, :punct_open,       text, ts-1, te)
      when 'pe'; self.emit(type, :punct_close,      text, ts-1, te)
      when 'pi'; self.emit(type, :punct_initial,    text, ts-1, te)
      when 'pf'; self.emit(type, :punct_final,      text, ts-1, te)
      when 'po'; self.emit(type, :punct_other,      text, ts-1, te)

      # Symbols
      when 's';  self.emit(type, :symbol_any,       text, ts-1, te)
      when 'sm'; self.emit(type, :symbol_math,      text, ts-1, te)
      when 'sc'; self.emit(type, :symbol_currency,  text, ts-1, te)
      when 'sk'; self.emit(type, :symbol_modifier,  text, ts-1, te)
      when 'so'; self.emit(type, :symbol_other,     text, ts-1, te)

      # Separators
      when 'z';  self.emit(type, :separator_any,    text, ts-1, te)
      when 'zs'; self.emit(type, :separator_space,  text, ts-1, te)
      when 'zl'; self.emit(type, :separator_line,   text, ts-1, te)
      when 'zp'; self.emit(type, :separator_para,   text, ts-1, te)

      # Codepoints
      when 'c';  self.emit(type, :cp_any,           text, ts-1, te)
      when 'cc'; self.emit(type, :cp_control,       text, ts-1, te)
      when 'cf'; self.emit(type, :cp_format,        text, ts-1, te)
      when 'cs'; self.emit(type, :cp_surrogate,     text, ts-1, te)
      when 'co'; self.emit(type, :cp_private,       text, ts-1, te)
      when 'cn'; self.emit(type, :cp_unassigned,    text, ts-1, te)
      end
      fret;
    };
  *|;


  # Main scanner
  # --------------------------------------------------------------------------
  main := |*

    # Meta characters
    dot {
      self.emit(:meta, :dot, data[ts..te-1].pack('c*'), ts, te)
    };

    alternation {
      self.emit(:meta, :alternation, data[ts..te-1].pack('c*'), ts, te)
    };

    # Character types
    #   \d, \D    digit, non-digit
    #   \h, \H    hex, non-hex
    #   \s, \S    space, non-space
    #   \w, \W    word, non-word
    # ------------------------------------------------------------------------
    backslash . char_type > (backslashed, 2) {
      case text = data[ts..te-1].pack('c*')
      when '\\d'; self.emit(:type, :digit,      text, ts, te)
      when '\\D'; self.emit(:type, :nondigit,   text, ts, te)
      when '\\h'; self.emit(:type, :hex,        text, ts, te)
      when '\\H'; self.emit(:type, :nonhex,     text, ts, te)
      when '\\s'; self.emit(:type, :space,      text, ts, te)
      when '\\S'; self.emit(:type, :nonspace,   text, ts, te)
      when '\\w'; self.emit(:type, :word,       text, ts, te)
      when '\\W'; self.emit(:type, :nonword,    text, ts, te)
      end
    };

    # Anchors
    beginning_of_line {
      self.emit(:anchor, :beginning_of_line, data[ts..te-1].pack('c*'), ts, te)
    };

    end_of_line {
      self.emit(:anchor, :end_of_line, data[ts..te-1].pack('c*'), ts, te)
    };

    backslash . anchor_char > (backslashed, 3) {
      case text = data[ts..te-1].pack('c*')
      when '\\A'; self.emit(:anchor, :bos,                text, ts, te)
      when '\\z'; self.emit(:anchor, :eos,                text, ts, te)
      when '\\Z'; self.emit(:anchor, :eos_ob_eol,         text, ts, te)
      when '\\b'; self.emit(:anchor, :word_boundary,      text, ts, te)
      when '\\B'; self.emit(:anchor, :nonword_boundary,   text, ts, te)
      else raise "Unsupported anchor at #{text} (char #{ts})"
      end
    };

    # Escaped sequences
    backslash > (backslashed, 1) {
      fcall escape_sequence;
    };

    # Character sets
    set_open %set_opened  {
      self.emit(:set, :open, data[ts..te-1].pack('c*'), ts, te)
      fcall character_set;
    };

    # (?#...) comments: parsed as a single expression, without introducing a
    # new nesting level. Comments may not include parentheses, escaped or not.
    # special case for close, all transitions
    group_open . group_comment $group_closed {
      self.emit(:group, :comment, data[ts..te-1].pack('c*'), ts, te)
    };

    # (?mix-mix...) expression options:
    #   (?imx-imx)          option on/off
    #                         i: ignore case
    #                         m: multi-line (dot(.) match newline)
    #                         x: extended form
    #
    #   (?imx-imx:subexp)   option on/off for subexp
    group_open . group_options >group_opened {
      self.emit(:group, :options, data[ts..te-1].pack('c*'), ts, te)
    };

    # Assertions
    #   (?=subexp)          look-ahead
    #   (?!subexp)          negative look-ahead
    #   (?<=subexp)         look-behind
    #   (?<!subexp)         negative look-behind
    # ------------------------------------------------------------------------
    group_open . assertion_type >group_opened {
      case text =  data[ts..te-1].pack('c*')
      when '(?=';  self.emit(:assertion, :lookahead,    text, ts, te)
      when '(?!';  self.emit(:assertion, :nlookahead,   text, ts, te)
      when '(?<='; self.emit(:assertion, :lookbehind,   text, ts, te)
      when '(?<!'; self.emit(:assertion, :nlookbehind,  text, ts, te)
      end
    };

    # Groups
    #   (?:subexp)          passive (non-captured) group
    #   (?>subexp)          atomic group, don't backtrack in subexp.
    #   (?<name>subexp)     named group
    #   (?'name'subexp)     named group (single quoted version)
    #   (subexp)            captured group
    # ------------------------------------------------------------------------
    group_open . group_type >group_opened {
      case text =  data[ts..te-1].pack('c*')
      when '(?:';  self.emit(:group, :passive,      text, ts, te)
      when '(?>';  self.emit(:group, :atomic,       text, ts, te)

      when /\(\?<\w+>/
        self.emit(:group, :named,     text, ts, te)
      when /\(\?'\w+'/
        self.emit(:group, :named_sq,  text, ts, te)
      end
    };

    group_open @group_opened {
      text =  data[ts..te-1].pack('c*')
      self.emit(:group, :capture, text, ts, te)
    };

    group_close @group_closed {
      self.emit(:group, :close, data[ts..te-1].pack('c*'), ts, te)
    };


    # Quantifiers
    # ------------------------------------------------------------------------
    zero_or_one {
      case text =  data[ts..te-1].pack('c*')
      when '?' ;  self.emit(:quantifier, :zero_or_one,            text, ts, te)
      when '??';  self.emit(:quantifier, :zero_or_one_reluctant,  text, ts, te)
      when '?+';  self.emit(:quantifier, :zero_or_one_possessive, text, ts, te)
      end
    };
  
    zero_or_more {
      case text =  data[ts..te-1].pack('c*')
      when '*' ;  self.emit(:quantifier, :zero_or_more,            text, ts, te)
      when '*?';  self.emit(:quantifier, :zero_or_more_reluctant,  text, ts, te)
      when '*+';  self.emit(:quantifier, :zero_or_more_possessive, text, ts, te)
      end
    };
  
    one_or_more {
      case text =  data[ts..te-1].pack('c*')
      when '+' ;  self.emit(:quantifier, :one_or_more,            text, ts, te)
      when '+?';  self.emit(:quantifier, :one_or_more_reluctant,  text, ts, te)
      when '++';  self.emit(:quantifier, :one_or_more_possessive, text, ts, te)
      end
    };


    # Intervals: min, max, and exact notations
    # ------------------------------------------------------------------------
    quantifier_range  @err(premature_end_error) {
      self.emit(:quantifier, :interval, data[ts..te-1].pack('c*'), ts, te)
    };

    # BRE version
    quantifier_range_bre  @err(premature_end_error) {
      self.emit(:quantifier, :interval_bre, data[ts..te-1].pack('c*'), ts, te)
    };


    # Literal: any run of ASCII (pritable or non-printable), and/or UTF-8,
    # except meta characters.
    # ------------------------------------------------------------------------
    ascii_print+    |
    ascii_nonprint+ |
    utf8_2_byte+    |
    utf8_3_byte+    |
    utf8_4_byte+    {
      self.append_literal(data, ts, te)
    };

  *|;
}%%


module Regexp::Scanner
  %% write data;

  # Scans the given regular expression text, or Regexp object and collects the
  # emitted token into an array that gets returns at the end. If a block is
  # given, it gets called for each emitted token.
  #
  # This may raise an error if a syntax error is encountered. ** this is still
  # in progress.
  # --------------------------------------------------------------------------
  def self.scan(input, &block)
    top, stack = 0, []

    input = input.source if input.is_a?(Regexp)
    data  = input.unpack("c*") if input.is_a?(String)
    eof   = data.length

    @tokens = []
    @block  = block_given? ? block : nil

    in_group = 0
    in_set   = false

    %% write init;
    %% write exec;

    raise "Premature end of pattern (missing group closing paranthesis) [#{in_group}]" if
      in_group > 0
    raise "Premature end of pattern (missing set closing bracket)" if in_set 

    # when the entire expression is a literal run
    self.emit_literal if @literal

    @tokens
  end

  # appends one or more characters to the literal buffer, to be emitted later
  # by a call to emit_literal. contents a mix of ASCII and UTF-8
  def self.append_literal(data, ts, te)
    @literal ||= []
    @literal << [data[ts..te-1].pack('c*'), ts, te]
  end

  # emits the collected literal run collected by one or more calls to the 
  # append_literal method
  def self.emit_literal
    ts, te = @literal.first[1], @literal.last[2]
    text = @literal.map {|t| t[0]}.join
    self.emit(:literal, :literal, text, ts, te)
    @literal = nil
  end

  def self.emit(type, token, text, ts, te)
    #puts " > emit: #{type}:#{token} '#{text}' [#{ts}..#{te}]"

    if @literal and type != :literal
      self.emit_literal
    end

    if @block
      @block.call type, token, text, ts, te
    end

    @tokens << [type, token, text, ts, te]
  end

end # module Regexp::Scanner
