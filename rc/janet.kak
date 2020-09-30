# http://janet-lang.org
# ‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾

# require lisp.kak

# Detection
# ‾‾‾‾‾‾‾‾‾

hook global BufCreate .*[.](janet|jdn) %{
    set-option buffer filetype janet
}

# Initialization
# ‾‾‾‾‾‾‾‾‾‾‾‾‾‾
#
hook global WinSetOption filetype=janet %{
    require-module janet
    janet-configure-window
}

hook -group janet-highlight global WinSetOption filetype=janet %{
    add-highlighter window/janet ref janet
    hook -once -always window WinSetOption filetype=.* %{ remove-highlighter window/janet }
}

hook -group janet-insert global BufNewFile .*[.](janet|jdn) %{
    require-module janet
}

provide-module janet %{

  require-module lisp

# Highlighters
# ‾‾‾‾‾‾‾‾‾‾‾‾

add-highlighter shared/janet regions
add-highlighter shared/janet/code default-region group
add-highlighter shared/janet/comment region '(?<!\\)(?:\\\\)*\K#' '$'                 fill comment
add-highlighter shared/janet/string  region '(?<!\\)(?:\\\\)*\K"' '(?<!\\)(?:\\\\)*"' fill string

add-highlighter shared/janet/code/ regex \b(nil|true|false)\b 0:value
add-highlighter shared/janet/code/ regex \
    \\(?:space|tab|newline|return|backspace|formfeed|u[0-9a-fA-F]{4}|o[0-3]?[0-7]{1,2}|.)\b 0:string

evaluate-commands %sh{
    symbol_char='[^\s()\[\]{}"\;@^`~\\%/]'
    modules="
    array buffer debug fiber file int janet math module os parser peg string
    table tarray thread tuple net"
    keywords="
     * *= + ++ += - -- -= -> ->> -?> -?>> < <= = == > >= abstract? all all-bindings
     all-dynamics and apply array array? as-> as?-> asm assert bad-compile bad-parse band
     blshift bnot boolean? bor brshift brushift buffer buffer? bxor bytes? case cfunction?
     cli-main comment comp compile complement cond coro count debug dec deep-not= deep=
     def def- default defglobal defmacro defmacro- defn defn- describe dictionary?
     disasm distinct doc doc* doc-format dofile drop drop-until drop-while dyn
     each eachk eachp empty? env-lookup eprin eprint eprintf error eval eval-string even? every?
     extreme false? fiber? filter find find-index first flatten flatten-into for freeze
     frequencies function? gccollect gcinterval gcsetinterval generate gensym get
     get-in getline hash idempotent? identity if-let if-not import import* in
     inc indexed? int? interleave interpose invert juxt juxt* keep keys keyword
     keyword? kvs last length let load-image loop macex macex1 make-env make-image
     map mapcat marshal match max max-order mean merge merge-into min min-order nat?
     native neg? next nil? not not= not== number? odd? one? or order< order<= order>
     order>= pairs partial partition pos? postwalk pp prewalk prin print printf product
     propagate put put-in quit range reduce repl require resume reverse run-context
     scan-number seq setdyn short-fn slice slurp some sort sort-by sorted sorted-by spit stderr stdin
     stdout string string? struct struct? sum symbol symbol? table table? take
     take-until take-while trace tracev true? try tuple tuple? type unless unmarshal untrace
     update update-in use values var varfn varglobal walk when when-let while with with-dyns
     with-syms with-vars yield zero? if while fn defer prompt label protect set reduce2 accumulate accumulate2"

    join() { sep=$2; set -- $1; IFS="$sep"; echo "$*"; }
    keywords() {
        words="$1"
        type="$2"
        words="$(echo "$words" |sed -e 's/[+?*\.]/\\&/g')"
        printf 'add-highlighter shared/janet/code/ regex (?<!%s)(%s)(?!%s) 0:%s\n' \
            "${symbol_char}" \
            "$(join "${words}" '|')" \
            "${symbol_char}" \
            "${type}"
    }

    static_words="$(join "$keywords" ' ')"

    printf %s "
        # Keywords
        add-highlighter shared/janet/code/ regex ::?(${symbol_char}+/)?${symbol_char}+ 0:value

        # Numbers
        add-highlighter shared/janet/code/ regex (?<!${symbol_char})[-+]?(?:0(?:[xX][0-9a-fA-F]+|[0-7]*)|[0-9]+)N? 0:value
        add-highlighter shared/janet/code/ regex (?<!${symbol_char})[-+]?(?:0|[0-9]\d*)(?:\.\d*)(?:M|[eE][-+]?\d+)? 0:value
        add-highlighter shared/janet/code/ regex (?<!${symbol_char})[-+]?(?:0|[0-9]\d*)/(?:0|[0-9]\d*) 0:value

        $(keywords "${keywords}" keyword)
        hook global WinSetOption filetype=janet %{
            set-option window static_words $static_words
        }
    "
}

# Commands
# ‾‾‾‾‾‾‾‾
define-command -hidden janet-configure-window %{
    hook window ModeChange pop:insert:.* -group janet-trim-indent  janet-trim-indent
    hook window InsertChar \n -group janet-indent janet-indent-on-new-line

    set-option buffer extra_word_chars '_' . / * ? + - < > ! : "'"
    hook -once -always window WinSetOption filetype=.* %{ remove-hooks window janet-.+ }
    set-option window extra_word_chars . / * ? + - < > ! : "'"

    set window formatcmd jfmt
    hook buffer BufWritePre .* %{format}
    map global user -docstring 'open janet'         J     ': connect-terminal janet<ret>'
}

define-command -hidden janet-trim-indent lisp-trim-indent

define-command -hidden janet-filter-around-selections lisp-filter-around-selections

declare-option \
    -docstring 'regex matching the head of forms which have options *and* indented bodies' \
    regex janet_special_indent_forms \
    '(?:def.*|while|for|fn\*?|if(-.*|)|let.*|loop|seq|with(-.*|)|when(-.*|))|defer|do|match'

define-command -hidden janet-indent-on-new-line %{
    # registers: i = best align point so far; w = start of first word of form
    evaluate-commands -draft -save-regs '/"|^@iw' -itersel %{
        execute-keys -draft 'gk"iZ'
        try %{
            execute-keys -draft '[bl"i<a-Z><gt>"wZ'

            try %{
                # If a special form, indent another space
                execute-keys -draft '"wze<a-k>\A' %opt{janet_special_indent_forms} '\z<ret><a-L>s.\K.*<ret><a-;>;"i<a-Z><gt>'
            } catch %{
                # If not special and parameter appears on line 1, indent to parameter
                execute-keys -draft '"wze<a-l>s\h\K[^\s].*<ret><a-;>;"i<a-Z><gt>'
            }
        }
        try %{ execute-keys -draft '[rl"i<a-Z><gt>' }
        try %{ execute-keys -draft '[Bl"i<a-Z><gt>' }
        execute-keys -draft '"i<a-z>a&<space>'
    }
}


}
