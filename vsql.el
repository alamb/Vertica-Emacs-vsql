;; *****************************************************
;; ********************* vsql emacs mode ***************
;; *****************************************************
;;
;; Heavily based on psql mode in 
;;   /usr/share/emacs/21.4/lisp/progmodes/sql.el
;; And by 'heavily based' I mean copy/paste/modify
;;
;; Change History:
;;   Initial Version: Andrew Lamb 11/16/2010
;;
;; This file is based on code from GNU Emacs.
;;
;; This program is free software: you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation, either version 3 of the
;; License, or (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see
;; <http://www.gnu.org/licenses/>.

(require 'sql)

(defcustom sql-vertica-program "vsql"
  "Command to start vsql by Vertica Systems."
  :type 'file
  :group 'SQL)

(defcustom sql-vertica-options '("-P" "pager=off")
  "*List of additional options for `sql-vertica-program'.
If you want to provide a username on the command line
add your name with a \"-U\" prefix (such as \"-Umark\") to the list."
  :type '(repeat string)
  :version "20.8"
  :group 'SQL)

(defcustom sql-port ""
  "*Default port (Vertica)."
  :type 'string
  :group 'SQL)


;; Specialized function to ask user for port (useful to connect to
;; remote development databases where the port is based on username)
(defun sql-get-vertica-port ()
  (interactive)
  (setq sql-port
	(read-from-minibuffer "Port: " sql-port nil nil
			      sql-user-history)))


;;;;;;;;;;;;; Fontlock stuff: keywords, etc.
(defvar sql-mode-vertica-font-lock-keywords nil
  "Vertica SQL keywords used by font-lock.

This variable is used by `sql-mode' and `sql-interactive-mode'.  The
regular expressions are created during compilation by calling the
function `regexp-opt'.  Therefore, take a look at the source before
you define your own sql-mode-vertica-font-lock-keywords.")

(if sql-mode-vertica-font-lock-keywords
    ()
  (let ((vertica-reserved-words (eval-when-compile
				 (concat "\\b"
					 (regexp-opt '(
"language"
) t) "\\b")))
	(vertica-types (eval-when-compile
			  (concat "\\b"
				  (regexp-opt '(
"bool" "box" "circle" "char" "char2" "char4" "char8" "char16" "date"
"float4" "float8" "int2" "int4" "int8" "line" "lseg" "money" "path"
"point" "polygon" "serial" "text" "time" "timespan" "timestamp" "varchar"
) t)"\\b")))
	(vertica-builtin-functions (eval-when-compile
			(concat "\\b"
				(regexp-opt '(
;; Misc Vertica builtin functions (need scrubbing)
"abstime" "age" "center" "date_part" "date_trunc"
"datetime" "dexp" "diameter" "dpow" "float" "height"
"initcap" "integer" "isclosed" "isfinite" 
"length" "lower" "lpad" "ltrim"
"position" "radius" "reltime" "revertpoly" "rpad" "rtrim" "substr"
"substring" "text" "timespan" "translate" "trim" 
"upper" "varchar" "width"
) t) "\\b"))))
    (setq sql-mode-vertica-font-lock-keywords
	  (append sql-mode-ansi-font-lock-keywords
		  (list (cons vertica-reserved-words 'font-lock-keyword-face)
			;; XEmacs doesn't have 'font-lock-builtin-face
			(if (string-match "XEmacs\\|Lucid" emacs-version)
			    (cons vertica-builtin-functions 'font-lock-preprocessor-face)
			  ;; Emacs
			  (cons vertica-builtin-functions 'font-lock-builtin-face))
			(cons vertica-types 'font-lock-type-face))))))



;;;###autoload
(defun sql-vertica ()
  "Run vsql Vertica Analytic Database client as an inferior process.

If buffer `*SQL*' exists but no process is running, make a new process.
If buffer exists and a process is running, just switch to buffer
`*SQL*'.

Interpreter used comes from variable `sql-vertica-program'.  Login uses
the variables `sql-database' and `sql-server' as default, if set.
Additional command line parameters can be stored in the list
`sql-vertica-options'.

The buffer is put in sql-interactive-mode, giving commands for sending
input.  See `sql-interactive-mode'.

To specify a coding system for converting non-ASCII characters
in the input and output to the process, use \\[universal-coding-system-argument]
before \\[sql-postgres].  You can also specify this with \\[set-buffer-process-coding-system]
in the SQL buffer, after you start the process.
The default comes from `process-coding-system-alist' and
`default-process-coding-system'.  If your output lines end with ^M,
your might try undecided-dos as a coding system.  If this doesn't help,
Try to set `comint-output-filter-functions' like this:

\(setq comint-output-filter-functions (append comint-output-filter-functions
					     '(comint-strip-ctrl-m)))

\(Type \\[describe-mode] in the SQL buffer for a list of commands.)"
  (interactive)
  (if (comint-check-proc "*SQL*")
      (pop-to-buffer "*SQL*")
    ;; Use standard read function to get server, user, password, custom to get port
    (sql-get-login 'server)
    (sql-get-vertica-port)
    (sql-get-login 'user 'password)

    (message "Login to Vertica...")
    ;; username and password are ignored.  Mark Stosberg suggest to add
    ;; the database at the end.  Jason Beegan suggest using --pset and
    ;; pager=off instead of \\o|cat.  The later was the solution by
    ;; Gregor Zych.  Jason's suggestion is the default value for
    ;; sql-postgres-options.
    (let ((params sql-vertica-options))
      (if (not (string= "" sql-user))
	  (setq params (append (list "-U" sql-user) params)))
      (if (not (string= "" sql-password))
	  (setq params (append (list "-w" sql-password) params)))
      (if (not (string= "" sql-server))
	  (setq params (append (list "-h" sql-server) params)))
      (if (not (string= "" sql-port))
	  (setq params (append (list "-p" sql-port) params)))
      (set-buffer (apply 'make-comint "SQL" sql-vertica-program
			 nil params)))
    (setq sql-prompt-regexp "^.*> *")
    (setq sql-prompt-length 5)
    ;; This is a lousy hack to prevent psql from truncating it's output
    ;; and giving stupid warnings. If s.o. knows a way to prevent psql
    ;; from acting this way, then I would be very thankful to
    ;; incorporate this (Gregor Zych <zych@pool.informatik.rwth-aachen.de>)
    ;; (comint-send-string "*SQL*" "\\o \| cat\n")
    (setq sql-mode-font-lock-keywords sql-mode-vertica-font-lock-keywords)
    (setq sql-buffer (current-buffer))
    (sql-interactive-mode)
    (message "Login...done")
    (pop-to-buffer sql-buffer)))


