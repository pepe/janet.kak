# janet.kak

Just barebone Janet language mode, copied from the clojure.kak, for [Kakoune][1].

## Installation

### With [plug.kak][2] (recommended)

Just add this to your `kakrc`:

```kak
plug "pepe/janet.kak"
```

Then reload Kakoune config or restart Kakoune and run `:plug-install`.

### Formatting

To use auto format on save, you need to install [jfmt][3] and update your `kakrc` like so:

```kak
set-option global janet_autoformat true
set-option global janet_formatcmd jfmt
```

### Linting

To use auto lint before save, you need to install [jlnt][4] and update your `kakrc` like so:

```kak
set-option global janet_autolint true
set-option global janet_lintcmd jlnt
```

### User Mappings

`janet.kak` provides a user mode with various mappings to access Janet doc strings, surround forms with delimiters, paste some common snippets, and more.
To access this user mode, you need to add a mapping to the default user mode.

```kak
map global user -docstring 'Janet mode' J ': enter-user-mode janet<ret>'
```

[1]: https://github.com/mawww/kakoune
[2]: https://github.com/andreyorst/plug.kak
[3]: https://github.com/andrewchambers/jfmt
[4]: https://git.sr.ht/~pepe/jlnt.kak
