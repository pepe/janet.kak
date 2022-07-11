# http://janet-lang.org
# ‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾

# Override built-in janet.kak hooks
remove-hooks global janet

# Detection
# ‾‾‾‾‾‾‾‾‾

hook -group janet global BufCreate '.*[.](janet|jdn)' %{
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

hook -group janet global BufSetOption filetype=janet %{
    require-module janet
    janet-configure-buffer
}

hook -group janet global WinSetOption filetype=janet %{
    require-module janet
    janet-configure-window
}

hook -group janet global WinSetOption filetype=janet %{
    add-highlighter window/janet ref janet
    hook -once -always window WinSetOption filetype=.* %{ remove-highlighter window/janet }
}

hook -group janet global BufNewFile .*[.](janet|jdn) %{
    require-module janet
}

provide-module -override janet %{

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
$(janet -e '(print (string "def var fn do quote if splice while break set quasiquote unquote upscope "(string/slice (string/replace "%" "%%" (string/format "%j" (all-bindings))) 2 -2)))')
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

    printf "%s" "
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

define-command fix-indentation-of-multiline-selections %{ try %{
  # Eliminate single line selections.
  execute-keys -draft '<a-k>\A[^\n]*\n.<ret>'
  # Fix indentation of the remaining multi line selections
  execute-keys -draft -with-hooks '<a-J>i<ret><esc>'
} }

declare-user-mode janet
map global janet -docstring 'Janet doc' d ': janet-doc<ret>'
map global janet -docstring 'Janet flycheck (error check)' f ': janet-fly<ret>'
map global janet -docstring 'Comment line'   c ': comment-line<ret>'
map global janet -docstring 'Comment block'   C ': comment-block<ret>'
map -docstring 'Fix indentation of multiline selections' \
global janet '<tab>' ': fix-indentation-of-multiline-selections<ret>'

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
        [ "${kak_opt_janet_autolint}" = false ] || {
            printf '%s' '
                set-option buffer lintcmd %opt{janet_lintcmd}
                hook buffer BufWritePre .* -group janet-autolint %{lint}
                hook -once -always buffer BufSetOption filetype=.* %{
                    remove-hooks buffer janet-autolint
                }
            '
        }
        [ "${kak_opt_janet_autoformat}" = false ] || {
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
    -docstring 'regex matching the head of special forms' \
    str-list janet_special_indent_forms \
    '(?:' \
    'def.*|while|for|fn\*?|if(-.*|)|let.*|loop|seq|with(-.*|)|when(-.*|)|' \
    'defer|do|match|var|try|case|cond|generate|unless' \
    ')'

define-command -hidden janet-indent-2-spaces %{ try %{
    execute-keys -draft '"wzh<a-l>Ls\A.{2}\K.*\z<ret><a-;>;"i<a-Z><gt>'
} }

define-command -hidden janet-indent-on-new-line %{
    # registers: i = best align point so far; w = start of first word of form
    evaluate-commands -draft -save-regs '/"|^@iw' -itersel %{
        # Assign the left-most position to i register.
        execute-keys -draft 'gk"iZ'
        # Remove leading spaces in the current line.
        try %{ execute-keys -draft '<a-i><space>d' }
        # Remove trailing spaces in the previous line
        try %{ execute-keys -draft 'kgl<a-i><space>d' }
        # Try to indent inside a pair of parentheses.
        try %{
            # Set w register and i register to
            # the position to the right of an opening parenthesis.
            execute-keys -draft '[bl"i<a-Z><gt>"wZ'

            try %{
                # If it is a special form, indent 2 spaces.
                execute-keys -draft '"wz<a-l>s\A\h*\K\S+<ret>' \
                '<a-k>\A' %opt{janet_special_indent_forms} '\z<ret>'
                janet-indent-2-spaces
            } catch %{
                # If it is not special, and parameters appear on line 1,
                # indent to the first parameter
                execute-keys -draft '"wz<a-l>s\A\h*\K\S+<ret>' \
                '<a-l>s\h\K[^\s].*\z<ret><a-;>;"i<a-Z><gt>'
            } catch %{
                # If it is not special, and parameters appear on next lines,
                janet-indent-2-spaces
            }
        }
        # Should the line be indented to the right of an opening bracket?
        try %{ execute-keys -draft '[rl"i<a-Z><gt>' }
        # Should the line be indented to the right of an opening brace?
        try %{ execute-keys -draft '[Bl"i<a-Z><gt>' }
        # Align the current line with i register.
        # `;` reduces selections to cursors so that `&` works without an issue
        execute-keys -draft ';"i<a-z>a&<space>'
    }
}
}
