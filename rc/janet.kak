# http://janet-lang.org
# ‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾

# require lisp.kak

# Detection
# ‾‾‾‾‾‾‾‾‾

hook global BufCreate .*[.](janet|jdn) %{
    set-option buffer filetype janet
}

# Options
# ‾‾‾‾‾‾‾

declare-option -docstring %{
    enable format on save for Janet files
} bool janet_autoformat false

declare-option -docstring %{
    the command to use to format Janet files
} str janet_formatcmd 'jfmt'

declare-option -docstring %{
    enable lint on save for Janet files
} bool janet_autolint false

declare-option -docstring %{
    the command to use to lint Janet files
} str janet_lintcmd 'jlnt'

# Initialization
# ‾‾‾‾‾‾‾‾‾‾‾‾‾‾

hook global BufSetOption filetype=janet %{
    require-module janet
    janet-configure-buffer
}

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
add-highlighter shared/janet/string  region '(^\s+```)|(?<!\\)(?:\\\\)*\K"' '(^\s+```)|(?<!\\)(?:\\\\)*"' fill string

add-highlighter shared/janet/code/ regex \b(nil|true|false)\b 0:value
add-highlighter shared/janet/code/ regex \
    \\(?:j|tab|newline|return|backspace|formfeed|u[0-9a-fA-F]{4}|o[0-3]?[0-7]{1,2}|.)\b 0:string

evaluate-commands %sh{
    symbol_char='[^\s()\[\]{}"\;@^`~\\%/]'
    modules="
    array buffer ev debug fiber file int janet math module net os parser peg string
    table tarray thread tuple"
    keywords="
$(janet -e '(print (string "def var fn do quote if splice while break set quasiquote unquote upscope "(string/slice (string/format "%j" (all-bindings)) 2 -2)))')
    "

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
    # -- Janet OUTPUT stored in %reg{o}
    set-register o %sh{
      output=$(mktemp -d "${TMPDIR:-/tmp}"/kak-janet-doc.XXXXXXXX)/fifo
      mkfifo $output
      printf "%s" "$output"
   }
   # -- Execute janet doc
   nop %sh{
     ( janet -q -e "(print (doc ${kak_selection}))" | tr -d '\r' > ${kak_reg_o} 2>&1 & ) > /dev/null 2>&1 < /dev/null }
   # -- Setup and populate *doc* bufferne
   edit! -fifo %reg{o} *doc*
   set-option buffer filetype scratch
   hook -always -once buffer BufCloseFifo .* %{ nop %sh{ rm -r $(dirname ${kak_reg_o}) } }
}}

define-command janet-fly %{ evaluate-commands  %{
    write
    # -- Janet OUTPUT stored in %reg{o}
    set-register o %sh{
      output=$(mktemp -d "${TMPDIR:-/tmp}"/kak-janet-fly.XXXXXXXX)/fifo
      mkfifo $output
      printf "%s" "$output"
   }
   # -- Execute janet -k
   nop %sh{
     ( janet -k ${kak_buffile}  2>&1 >/dev/null | tr -d '\r' > ${kak_reg_o} 2>&1 & ) > /dev/null 2>&1 < /dev/null }

   edit! -fifo %reg{o} *flycheck*
   set-option buffer filetype scratch
   hook -always -once buffer BufCloseFifo .* %{ nop %sh{ rm -r $(dirname ${kak_reg_o}) } }
}}

declare-user-mode janet
map global janet -docstring 'repl'      r ': connect-terminal janet<ret>'
map global janet -docstring 'tracev'    t ': surround<ret>(<a-;>itracev <esc>'
map global janet -docstring 'strip '    T 'edd: delete-surround<ret>( <esc>'
map global janet -docstring 'Janet doc' d ': janet-doc<ret>'
map global janet -docstring 'wrap'      w ': surround<ret>(ma<esc>'
map global janet -docstring 'unwrap'    W ': delete-surround<ret>('
map global janet -docstring 'snips'     s ': enter-user-mode janet-snips<ret>'
map global janet -docstring 'comment'   c ': comment-line<ret>'
map global janet -docstring 'Comment'   C ': comment-block<ret>'

declare-user-mode janet-snips
map global janet-snips -docstring 'fn'        f     ': surround<ret>(<a-;>ifn []'
map global janet-snips -docstring 'defn'      F     ': surround<ret>(<a-;>idefn [] <esc><a-;>hi'
map global janet-snips -docstring 'defn-'     <a-F> ': surround<ret>(<a-;>idefn- [] <esc><a-;>hi'
map global janet-snips -docstring 'def'       D     ': surround<ret>(<a-;>idef  <esc>hi'
map global janet-snips -docstring 'def-'      <a-d> ': surround<ret>(<a-;>idef-  <esc>hi'
map global janet-snips -docstring 'var'       v     ': surround<ret>(<a-;>ivar  <esc>hi'
map global janet-snips -docstring 'var-'      <a-v> ': surround<ret>(<a-;>ivar-  <esc>hi'
map global janet-snips -docstring 'if'        i     ': surround<ret>(<a-;>iif  <esc>hi'
map global janet-snips -docstring 'when'      w     ': surround<ret>(<a-;>iwhen  <esc>hi'
map global janet-snips -docstring 'default'   e     ': surround<ret>(<a-;>idefault  <esc>hi'

define-command -hidden janet-configure-window %{
    hook window ModeChange pop:insert:.* -group janet-trim-indent  janet-trim-indent
    hook window InsertChar \n -group janet-indent janet-indent-on-new-line

    set-option buffer extra_word_chars '_' - . / * ? + < > ! : "'"
    hook -once -always window WinSetOption filetype=.* %{ remove-hooks window janet-.+ }
}

define-command -hidden janet-configure-buffer %{
    set-option buffer comment_line '#'
    set-option buffer comment_block_begin '(comment '
    set-option buffer comment_block_end ')'

    evaluate-commands %sh{
        [ "${KAK_OPT_JANET_AUTOLINT}" = false ] || {
            printf '%s' '
                set-option buffer lintcmd %opt{janet_lintcmd}
                hook buffer BufWritePre .* -group janet-autolint %{lint}
                hook -once -always buffer BufSetOption filetype=.* %{
                    remove-hooks buffer janet-autolint
                }
            '
        }
        [ "${KAK_OPT_JANET_AUTOFORMAT}" = false ] || {
            printf '%s' '
                set-option buffer formatcmd %opt{janet_formatcmd}
                hook buffer BufWritePre .* -group janet-autoformat %{format}
                hook -once -always buffer BufSetOption filetype=.* %{
                    remove-hooks buffer janet-autoformat
                }
            '
        }
    }
}

define-command -hidden janet-trim-indent lisp-trim-indent

define-command -hidden janet-filter-around-selections lisp-filter-around-selections

declare-option \
    -docstring 'regex matching the head of forms which have options *and* indented bodies' \
    regex janet_special_indent_forms \
    '(?:def.*|while|for|fn\*?|if(-.*|)|let.*|loop|seq|with(-.*|)|when(-.*|))|defer|do|match|var'

define-command -hidden janet-indent-on-new-line %{
    # registers: i = best align point so far; w = start of first word of form
    evaluate-commands -draft -save-regs '/"|^@iw' -itersel %{
        execute-keys -draft 'gk"iZ'
        try %{
            execute-keys -draft '[bl"i<a-Z><gt>"wZ'

            try %{
                # If a special form, indent another j
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
