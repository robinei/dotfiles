;; Minimize garbage collection during startup
(setq gc-cons-threshold most-positive-fixnum)
(add-hook 'emacs-startup-hook ; Lower threshold back to 8 MiB (default is 800kB)
          (lambda ()
            (setq gc-cons-threshold (expt 2 23))))

;; Package management
(require 'package)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
(setq package-native-compile t)
(setq package-enable-at-startup nil) ; To prevent initialising twice

;; use-package
(unless (package-installed-p 'use-package)
  (package-refresh-contents)
  (package-install 'use-package))
(eval-when-compile
  (require 'use-package))

;; Init benchmark benchmark-init/show-durations-tree
'(use-package benchmark-init
   :ensure t
   :config
   (add-hook 'after-init-hook 'benchmark-init/deactivate))

;; Basic behavior and looks
(setq ad-redefinition-action 'accept)
(setq inhibit-startup-message t)
(setq ring-bell-function 'ignore)
(fset 'yes-or-no-p 'y-or-n-p)
(setq make-backup-files nil)
(setq auto-save-list-file-name nil)
(setq auto-save-default nil)
(setq use-dialog-box nil)
(menu-bar-mode -1)
(tool-bar-mode -1)
(scroll-bar-mode -1)
(setq default-frame-alist
      '((font . "Envy Code R-10")
	(vertical-scroll-bars . nil)
	(horizontal-scroll-bars . nil)
	(menu-bar-lines . 0)
	(tool-bar-lines . 0)))

;; Syntax highlighting
(global-font-lock-mode t)
(setq font-lock-maximum-decoration t)

;; Theme
(load-theme 'deeper-blue t)
(set-background-color "black")
(unless window-system
  (add-hook 'window-setup-hook
	    (lambda ()
	      (set-face-background 'default "unspecified-bg" (selected-frame)))))
(set-face-background 'mode-line "#666666")
(set-face-background 'mode-line-inactive "#444444")
(mapc ; disable bold
 (lambda (face)
   (when (eq (face-attribute face :weight) 'bold)
     (set-face-attribute face nil :weight 'normal)))
 (face-list))
(set-face-attribute 'vertical-border nil :foreground ; make jarring vertical split line meld with margin/fringe
		    (face-attribute 'fringe :background))

;; Highlight current line
(defface hl-line '((t (:background "#111111")))
  "Face to use for `hl-line-face'." :group 'hl-line)
(setq hl-line-face 'hl-line)
(global-hl-line-mode t)

;; Show line numbers
(global-display-line-numbers-mode)

;; Text encoding
(prefer-coding-system 'utf-8)
(set-terminal-coding-system 'utf-8)
(setq default-buffer-file-coding-system 'utf-8)
(set-keyboard-coding-system 'utf-8)
(setq x-select-request-type '(UTF8_STRING COMPOUND_TEXT TEXT STRING))
(if (eq system-type 'windows-nt)
    (set-clipboard-coding-system 'utf-16le-dos))

;; Reload changed files automatically
(global-auto-revert-mode t)

(put 'dired-find-alternate-file 'disabled nil)

;; Make page up/down able to scroll to very first or last line
(defun do-scroll-up ()
  (interactive)
  (condition-case nil
      (scroll-down) (beginning-of-buffer (goto-char (point-min)))))
(defun do-scroll-down ()
  (interactive)
  (condition-case nil
      (scroll-up) (end-of-buffer (goto-char (point-max)))))
(global-set-key (kbd "<prior>") 'do-scroll-up)
(global-set-key (kbd "<next>") 'do-scroll-down)
(global-set-key (kbd "M-v") 'do-scroll-up)
(global-set-key (kbd "C-v") 'do-scroll-down)

;; icomplete, with some ido key-binds
(fido-mode)

(setq default-directory (concat (getenv "HOME") "/"))

;; ssh file editing
(if (eq system-type 'windows-nt)
    (setq tramp-default-method "plink")
    (setq tramp-default-method "ssh"))

;; "find" on windows is not what we want. we want GNU find which we can name "find2"
(when (executable-find "find2")
  (setq find-program "find2"))

;; Disable vc-mode
'(with-eval-after-load 'vc
  (remove-hook 'find-file-hook 'vc-find-file-hook)
  (remove-hook 'find-file-hook 'vc-refresh-state)
  (setq vc-handled-backends nil))
'(defun my-git-project-finder (dir)
  "Integrate .git project roots."
  (let ((dotgit (and (setq dir (locate-dominating-file dir ".git"))
		     (expand-file-name dir))))
    (and dotgit
	 (cons 'transient (file-name-directory dotgit)))))
(use-package project
  ;:config
  ;(add-hook 'project-find-functions 'my-git-project-finder)
  )

(use-package magit
  :ensure t
  :bind (("C-x g" . magit-status)))

(use-package paren
  :config
  (setq show-paren-style 'parenthesis)
  (setq show-paren-when-point-in-periphery t)
  (setq show-paren-when-point-inside-paren t)
  (setq show-paren-context-when-offscreen 'child-frame) ; Emacs 29
  (setq show-paren-delay 0)
  :init
  (add-hook 'after-init-hook 'show-paren-mode))

(use-package puni
  :ensure t
  :defer t
  :init
  ;; The autoloads of Puni are set up so you can enable `puni-mode` or
  ;; `puni-global-mode` before `puni` is actually loaded. Only after you press
  ;; any key that calls Puni commands, it's loaded.
  (puni-global-mode)
  (add-hook 'term-mode-hook #'puni-disable-puni-mode))

(use-package eglot
  :ensure t
  :commands eglot)

'(use-package company
  :ensure t
  :after eglot
  :hook (eglot-managed-mode . company-mode)
  :init
  (setq company-idle-delay 0.1
        company-minimum-prefix-length 1)
  :bind (:map company-active-map
              ("C-n" . company-select-next)
              ("C-p" . company-select-previous))
  ;:config
  ;(global-company-mode)
  ;(define-key company-mode-map [remap indent-for-tab-command] #'company-indent-or-complete-common)
  )

;; A few more useful configurations...
(use-package emacs
  :init
  ;; TAB cycle if there are only few candidates
  (setq completion-cycle-threshold 3)

  ;; Emacs 28: Hide commands in M-x which do not apply to the current mode.
  ;; Corfu commands are hidden, since they are not supposed to be used via M-x.
  ;; (setq read-extended-command-predicate
  ;;       #'command-completion-default-include-p)

  ;; Enable indentation+completion using the TAB key.
  ;; `completion-at-point' is often bound to M-TAB.
  (setq tab-always-indent 'complete))

(use-package sly
  :ensure t
  :commands sly
  :config
  (setq inferior-lisp-program "sbcl"))


;; Reload config file when saved
(add-hook 'after-save-hook 'maybe-reload-config)
(defun maybe-reload-config ()
  (let ((suffix (substring (buffer-file-name) -6 nil)))
    (when (string= suffix ".emacs")
	(reload-config))))
(defun reload-config ()
  (interactive)
  (load-file (expand-file-name "~/.emacs")))

;; Shortcut for opening the config file
(defun find-config ()
  (interactive)
  (find-file (expand-file-name "~/.emacs")))
(global-set-key [C-f12] 'find-config)


;; Window navigation
(defun prev-window ()
  (interactive)
  (other-window -1))
(global-set-key (kbd "M-.") #'other-window)
(global-set-key (kbd "M-,") #'prev-window)


(defadvice kill-line (before check-position activate)
  (if (and (eolp) (not (bolp)))
      (progn (forward-char 1)
             (just-one-space 0)
             (backward-char 1))))
(defvar previous-column nil "Save the column position")
;; Define the nuke-line function. The line is killed, then the newline
;; character is deleted. The column which the cursor was positioned at is then
;; restored. Because the kill-line function is used, the contents deleted can
;; be later restored by usibackward-delete-char-untabifyng the yank commands.
(defun nuke-line()
  "Kill an entire line, including the trailing newline character"
  (interactive)
  (setq previous-column (current-column))
  (end-of-line)
  (if (= (current-column) 0)
    (delete-char 1)
    (progn
      (beginning-of-line)
      (kill-line)
      (delete-char 1)
      (move-to-column previous-column))))
(global-set-key [f8] 'nuke-line)



(global-set-key [f5]
		`(lambda () "Refresh the buffer from the disk (prompt of modified)."
		   (interactive)
		   (revert-buffer t (not (buffer-modified-p)) t)))


(defun rename-file-and-buffer ()
  "Rename the current buffer and file it is visiting."
  (interactive)
  (let ((filename (buffer-file-name)))
    (if (not (and filename (file-exists-p filename)))
        (message "Buffer is not visiting a file!")
      (let ((new-name (read-file-name "New name: " filename)))
        (cond
         ((vc-backend filename) (vc-rename-file filename new-name))
         (t
          (rename-file filename new-name t)
          (set-visited-file-name new-name t t)))))))
(global-set-key (kbd "C-c r")  'rename-file-and-buffer)



(defun run-current-file ()
  "Execute or compile the current file.
For example, if the current buffer is the file x.pl,
then it'll call “perl x.pl” in a shell.
The file can be php, perl, python, ruby, javascript, bash, ocaml, java.
File suffix is used to determine what program to run."
  (interactive)
  (let (extention-alist fname suffix progName cmdStr)
    (setq extention-alist ; a keyed list of file suffix to comand-line program to run
          '(
            ("php" . "php")
            ("pl" . "perl")
            ("py" . "python")
            ("rb" . "ruby")
            ("js" . "js")
            ("sh" . "bash")
            ("ml" . "ocaml")
            ("vbs" . "cscript")
            ("java" . "javac")
            )
          )
    (setq fname (buffer-file-name))
    (setq suffix (file-name-extension fname))
    (setq progName (cdr (assoc suffix extention-alist)))
    (setq cmdStr (concat progName " \""   fname "\""))

    (if (string-equal suffix "el")
        (load-file fname)
      (if progName
          (progn
            (message "Running...")
            (shell-command cmdStr))
        (message "No recognized program file suffix for this file.")))))

(global-set-key (kbd "<f7>") 'run-current-file)



(defun nuke-all-buffers ()
  "Kill all buffers, leaving *scratch* only"
  (interactive)
  (mapcar (lambda (x) (kill-buffer x))
	  (buffer-list))
  (delete-other-windows))


(defun smart-beginning-of-line ()
  "Move point to first non-whitespace character or beginning-of-line.

Move point to the first non-whitespace character on this line.
If point was already at that position, move point to beginning of line."
  (interactive)
  (let ((oldpos (point)))
    (back-to-indentation)
    (and (= oldpos (point))
         (beginning-of-line))))
(global-set-key [home] 'smart-beginning-of-line)
(global-set-key (kbd "C-a") 'smart-beginning-of-line)



(defun dos2unix ()
  "Replace DOS eolns CR LF with Unix eolns CR"
  (interactive)
    (goto-char (point-min))
      (while (search-forward "\r" nil t) (replace-match "")))
(global-set-key [C-f6] 'dos2unix)


(defun kill-other-buffers ()
  "Kill all other buffers."
  (interactive)
  (mapc 'kill-buffer (delq (current-buffer) (buffer-list))))
(global-set-key (kbd "C-c C-k") 'kill-other-buffers)


(defun show-file-name ()
  "Show the full path file name in the minibuffer."
  (interactive)
  (message (buffer-file-name)))
(global-set-key [C-f1] 'show-file-name)


(defun my-c-mode-hook ()
  (setq c-default-style "bsd"
	c-basic-offset 4
	c-indent-level 4
	indent-tabs-mode nil)
  (local-set-key  (kbd "C-c o") 'ff-get-other-file)
  (c-set-offset 'innamespace 0))
(use-package cc-mode
  :defer
  :hook (c-mode-common-hook . my-c-mode-hook)
  :config
  (add-to-list 'auto-mode-alist '("\\.h\\'" . c++-mode)))
  

;; Autoindent yanked text
(dolist (command '(yank yank-pop))
   (eval `(defadvice ,command (after indent-region activate)
            (and (not current-prefix-arg)
                 (member major-mode '(emacs-lisp-mode lisp-mode
                                                      clojure-mode    scheme-mode
                                                      haskell-mode    ruby-mode
                                                      rspec-mode      python-mode
                                                      c-mode          c++-mode
                                                      objc-mode       latex-mode
                                                      plain-tex-mode))
                 (let ((mark-even-if-inactive transient-mark-mode))
                   (indent-region (region-beginning) (region-end) nil))))))


(defun q-r-word ()
  "Query-replace whole words."
  (interactive)
  (let ((current-prefix-arg t))
    (call-interactively #'query-replace)))


(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(package-selected-packages
   '(puni parinfer corfu benchmark-init sly company eglot paredit magit use-package)))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )
