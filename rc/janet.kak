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
       % %= * *= + ++ += - -- -= -> ->> -?> -?>> / /= < <= = > >=
       abstract? accumulate accumulate2 all all-bindings all-dynamics
       and any? apply array array? as-> as?-> asm assert bad-compile
       bad-parse band blshift bnot boolean? bor brshift brushift buffer
       buffer? bxor bytes? cancel case cfunction? chr cli-main cmp comment
       comp compare compare< compare<= compare= compare> compare>= compile
       complement comptime cond coro count curenv debug debugger-env dec
       deep-not= deep= def- default default-peg-grammar defer defglobal
       defmacro defmacro- defn defn- describe dictionary? disasm distinct
       doc doc* doc-format dofile drop drop-until drop-while dyn each
       eachk eachp eachy edefer eflush empty? env-lookup eprin eprinf
       eprint eprintf error errorf eval eval-string even? every? extreme
       false? fiber? filter find find-index first flatten flatten-into
       flush for forever forv freeze frequencies function? gccollect
       gcinterval gcsetinterval generate gensym get get-in getline
       hash idempotent? identity if-let if-not if-with import import*
       in inc index-of indexed? int? interleave interpose invert
       juxt juxt* keep keys keyword keyword? kvs label last length
       let load-image load-image-dict loop macex macex1 make-env
       make-image make-image-dict map mapcat marshal match max mean
       merge merge-into min mod nan? nat? native neg? next nil? not not=
       number? odd? one? or pairs parse partial partition pos? postwalk pp
       prewalk prin prinf print printf product prompt propagate protect
       put put-in quit range reduce reduce2 repeat repl require resume
       return reverse reverse! root-env run-context scan-number seq setdyn
       short-fn signal slice slurp some sort sort-by sorted sorted-by
       spit stderr stdin stdout string string? struct struct? sum
       symbol symbol? table table? take take-until take-while trace
       tracev true? truthy? try tuple tuple? type unless unmarshal
       untrace update update-in use values var- varfn varglobal walk
       when when-let when-with with with-dyns with-syms with-vars xprin
       xprinf xprint xprintf yield zero? zipcoll"

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
define-command janet-doc %{ evaluate-commands  %{
    write
    # -- Janet OUTPUT stored in %reg{o}
    set-register o %sh{
      output=$(mktemp -d "${TMPDIR:-/tmp}"/kak-jesty.XXXXXXXX)/fifo
      mkfifo $output
      printf "%s" "$output"
   }
   # -- Execute Jesty
   nop %sh{
     ( janet -q -e "(print (doc ${kak_selection}))" | tr -d '\r' > ${kak_reg_o} 2>&1 & ) > /dev/null 2>&1 < /dev/null }
   # -- Setup and populate *search* bufferne
   edit! -fifo %reg{o} *janet.doc*
   set-option buffer filetype janet
   hook -always -once buffer BufCloseFifo .* %{ nop %sh{ rm -r $(dirname ${kak_reg_o}) } }
}}

declare-user-mode janet
map global janet -docstring 'Open repl' r ': connect-terminal janet<ret>'
map global janet -docstring 'tracev'    t ': surround<ret>(<a-;>itracev <esc>'
map global janet -docstring 'strip '    T 'edd: delete-surround<ret>( <esc>'
map global janet -docstring 'Janet doc' d ': janet-doc<ret>'

define-command -hidden janet-configure-window %{
    hook window ModeChange pop:insert:.* -group janet-trim-indent  janet-trim-indent
    hook window InsertChar \n -group janet-indent janet-indent-on-new-line

    set-option buffer extra_word_chars '_' . / * ? + - < > ! : "'"
    hook -once -always window WinSetOption filetype=.* %{ remove-hooks window janet-.+ }
    set-option window extra_word_chars . / * ? + - < > ! : "'"

    set window formatcmd jfmt
    hook buffer BufWritePre .* %{format}

    map global normal -docstring 'Janet mode' § ': enter-user-mode janet<ret>'

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
