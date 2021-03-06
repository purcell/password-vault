;;; password-vault.el --- A Password manager for Emacs. -*- lexical-binding: t -*-

;;; AuthorL Javier "PuercoPop" Olaechea <pirata@gmail.com>
;;; URL: http://github.com/PuercoPop/password-vault.el
;;; Version: 20130721
;;; Keywords: password, productivity

;;; Comentary:

;; It builds upon the pattern described in this post:
;; http://emacs-fu.blogspot.com/2011/02/keeping-your-secrets-secret.html

;; Usage: (password-vault-register-secrets-file 'secrets.el)
;; M-x password-vault

;;; License:
;; Copying is an act of love, please copy. ♡

;;; Todo:
;; make the keymap for the major mode use n and p to go next password


;;; Code:

(eval-when-compile (require 'cl-lib))

;; So that locate-library works properly.
(setq load-file-rep-suffixes (append load-file-rep-suffixes '(".gpg")))


(define-derived-mode password-vault-mode special-mode "password-vault"
  "Major mode from copying the passwords you store in Emacs to the clipboard")

(defgroup password-vault nil
  "A password manager for Emacs"
  :group 'password-vault)

(defcustom password-vault-passwords nil
  "An alist containing the passwords."
  :group 'password-vault)

(defcustom password-vault-secret-files nil
  "An alist of the modules to load the passwords from."
  :group 'password-vault)


(defun password-vault-button-password (button)
  "Return BUTTON's password."
  (get-text-property 1 'password button))

(defun password-vault-button-action-callback-factory (password)
  "Return a function that when called copies the password to the clipboard."
  (lambda (z)
    (apply interprogram-cut-function (list password))))

(defun password-vault-make-button (service-name password)
  (let* ((button-start (point))
         (button-end (+ button-start (length service-name))))
    (insert service-name)
    (make-text-button button-start button-end
                      'follow-link t ;; Action also binds the left click :D
                      'action (apply
                               'password-vault-button-action-callback-factory
                               (list password))
                      'help-echo "Copy to Clipboard")))

;;;###autoload
(defun password-vault-register-secrets-file (module)
  "Load the setq forms to the module to the password-vaults."
  (add-to-list 'password-vault-secret-files module))

(defun password-vault-update-passwords-helper (module)
  "Locate module and add them to the alist."
  (with-current-buffer (find-file-noselect
                      (locate-library module) t)
    (setq buffer-read-only t)
    (let ((sexp
           (read (buffer-substring-no-properties (point-min) (point-max)))))
      (when (equal (car sexp) 'setq)
        (let ((pairs (cdr sexp)))
          (while pairs
            (add-to-list 'password-vault-passwords `(,(car pairs) . ,(cadr pairs)))
            (setq pairs (cddr pairs))))))
    (setq buffer-read-only nil)))

(defun password-vault-update-passwords ()
  "(re)Generate the password alist."
  (dolist (module password-vault-secret-files)
    (password-vault-update-passwords-helper module)))

;;;###autoload
(defun password-vault ()
  (interactive)

  (unless interprogram-cut-function
    (error "Interprogram clipboard must be enabled."))

  (unless password-vault-passwords
    (password-vault-update-passwords))

  (let ((password-vault-buffer (get-buffer-create "*password-vault*")))
    (switch-to-buffer password-vault-buffer)
    (set-buffer-major-mode (current-buffer))
    (loop for (key . value) in  password-vault-passwords
          do
          (password-vault-make-button (symbol-name key) value)
          (insert "\n"))
    (goto-char (point-min))))

(add-to-list 'auto-mode-alist (cons "*password-vault*" 'password-vault-mode))

(provide 'password-vault)
;;; password-vault.el ends here
