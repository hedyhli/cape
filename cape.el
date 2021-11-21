;;; cape.el --- Completion At Point Extensions -*- lexical-binding: t -*-

;; Author: Daniel Mendler
;; Created: 2021
;; License: GPL-3.0-or-later
;; Version: 0.1
;; Package-Requires: ((emacs "27.1"))
;; Homepage: https://github.com/minad/cape

;; This file is not part of GNU Emacs.

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; Make your completions fly! This package provides additional completion
;; backends in the form of capfs.

;;; Code:

(require 'dabbrev)

(defun cape--complete-in-region (thing table &rest extra)
  "Complete THING at point given completion TABLE and EXTRA properties."
  (let ((bounds (or (bounds-of-thing-at-point thing) (cons (point) (point))))
        (completion-extra-properties extra))
    (completion-in-region (car bounds) (cdr bounds) table)))

;;;###autoload
(defun cape-file-capf ()
  "File name completion-at-point-function."
  (when-let (bounds (bounds-of-thing-at-point 'filename))
    (list (car bounds) (cdr bounds)
          #'read-file-name-internal
          :exclusive 'no
          :annotation-function (lambda (_) " File"))))

;;;###autoload
(defun cape-file ()
  "Complete file name at point."
  (interactive)
  (cape--complete-in-region 'filename #'read-file-name-internal))

;;;###autoload
(defun cape-dabbrev-capf ()
  "Dabbrev completion-at-point-function."
  (let ((dabbrev-check-all-buffers nil)
        (dabbrev-check-other-buffers nil))
    (dabbrev--reset-global-variables))
  (let ((abbrev (ignore-errors (dabbrev--abbrev-at-point))))
    (when (and abbrev (not (string-match-p "[ \t]" abbrev)))
      (pcase ;; Interruptible scanning
          (while-no-input
            (let ((inhibit-message t)
                  (message-log-max nil))
              (or (dabbrev--find-all-expansions
                   abbrev (dabbrev--ignore-case-p abbrev))
                  t)))
        ('nil (keyboard-quit))
        ('t nil)
        (words
         ;; Ignore completions which are too short
         (let ((min-len (+ 4 (length abbrev))))
           (setq words (seq-remove (lambda (x) (< (length x) min-len)) words)))
         (when words
           (let ((beg (progn (search-backward abbrev) (point)))
                 (end (progn (search-forward abbrev) (point))))
             (unless (string-match-p "\n" (buffer-substring beg end))
               (list beg end words
                     :exclusive 'no
                     :annotation-function (lambda (_) " Dabbrev"))))))))))

(autoload 'ispell-lookup-words "ispell")

;;;###autoload
(defun cape-ispell-capf ()
  "Ispell completion-at-point-function."
  (when-let* ((bounds (bounds-of-thing-at-point 'word))
              (table (with-demoted-errors
                         (let ((message-log-max nil)
                               (inhibit-message t))
                           (ispell-lookup-words
                            (format "*%s*"
                                    (buffer-substring-no-properties (car bounds) (cdr bounds))))))))
    (list (car bounds) (cdr bounds) table
          :exclusive 'no
          :annotation-function (lambda (_) " Ispell"))))

;;;###autoload
(defun cape-ispell ()
  "Complete with Ispell at point."
  (interactive)
  (let ((completion-at-point-functions (list #'cape-ispell-capf)))
    (completion-at-point)))

(defvar cape--dict-words nil
  "List of dictionary words.")

(defvar cape--dict-file "/etc/dictionaries-common/words"
  "Dictionary word list file.")

(defun cape--dict-words ()
  "Return list of dictionary words."
  (or cape--dict-words
      (setq cape--dict-words
            (split-string (with-temp-buffer
                            (insert-file-contents-literally cape--dict-file)
                            (buffer-string))
                          "\n"))))

;;;###autoload
(defun cape-dict-capf ()
  "Dictionary completion-at-point-function."
  (when-let (bounds (bounds-of-thing-at-point 'word))
    (list (car bounds) (cdr bounds) (cape--dict-words)
          :exclusive 'no
          :annotation-function (lambda (_) " Dict"))))

;;;###autoload
(defun cape-dict ()
  "Complete word at point."
  (interactive)
  (cape--complete-in-region 'word (cape--dict-words)))

(defun cape--abbrev-completions ()
  "Return all abbreviations."
  (delete "" (nconc (all-completions "" global-abbrev-table)
                    (all-completions "" local-abbrev-table))))

(defun cape--abbrev-expand (&rest _)
  "Expand abbreviation before point."
  (expand-abbrev))

;;;###autoload
(defun cape-abbrev-capf ()
  "Abbrev completion-at-point-function."
  (when-let ((bounds (bounds-of-thing-at-point 'symbol))
             (abbrevs (cape--abbrev-completions)))
    (list (car bounds) (cdr bounds) abbrevs
          :exclusive 'no
          :exit-function #'cape--abbrev-expand
          :annotation-function (lambda (_) " Abbrev"))))

;;;###autoload
(defun cape-abbrev ()
  "Complete abbreviation at point."
  (interactive)
  (cape--complete-in-region 'symbol (or (cape--abbrev-completions)
                                        (user-error "No abbreviations"))
                            :exit-function #'cape--abbrev-expand))

(defvar cape-keywords
  ;; Taken from company-keywords.el
  ;; Please contribute corrections or additions.
  '((c++-mode ;; https://en.cppreference.com/w/cpp/keyword
     "alignas" "alignof" "and" "and_eq" "asm" "atomic_cancel" "atomic_commit"
     "atomic_noexcept" "auto" "bitand" "bitor" "bool" "break" "case" "catch"
     "char" "char16_t" "char32_t" "char8_t" "class" "co_await" "co_return"
     "co_yield" "compl" "concept" "const" "const_cast" "consteval" "constexpr"
     "constinit" "continue" "decltype" "default" "delete" "do" "double"
     "dynamic_cast" "else" "enum" "explicit" "export" "extern" "false" "final"
     "float" "for" "friend" "goto" "if" "import" "inline" "int" "long" "module"
     "mutable" "namespace" "new" "noexcept" "not" "not_eq" "nullptr" "operator"
     "or" "or_eq" "override" "private" "protected" "public" "reflexpr" "register"
     "reinterpret_cast" "requires" "return" "short" "signed" "sizeof" "static"
     "static_assert" "static_cast" "struct" "switch" "synchronized" "template"
     "this" "thread_local" "throw" "true" "try" "typedef" "typeid" "typename"
     "union" "unsigned" "using" "virtual" "void" "volatile" "wchar_t" "while"
     "xor" "xor_eq")
    (c-mode ;; https://en.cppreference.com/w/c/keyword
     "_Alignas" "_Alignof" "_Atomic" "_Bool" "_Complex" "_Generic" "_Imaginary"
     "_Noreturn" "_Static_assert" "_Thread_local"
     "auto" "break" "case" "char" "const" "continue" "default" "do"
     "double" "else" "enum" "extern" "float" "for" "goto" "if" "inline"
     "int" "long" "register" "restrict" "return" "short" "signed" "sizeof"
     "static" "struct" "switch" "typedef" "union" "unsigned" "void" "volatile"
     "while")
    (csharp-mode
     "abstract" "add" "alias" "as" "base" "bool" "break" "byte" "case"
     "catch" "char" "checked" "class" "const" "continue" "decimal" "default"
     "delegate" "do" "double" "else" "enum" "event" "explicit" "extern"
     "false" "finally" "fixed" "float" "for" "foreach" "get" "global" "goto"
     "if" "implicit" "in" "int" "interface" "internal" "is" "lock" "long"
     "namespace" "new" "null" "object" "operator" "out" "override" "params"
     "partial" "private" "protected" "public" "readonly" "ref" "remove"
     "return" "sbyte" "sealed" "set" "short" "sizeof" "stackalloc" "static"
     "string" "struct" "switch" "this" "throw" "true" "try" "typeof" "uint"
     "ulong" "unchecked" "unsafe" "ushort" "using" "value" "var" "virtual"
     "void" "volatile" "where" "while" "yield")
    (d-mode ;; http://www.digitalmars.com/d/2.0/lex.html
     "abstract" "alias" "align" "asm"
     "assert" "auto" "body" "bool" "break" "byte" "case" "cast" "catch"
     "cdouble" "cent" "cfloat" "char" "class" "const" "continue" "creal"
     "dchar" "debug" "default" "delegate" "delete" "deprecated" "do"
     "double" "else" "enum" "export" "extern" "false" "final" "finally"
     "float" "for" "foreach" "foreach_reverse" "function" "goto" "idouble"
     "if" "ifloat" "import" "in" "inout" "int" "interface" "invariant"
     "ireal" "is" "lazy" "long" "macro" "mixin" "module" "new" "nothrow"
     "null" "out" "override" "package" "pragma" "private" "protected"
     "public" "pure" "real" "ref" "return" "scope" "short" "static" "struct"
     "super" "switch" "synchronized" "template" "this" "throw" "true" "try"
     "typedef" "typeid" "typeof" "ubyte" "ucent" "uint" "ulong" "union"
     "unittest" "ushort" "version" "void" "volatile" "wchar" "while" "with")
    (f90-mode ;; f90.el
     "abs" "abstract" "achar" "acos" "adjustl" "adjustr" "aimag" "aint"
     "align" "all" "all_prefix" "all_scatter" "all_suffix" "allocatable"
     "allocate" "allocated" "and" "anint" "any" "any_prefix" "any_scatter"
     "any_suffix" "asin" "assign" "assignment" "associate" "associated"
     "asynchronous" "atan" "atan2" "backspace" "bind" "bit_size" "block"
     "btest" "c_alert" "c_associated" "c_backspace" "c_bool"
     "c_carriage_return" "c_char" "c_double" "c_double_complex" "c_f_pointer"
     "c_f_procpointer" "c_float" "c_float_complex" "c_form_feed" "c_funloc"
     "c_funptr" "c_horizontal_tab" "c_int" "c_int16_t" "c_int32_t" "c_int64_t"
     "c_int8_t" "c_int_fast16_t" "c_int_fast32_t" "c_int_fast64_t"
     "c_int_fast8_t" "c_int_least16_t" "c_int_least32_t" "c_int_least64_t"
     "c_int_least8_t" "c_intmax_t" "c_intptr_t" "c_loc" "c_long"
     "c_long_double" "c_long_double_complex" "c_long_long" "c_new_line"
     "c_null_char" "c_null_funptr" "c_null_ptr" "c_ptr" "c_short"
     "c_signed_char" "c_size_t" "c_vertical_tab" "call" "case" "ceiling"
     "char" "character" "character_storage_size" "class" "close" "cmplx"
     "command_argument_count" "common" "complex" "conjg" "contains" "continue"
     "copy_prefix" "copy_scatter" "copy_suffix" "cos" "cosh" "count"
     "count_prefix" "count_scatter" "count_suffix" "cpu_time" "cshift"
     "cycle" "cyclic" "data" "date_and_time" "dble" "deallocate" "deferred"
     "digits" "dim" "dimension" "distribute" "do" "dot_product" "double"
     "dprod" "dynamic" "elemental" "else" "elseif" "elsewhere" "end" "enddo"
     "endfile" "endif" "entry" "enum" "enumerator" "eoshift" "epsilon" "eq"
     "equivalence" "eqv" "error_unit" "exit" "exp" "exponent" "extends"
     "extends_type_of" "external" "extrinsic" "false" "file_storage_size"
     "final" "floor" "flush" "forall" "format" "fraction" "function" "ge"
     "generic" "get_command" "get_command_argument" "get_environment_variable"
     "goto" "grade_down" "grade_up" "gt" "hpf_alignment" "hpf_distribution"
     "hpf_template" "huge" "iachar" "iall" "iall_prefix" "iall_scatter"
     "iall_suffix" "iand" "iany" "iany_prefix" "iany_scatter" "iany_suffix"
     "ibclr" "ibits" "ibset" "ichar" "ieee_arithmetic" "ieee_exceptions"
     "ieee_features" "ieee_get_underflow_mode" "ieee_set_underflow_mode"
     "ieee_support_underflow_control" "ieor" "if" "ilen" "implicit"
     "import" "include" "independent" "index" "inherit" "input_unit"
     "inquire" "int" "integer" "intent" "interface" "intrinsic" "ior"
     "iostat_end" "iostat_eor" "iparity" "iparity_prefix" "iparity_scatter"
     "iparity_suffix" "ishft" "ishftc" "iso_c_binding" "iso_fortran_env"
     "kind" "lbound" "le" "leadz" "len" "len_trim" "lge" "lgt" "lle" "llt"
     "log" "log10" "logical" "lt" "matmul" "max" "maxexponent" "maxloc"
     "maxval" "maxval_prefix" "maxval_scatter" "maxval_suffix" "merge"
     "min" "minexponent" "minloc" "minval" "minval_prefix" "minval_scatter"
     "minval_suffix" "mod" "module" "modulo" "move_alloc" "mvbits" "namelist"
     "ne" "nearest" "neqv" "new" "new_line" "nint" "non_intrinsic"
     "non_overridable" "none" "nopass" "not" "null" "nullify"
     "number_of_processors" "numeric_storage_size" "only" "onto" "open"
     "operator" "optional" "or" "output_unit" "pack" "parameter" "parity"
     "parity_prefix" "parity_scatter" "parity_suffix" "pass" "pause"
     "pointer" "popcnt" "poppar" "precision" "present" "print" "private"
     "procedure" "processors" "processors_shape" "product" "product_prefix"
     "product_scatter" "product_suffix" "program" "protected" "public"
     "pure" "radix" "random_number" "random_seed" "range" "read" "real"
     "realign" "recursive" "redistribute" "repeat" "reshape" "result"
     "return" "rewind" "rrspacing" "same_type_as" "save" "scale" "scan"
     "select" "selected_char_kind" "selected_int_kind" "selected_real_kind"
     "sequence" "set_exponent" "shape" "sign" "sin" "sinh" "size" "spacing"
     "spread" "sqrt" "stop" "subroutine" "sum" "sum_prefix" "sum_scatter"
     "sum_suffix" "system_clock" "tan" "tanh" "target" "template" "then"
     "tiny" "transfer" "transpose" "trim" "true" "type" "ubound" "unpack"
     "use" "value" "verify" "volatile" "wait" "where" "while" "with" "write")
    (go-mode ;; https://golang.org/ref/spec#Keywords, https://golang.org/pkg/builtin/
     "append" "bool" "break" "byte" "cap" "case" "chan" "close" "complex" "complex128"
     "complex64" "const" "continue" "copy" "default" "defer" "delete" "else" "error"
     "fallthrough" "false" "float32" "float64" "for" "func" "go" "goto" "if" "imag"
     "import" "int" "int16" "int32" "int64" "int8" "interface" "len" "make"
     "map" "new" "nil" "package" "panic" "print" "println" "range" "real" "recover"
     "return" "rune" "select" "string" "struct" "switch" "true" "type" "uint" "uint16"
     "uint32" "uint64" "uint8" "uintptr" "var")
    (java-mode
     "abstract" "assert" "boolean" "break" "byte" "case" "catch" "char" "class"
     "continue" "default" "do" "double" "else" "enum" "extends" "final"
     "finally" "float" "for" "if" "implements" "import" "instanceof" "int"
     "interface" "long" "native" "new" "package" "private" "protected" "public"
     "return" "short" "static" "strictfp" "super" "switch" "synchronized"
     "this" "throw" "throws" "transient" "try" "void" "volatile" "while")
    (javascript-mode ;; https://tc39.github.io/ecma262/
     "async" "await" "break" "case" "catch" "class" "const" "continue"
     "debugger" "default" "delete" "do" "else" "enum" "export" "extends" "false"
     "finally" "for" "function" "if" "import" "in" "instanceof" "let" "new"
     "null" "return" "static" "super" "switch" "this" "throw" "true" "try"
     "typeof" "undefined" "var" "void" "while" "with" "yield")
    (kotlin-mode
     "abstract" "annotation" "as" "break" "by" "catch" "class" "companion"
     "const" "constructor" "continue" "data" "do" "else" "enum" "false" "final"
     "finally" "for" "fun" "if" "import" "in" "init" "inner" "interface"
     "internal" "is" "lateinit" "nested" "null" "object" "open" "out" "override"
     "package" "private" "protected" "public" "return" "super" "this" "throw"
     "trait" "true" "try" "typealias" "val" "var" "when" "while")
    (lua-mode ;; https://www.lua.org/manual/5.3/manual.html
     "and" "break" "do" "else" "elseif" "end" "false" "for" "function" "goto" "if"
     "in" "local" "nil" "not" "or" "repeat" "return" "then" "true" "until" "while")
    (objc-mode
     "@catch" "@class" "@encode" "@end" "@finally" "@implementation"
     "@interface" "@private" "@protected" "@protocol" "@public"
     "@selector" "@synchronized" "@throw" "@try" "alloc" "autorelease"
     "bycopy" "byref" "in" "inout" "oneway" "out" "release" "retain")
    (perl-mode ;; cperl.el
     "AUTOLOAD" "BEGIN" "CHECK" "CORE" "DESTROY" "END" "INIT" "__END__"
     "__FILE__" "__LINE__" "abs" "accept" "alarm" "and" "atan2" "bind"
     "binmode" "bless" "caller" "chdir" "chmod" "chomp" "chop" "chown" "chr"
     "chroot" "close" "closedir" "cmp" "connect" "continue" "cos"
     "crypt" "dbmclose" "dbmopen" "defined" "delete" "die" "do" "dump" "each"
     "else" "elsif" "endgrent" "endhostent" "endnetent" "endprotoent"
     "endpwent" "endservent" "eof" "eq" "eval" "exec" "exists" "exit" "exp"
     "fcntl" "fileno" "flock" "for" "foreach" "fork" "format" "formline"
     "ge" "getc" "getgrent" "getgrgid" "getgrnam" "gethostbyaddr"
     "gethostbyname" "gethostent" "getlogin" "getnetbyaddr" "getnetbyname"
     "getnetent" "getpeername" "getpgrp" "getppid" "getpriority"
     "getprotobyname" "getprotobynumber" "getprotoent" "getpwent" "getpwnam"
     "getpwuid" "getservbyname" "getservbyport" "getservent" "getsockname"
     "getsockopt" "glob" "gmtime" "goto" "grep" "gt" "hex" "if" "index" "int"
     "ioctl" "join" "keys" "kill" "last" "lc" "lcfirst" "le" "length"
     "link" "listen" "local" "localtime" "lock" "log" "lstat" "lt" "map"
     "mkdir" "msgctl" "msgget" "msgrcv" "msgsnd" "my" "ne" "next" "no"
     "not" "oct" "open" "opendir" "or" "ord" "our" "pack" "package" "pipe"
     "pop" "pos" "print" "printf" "push" "q" "qq" "quotemeta" "qw" "qx"
     "rand" "read" "readdir" "readline" "readlink" "readpipe" "recv" "redo"
     "ref" "rename" "require" "reset" "return" "reverse" "rewinddir" "rindex"
     "rmdir" "scalar" "seek" "seekdir" "select" "semctl" "semget" "semop"
     "send" "setgrent" "sethostent" "setnetent" "setpgrp" "setpriority"
     "setprotoent" "setpwent" "setservent" "setsockopt" "shift" "shmctl"
     "shmget" "shmread" "shmwrite" "shutdown" "sin" "sleep" "socket"
     "socketpair" "sort" "splice" "split" "sprintf" "sqrt" "srand" "stat"
     "study" "sub" "substr" "symlink" "syscall" "sysopen" "sysread" "system"
     "syswrite" "tell" "telldir" "tie" "time" "times" "tr" "truncate" "uc"
     "ucfirst" "umask" "undef" "unless" "unlink" "unpack" "unshift" "untie"
     "until" "use" "utime" "values" "vec" "wait" "waitpid"
     "wantarray" "warn" "while" "write" "x" "xor" "y")
    (php-mode
     "__CLASS__" "__DIR__" "__FILE__" "__FUNCTION__" "__LINE__" "__METHOD__"
     "__NAMESPACE__" "_once" "abstract" "and" "array" "as" "break" "case"
     "catch" "cfunction" "class" "clone" "const" "continue" "declare"
     "default" "die" "do" "echo" "else" "elseif" "empty" "enddeclare"
     "endfor" "endforeach" "endif" "endswitch" "endwhile" "eval" "exception"
     "exit" "extends" "final" "for" "foreach" "function" "global"
     "goto" "if" "implements" "include" "instanceof" "interface"
     "isset" "list" "namespace" "new" "old_function" "or" "php_user_filter"
     "print" "private" "protected" "public" "require" "require_once" "return"
     "static" "switch" "this" "throw" "try" "unset" "use" "var" "while" "xor")
    (python-mode ;; https://docs.python.org/3/reference/lexical_analysis.html#keywords
     "False" "None" "True" "and" "as" "assert" "break" "class" "continue" "def"
     "del" "elif" "else" "except" "exec" "finally" "for" "from" "global" "if"
     "import" "in" "is" "lambda" "nonlocal" "not" "or" "pass" "print" "raise"
     "return" "try" "while" "with" "yield")
    (ruby-mode
     "BEGIN" "END" "alias" "and"  "begin" "break" "case" "class" "def" "defined?"
     "do" "else" "elsif"  "end" "ensure" "false" "for" "if" "in" "module"
     "next" "nil" "not" "or" "redo" "rescue" "retry" "return" "self" "super"
     "then" "true" "undef" "unless" "until" "when" "while" "yield")
    (rust-mode ;; https://doc.rust-lang.org/grammar.html#keywords
     "Self" "as" "box" "break" "const" "continue" "crate" "else" "enum" "extern"
     "false" "fn" "for" "if" "impl" "in" "let" "loop" "macro" "match" "mod"
     "move" "mut" "pub" "ref" "return" "self" "static" "struct" "super"
     "trait" "true" "type" "unsafe" "use" "where" "while")
    (scala-mode
     "abstract" "case" "catch" "class" "def" "do" "else" "extends" "false"
     "final" "finally" "for" "forSome" "if" "implicit" "import" "lazy" "match"
     "new" "null" "object" "override" "package" "private" "protected"
     "return" "sealed" "super" "this" "throw" "trait" "true" "try" "type" "val"
     "var" "while" "with" "yield")
    (swift-mode
     "Protocol" "Self" "Type" "and" "as" "assignment" "associatedtype"
     "associativity" "available" "break" "case" "catch" "class" "column" "continue"
     "convenience" "default" "defer" "deinit" "didSet" "do" "dynamic" "dynamicType"
     "else" "elseif" "endif" "enum" "extension" "fallthrough" "false" "file"
     "fileprivate" "final" "for" "func" "function" "get" "guard" "higherThan" "if"
     "import" "in" "indirect" "infix" "init" "inout" "internal" "is" "lazy" "left"
     "let" "line" "lowerThan" "mutating" "nil" "none" "nonmutating" "open"
     "operator" "optional" "override" "postfix" "precedence" "precedencegroup"
     "prefix" "private" "protocol" "public" "repeat" "required" "rethrows" "return"
     "right" "selector" "self" "set" "static" "struct" "subscript" "super" "switch"
     "throw" "throws" "true" "try" "typealias" "unowned" "var" "weak" "where"
     "while" "willSet")
    (julia-mode
     "abstract" "break" "case" "catch" "const" "continue" "do" "else" "elseif"
     "end" "eval" "export" "false" "finally" "for" "function" "global" "if"
     "ifelse" "immutable" "import" "importall" "in" "let" "macro" "module"
     "otherwise" "quote" "return" "switch" "throw" "true" "try" "type"
     "typealias" "using" "while")
    (thrift-mode ;; https://github.com/apache/thrift/blob/master/contrib/thrift.el
     "binary" "bool" "byte" "const" "double" "enum" "exception" "extends"
     "i16" "i32" "i64" "include" "list" "map" "oneway" "optional" "required"
     "service" "set" "string" "struct" "throws" "typedef" "void")
    ;; Aliases
    (js2-mode javascript-mode)
    (js2-jsx-mode javascript-mode)
    (espresso-mode javascript-mode)
    (js-mode javascript-mode)
    (js-jsx-mode javascript-mode)
    (rjsx-mode javascript-mode)
    (cperl-mode perl-mode)
    (jde-mode java-mode)
    (ess-julia-mode julia-mode)
    (enh-ruby-mode ruby-mode))
  "Alist of major modes and keywords.")

(defun cape--keywords ()
  "Return keywords for current major mode."
  (when-let (kw (alist-get major-mode cape-keywords))
    (if (symbolp (cadr kw)) (alist-get (cadr kw) cape-keywords) kw)))

;;;###autoload
(defun cape-keyword-capf ()
  "Dictionary completion-at-point-function."
  (when-let ((bounds (bounds-of-thing-at-point 'symbol))
             (keywords (cape--keywords)))
    (list (car bounds) (cdr bounds) keywords
          :exclusive 'no
          :annotation-function (lambda (_) " Keyword"))))

;;;###autoload
(defun cape-keyword ()
  "Complete word at point."
  (interactive)
  (cape--complete-in-region 'symbol
                            (or (cape--keywords)
                                (user-error "No keywords for %s" major-mode))))

(provide 'cape)
;;; cape.el ends here
