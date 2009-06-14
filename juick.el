;;; juick.el --- improvement reading juick@juick.com

;; Copyright (C) 2009  mad

;; Author: mad <owner.mad.epa@gmail.com>
;; Keywords: juick

;; This program is free software; you can redistribute it and/or modify
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

;; Markup message recivied from juick@juick.com and some usefull keybindings.

;;; Installing:

;; 1. Put juick.el to you load-path
;; 2. put this to your init file:
;;  (require 'juick)
;; 3. Turn on jabber history in order to `juick-last-reply' working:
;;
;;  (setq jabber-history-enabled t)
;;  (setq jabber-use-global-history nil)

;;; Default bind:

;; C-cjl - `juick-last-reply'
;; TAB - `juick-next-button'

;;; Code:

(require 'button)

(defgroup juick-faces nil "Faces for displaying Juick msg"
  :group 'juick)

(defface juick-id-face
  '((t (:weight bold)))
  "face for displaying id"
  :group 'juick-faces)

(defface juick-user-name-face
  '((t (:foreground "blue" :weight bold :slant normal)))
  "face for displaying user name"
  :group 'juick-faces)

(defface juick-tag-face
  '((t (:foreground "black" :background "light gray" :slant italic)))
  "face for displaying tags"
  :group 'juick-faces)

(defface juick-bold-face
  '((t (:weight bold :slant normal)))
  "face for displaying bold text"
  :group 'juick-faces)

(defface juick-italic-face
  '((t (:slant italic)))
  "face for displaying italic text"
  :group 'juick-faces)

(defface juick-underline-face
  '((t (:underline t :slant normal)))
  "face for displaying underline text"
  :group 'juick-faces)

(defvar juick-overlays nil)
(defvar juick-point-last-message nil)

(defvar juick-bot-jid "juick@juick.com")

(defvar jabber-ask-me-location nil
  "If t then jabber ask your location when send message")
(defvar jabber-default-location nil
  "Send this location when `jabber-ask-me-location' nil")

;; from http://juick.com/help/
(defvar juick-id-regex "\\(#[0-9]+\\(/[0-9]+\\)?\\)")
(defvar juick-user-name-regex "[^0-9A-Za-z\\.]\\(@[0-9A-Za-z@\\.\\-]+\\)")
(defvar juick-tag-regex "\\(\\*[^ \n]+\\)")
(defvar juick-bold-regex "[\n ]\\(\\*[^\n]+*\\*\\)[\n ]")
(defvar juick-italic-regex "[\n ]\\(/[^\n]+/\\)[\n ]")
(defvar juick-underline-regex "[\n ]\\(\_[^\n]+\_\\)[\n ]")

(defvar juick-last-reply-mode-map
  (let ((map (make-sparse-keymap)))
    (set-keymap-parent map text-mode-map)
    (define-key map "q" 'juick-find-buffer)
    (define-key map (kbd "TAB") 'juick-next-button)
    (define-key map (kbd "<backtab>") 'backward-button)
    map)
  "Keymap for `juick-last-reply-mode'.")

(defun jabber-message-juick (from buffer text proposed-alert &optional force)
  "Markup  message from `juick-bot-jid'.

Where FROM is jid sender, BUFFER is buffer with message TEXT

Use FORCE to markup any buffer"
  (if (or force (string-match juick-bot-jid from))
      (save-excursion
        (setq juick-point-last-message
              (re-search-backward (concat juick-bot-jid ">") nil t))
        (set-buffer buffer)
        (juick-markup-user-name)
        (juick-markup-id)
        (juick-markup-tag)
        (juick-markup-bold)
        (juick-markup-italic)
        (juick-markup-underline))))

(add-hook 'jabber-alert-message-hooks 'jabber-message-juick)

(defun juick-last-reply ()
  "View last message in own buffer"
  (interactive)
  (split-window-vertically -10)
  (windmove-down)
  (switch-to-buffer "*juick-last-reply*")
  (toggle-read-only -1)
  (delete-region (point-min) (point-max))
  ;; XXX: retrive last 200 msg, some of them '^#NNNN msg'
  ;; make own history for juick and write only '^#NNNN msg'
  ;; or retrive ALL history
  (let ((list (nreverse (jabber-history-query nil nil 200 "out" juick-bot-jid
                                              (concat jabber-history-dir
                                                      (concat "/" juick-bot-jid))))))
    (while list
      (let ((msg (aref (car list) 4)))
        (if (string-match "\\(^#[0-9]+\\(/[0-9]+\\)? .\\)" msg 0)
            (progn
              (if (> (length msg) 40)
                  (insert (concat (substring msg 0 40) "...\n"))
                (insert (concat msg "\n"))))))
      (setq list (cdr list))))
  (goto-char (point-min))
  (toggle-read-only)
  (jabber-message-juick nil (current-buffer) nil nil t)
  (juick-last-reply-mode))

(define-derived-mode juick-last-reply-mode text-mode
  "juick last reply mode"
  "Major mode for getting last reply")

(define-key jabber-chat-mode-map (kbd "TAB") 'juick-next-button)
(define-key jabber-chat-mode-map "\C-cjl" 'juick-last-reply)

(defun juick-markup-user-name ()
  "Markup user-name matched by regex `juick-regex-user-name'"
  (goto-char (or juick-point-last-message (point-min)))
  (while (re-search-forward juick-user-name-regex nil t)
    (if (match-string 1)
        (progn
          (juick-add-overlay (match-beginning 1) (match-end 1)
                             'juick-user-name-face)
          (make-button (match-beginning 1) (match-end 1)
                       'action 'juick-insert-user-name)))))

(defun juick-markup-id ()
  "Markup id matched by regex `juick-regex-id'"
  (goto-char (or juick-point-last-message (point-min)))
  (while (re-search-forward juick-id-regex nil t)
    (if (match-string 1)
        (progn
          (juick-add-overlay (match-beginning 1) (match-end 1)
                             'juick-id-face)
          (make-button (match-beginning 1) (match-end 1)
                       'action 'juick-insert-id)))))

(defun juick-markup-tag ()
  "Markup tag matched by regex `juick-regex-tag'"
  (goto-char (or juick-point-last-message (point-min)))
  ;;; FIXME: I dont know how to recognize a tag point
  (while (re-search-forward "\\([:]\n\n\\|[:]\n\\|[\)]\n\n\\)" nil t)
    ;;(goto-char (+ (point) (length (match-string 1))))
    (let ((count-tag 0))
      (while (and (looking-at "\\*")
                  (<= count-tag 5))
        (let ((beg-tag (point))
              (end-tag (- (re-search-forward "[\n ]" nil t) 1)))
          (juick-add-overlay beg-tag end-tag 'juick-tag-face)
          (make-button beg-tag end-tag 'action 'juick-find-tag))
        (setq count-tag (+ count-tag 1))))))

(defun juick-markup-italic ()
  (goto-char (or juick-point-last-message (point-min)))
  (while (re-search-forward juick-italic-regex nil t)
    (juick-add-overlay (match-beginning 1) (match-end 1)
                       'juick-italic-face)
    (goto-char (- (point) 1))))

(defun juick-markup-bold ()
  (goto-char (or juick-point-last-message (point-min)))
  (while (re-search-forward juick-bold-regex nil t)
    (juick-add-overlay (match-beginning 1) (match-end 1)
                       'juick-bold-face)
    (goto-char (- (point) 1))))

(defun juick-markup-underline ()
  (goto-char (or juick-point-last-message (point-min)))
  (while (re-search-forward juick-underline-regex nil t)
    (juick-add-overlay (match-beginning 1) (match-end 1)
                       'juick-underline-face)
    (goto-char (- (point) 1))))

;;; XXX: maybe merge?
(defun juick-insert-user-name (button)
  "Inserting reply id in conversation buffer"
  (let ((user-name (buffer-substring-no-properties
                    (overlay-start button)
                    (- (re-search-forward "[\n :]" nil t) 1))))
    (juick-find-buffer)
    (goto-char (point-max))
    (insert (concat user-name " ")))
  (recenter 10))

(defun juick-insert-id (button)
  "Inserting reply id in conversation buffer"
  (let ((id (buffer-substring-no-properties
             (overlay-start button)
             (- (re-search-forward "[\n ]" nil t) 1))))
    (juick-find-buffer)
    (goto-char (point-max))
    (insert (concat id " ")))
  (recenter 10))

(defun juick-find-tag (button)
  "Retrive 10 message this tag"
  (save-excursion
    (let ((tag (buffer-substring-no-properties
                (overlay-start button)
                (re-search-forward "\\([\n ]\\|$\\)" nil t))))
      (juick-find-buffer)
      (delete-region jabber-point-insert (point-max))
      (goto-char (point-max))
      (insert tag)))
  (jabber-chat-buffer-send))

(defun juick-find-buffer ()
  "Find buffer with `juick-bot-jid'"
  (interactive)
  (if (not (string-match (concat "*-jabber-chat-" juick-bot-jid "-*")
                         (buffer-name)))
      (progn
        (delete-window)
        (let ((juick-window (get-window-with-predicate
                             (lambda (w)
                               (string-match
                                (concat "*-jabber-chat-" juick-bot-jid "-*")
                                (buffer-name (window-buffer w)))))))
          (if juick-window
              (select-window juick-window)
            (jabber-chat-with (jabber-read-account) juick-bot-jid))))))

(defun jabber-chat-send-add-geoloc (body id)
  "Add geoloc to message"
  (if jabber-ask-me-location
      (if (y-or-n-p "Add geoloc? ")
          (jabber-make-geoloc-stanza))
    (if jabber-default-location
        (jabber-make-geoloc-stanza jabber-default-location))))

(add-hook 'jabber-chat-send-hooks 'jabber-chat-send-add-geoloc)

(defun jabber-make-geoloc-stanza (&optional location)
  (let* ((maybe-loc (or location (read-string "Input your location: ")))
         (maybe-loc (or location (google-map-get-loc maybe-loc))))
    (if maybe-loc
        (let ((loc-stanza
               `((geoloc ((xmlns . "http://jabber.org/protocol/geoloc"))
                         (lat nil ,(prin1-to-string (aref maybe-loc 1)))
                         (lon nil ,(prin1-to-string (aref maybe-loc 0)))))))
          loc-stanza)
      (if (y-or-n-p (concat "Your location not found. Send without loc? "))
          nil
        (jabber-make-geoloc-stanza)))))

(defun jabber-set-default-location (location)
  "Set `jabber-default-location'"
  (interactive "sInput your default location: ")
  (let ((location (google-map-get-loc location)))
    (if location
        (progn
          (message "Your default location set")
          (setq jabber-default-location location))
      (message "Your location not found."))))

(defun google-map-get-loc (location)
  "Get location ADDRES from google maps

Return array with lat and lon (e.g. [30.333 59.3333])"
  (let* ((request location)
         (google-url (concat
                      "http://maps.google.com/maps/geo?q="
                      (url-hexify-string request)
                      "&output=json&oe=utf8&sensor=true_or_false&key=emacs-jabber"))
         (url-request-method "GET")
         (content-buf (url-retrieve-synchronously google-url)))
         (save-excursion
           (set-buffer content-buf)
           (goto-char (point-min))
           (delete-region (point-min) (re-search-forward "\n\n" nil t))
           (let ((maybe-loc (json-read)))
             (kill-buffer (current-buffer))
             (if (= (length maybe-loc) 3)
                 (progn
                   (cdar (cdar (aref (cdr (car maybe-loc)) 0))))
               nil)))))

(defun juick-next-button ()
  "move point to next button"
  (interactive)
  (if (next-button (point))
      (goto-char (overlay-start (next-button (point))))
    (progn
      (goto-char (point-max))
      (message "button not found"))))

(defun juick-add-overlay (begin end faces)
  (let ((overlay (make-overlay begin end)))
    (overlay-put overlay 'face faces)
    (push overlay juick-overlays)))

(defun juick-delete-overlays ()
  (dolist (overlay juick-overlays)
    (delete-overlay overlay))
  (setq juick-overlays nil))

(provide 'juick)
;;; juick.el ends here
