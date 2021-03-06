;;; e2wm-code2.el --- Side-by-Side Code editing perspective
;;
;; Author: Henry G. Weller <hweller0@gmail.com>
;; Maintainer: Henry G. Weller
;; Copyright (C) 2013, Henry G. Weller, all rights reserved.
;; Created: Sun Sep 22 18:55:40 2013 (+0100)
;; Version: 0.1
;; Last-Updated: Sun Sep 22 19:00:54 2013 (+0100)
;;           By: Henry G. Weller
;;     Update #: 3
;; URL:
;; Keywords: tools, window manager
;; Compatibility: GNU Emacs 24.x (may work with earlier versions)
;; This file is NOT part of Emacs.
;;
;; -----------------------------------------------------------------------------
;;; Commentary:
;;
;; Perspective for the e2wm window-manager for coding on a wide full-screen
;; window supporting two code windows side-by-side with a directory tree and
;; file history list on the left.
;;
;; Includes a dirtree plugin for the directory tree.
;;
;; -----------------------------------------------------------------------------
;;; Change Log:
;;
;; Version 0.1
;; * Initial release
;;
;; -----------------------------------------------------------------------------
;;
;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation; either version 3, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program; see the file COPYING.  If not, write to
;; the Free Software Foundation, Inc., 51 Franklin Street, Fifth
;; Floor, Boston, MA 02110-1301, USA.
;; -----------------------------------------------------------------------------
;;; Code:

(use-package e2wm
  :init
  (setq e2wm:debug t))

;; -----------------------------------------------------------------------------
;;; Dirtree plugin

(require 'tree-mode)
(require 'dirtree)
(require 'imenu-tree)

(defun e2wm:dirtree-select (node &rest ignore)
  "Open file in main window"
  (let ((file (widget-get node :file)))
    (when file
      (e2wm:history-add (find-file-noselect file))
      (e2wm:pst-show-history-main)
      (e2wm:pst-window-select-main))))

(defun e2wm:def-plugin-dirtree (frame wm winfo)
  (let ((wname (wlf:window-name winfo))
        (win (wlf:window-live-window winfo))
        (buf (get-buffer dirtree-buffer)))
    (unless (and buf (buffer-live-p buf))
      (setq buf (get-buffer-create dirtree-buffer))
      (select-window win)
      (dirtree-build buf "." nil))
    (wlf:set-buffer wm wname buf))
  ;; Select the `left' window
  (e2wm:pst-window-select 'left))

(e2wm:plugin-register 'dirtree
                     "dirtree"
                     'e2wm:def-plugin-dirtree)

;; -----------------------------------------------------------------------------
;;; Code2 perspective

(defvar e2wm:c-code2-recipe
  '(| (:left-max-size 50)
      (- (:upper-size-ratio 0.7)
         files history)
      (- (:lower-max-size 5)
         (| (:left-size 81) left right)
         sub)))

(defvar e2wm:c-code2-winfo
  '((:name left)
    (:name right)
    (:name files :plugin dirtree)
    (:name sub :buffer "*Completions*" :default-hide t)
    (:name history :plugin history-list2)))

(defvar e2wm:c-code2-right-default 'prev)

(e2wm:pst-class-register
  (make-e2wm:$pst-class
   :name       'code2
   :extend     'base
   :title      "Coding2"
   :init       'e2wm:dp-code2-init
   :main       'left
   :switch     'e2wm:dp-code2-switch
   :popup      'e2wm:dp-code2-popup
   :display    'e2wm:dp-code2-display
   :after-bury 'e2wm:dp-code2-after-bury
   :keymap     'e2wm:dp-code2-minor-mode-map
   :leave      'e2wm:dp-code2-leave))

(defun e2wm:dp-code2-init ()

  ;; Hack to try to help get the correct window sizes in the new layout
  (ad-deactivate 'delete-other-windows)
  (delete-other-windows)
  (ad-activate 'delete-other-windows)

  ;; Set the dirtree-file-widget to us e2wm:dirtree-select
  (define-widget 'dirtree-file-widget 'push-button
    "File widget."
    :format         "%[%t%]\n"
    :button-face    'default
    :notify         'e2wm:dirtree-select)
  (let*
      ((code2-wm
        (wlf:no-layout
         e2wm:c-code2-recipe
         e2wm:c-code2-winfo))
       (buf (or e2wm:prev-selected-buffer
                (e2wm:history-get-main-buffer))))

    (when (e2wm:history-recordable-p e2wm:prev-selected-buffer)
      (e2wm:history-add e2wm:prev-selected-buffer))

    (wlf:set-buffer code2-wm 'left buf)
    (cond
     ((eq e2wm:c-code2-right-default 'left)
      (wlf:set-buffer code2-wm 'right buf))
     ((eq e2wm:c-code2-right-default 'prev)
      (wlf:set-buffer code2-wm 'right (e2wm:history-get-prev buf)))
     (t
      (wlf:set-buffer code2-wm 'right (e2wm:history-get-prev buf))))

    code2-wm))

(defun e2wm:dp-code2-leave (wm)
  (kill-buffer (get-buffer-create dirtree-buffer))
  ;; Reset dirtree-file-widget
  (define-widget 'dirtree-file-widget 'push-button
    "File widget."
    :format         "%[%t%]\n"
    :button-face    'default
    :notify         'dirtree-select)
  (customize-set-variable 'display-buffer-alist nil))

(defun e2wm:dp-code2-switch (buf)
  "Switch to the buffer BUF staying in the same window if left or right"
  (e2wm:message "#DP CODE2 switch : %s" buf)
  (let ((wm (e2wm:pst-get-wm))
        (curwin (selected-window))
        (buf-name (buffer-name buf)))
    (cond
     ;; Standard popups in right window
     ((and e2wm:c-code2-show-right-regexp
          (string-match e2wm:c-code2-show-right-regexp buf-name))
     (e2wm:pst-buffer-set 'right buf t t)
     t)

     ;; In left window
     ((eql curwin (wlf:get-window wm 'left))
      (cond
       ((eql (get-buffer buf) (wlf:get-buffer wm 'left))
        ;; Switching to the same buffer, show it in right window
        (e2wm:pst-update-windows)
        (e2wm:pst-buffer-set 'right buf)
        t)
       (t
        ;; Otherwise, do the default
        nil)))

     ;; In right window
     ((eql curwin (wlf:get-window wm 'right))
      (e2wm:pst-buffer-set 'right buf)
      t)

     ;; Default
     (t nil))))

(setq e2wm:c-document-buffer-p (lambda (buf) nil))

(defvar e2wm:c-code2-show-left-regexp nil)

(defvar e2wm:c-code2-show-right-regexp
  "\\*\\(Help\\|eshell\\|grep\\|Occur\\|Greed\\|Compilation\\|Backtrace\\|imenu-tree\\|Man\\|WoMan\\|info\\|eww\\|magit\\)")

(defvar e2wm:c-code2-max-sub-size 1000)

(defun e2wm:dp-code2-popup (buf)
  "Show document buffers in 'right,
   recordable buffers in 'left,
   specifically allocated to either the 'left or 'right windows by regexp,
   buffers to large for sub in 'right,
   otherwise display the buffer in pop-up sub."
  (e2wm:message "#DP CODE2 popup : %s" buf)
  (let ((buf-name (buffer-name buf)))
    (message "popup %s" buf-name)
    (cond
    ((e2wm:document-buffer-p buf)
     (e2wm:pst-buffer-set 'right buf)
     t)
    ((e2wm:history-recordable-p buf)
     (e2wm:pst-show-history-main)
     t)
    ((and e2wm:c-code2-show-left-regexp
          (string-match e2wm:c-code2-show-left-regexp buf-name))
     (e2wm:pst-buffer-set 'left buf t t)
     t)
    ((and e2wm:c-code2-show-right-regexp
          (string-match e2wm:c-code2-show-right-regexp buf-name))
     (e2wm:pst-buffer-set 'right buf t t)
     t)
    ((> (buffer-size buf) e2wm:c-code2-max-sub-size)
     ;; Put large special buffers in 'right ...
     (e2wm:pst-buffer-set 'right buf t)
     t)
    (t
     (e2wm:dp-code2-popup-sub buf)
     t))))

(defun e2wm:dp-code2-popup-sub (buf)
  (let ((wm (e2wm:pst-get-wm))
        (not-minibufp (= 0 (minibuffer-depth))))
    (e2wm:with-advice
     (e2wm:pst-buffer-set 'sub buf t not-minibufp))))

(defun e2wm:dp-code2-display (buf)
  "Show document buffers in 'right,
   recordable buffers in 'left,
   specifically allocated to either the 'left or 'right windows by regexp,
   buffers to large for sub in 'right,
   otherwise display the buffer in pop-up sub.
   Do not select the buffer."
  (e2wm:message "#DP CODE2 display : %s" buf)
  (let ((buf-name (buffer-name buf)))
    (cond
     ((or (e2wm:history-recordable-p buf) ; we don't need to distinguish
          (e2wm:document-buffer-p buf))   ; these two as we don't select
      (let ((wm (e2wm:pst-get-wm))
            (curwin (selected-window)))
        ;; show in the other window, but don't select.
        (if (eql curwin (wlf:get-window wm 'left))
            (e2wm:pst-buffer-set 'right buf)
          (e2wm:pst-buffer-set 'left buf)))
      (e2wm:pst-update-windows)        ; update plugins, etc.
      t)
     ((and e2wm:c-code2-show-left-regexp
           (string-match e2wm:c-code2-show-left-regexp buf-name))
      (e2wm:pst-buffer-set 'left buf t t)
      t)
     ((and e2wm:c-code2-show-right-regexp
           (string-match e2wm:c-code2-show-right-regexp buf-name))
      (e2wm:pst-buffer-set 'right buf t t)
      t)
     ((> (buffer-size buf) e2wm:c-code2-max-sub-size)
      ;; Put large special buffers in 'right ...
      (e2wm:pst-buffer-set 'right buf t)
      ;; ... and delete the pop-up 'sub if present
      (let ((win (wlf:get-window (e2wm:pst-get-wm) 'sub)))
        (when win
          (delete-window win)))
      t)
     (t
      ;; If buf is already displayed in 'right revert to previous buffer ...
      (let* ((rwin (wlf:get-window (e2wm:pst-get-wm) 'right))
             (rbuf (window-buffer rwin)))
        (when (eql buf rbuf)
          (switch-to-prev-buffer rwin)))
      ;; ... and display in pop-up 'sub
      (e2wm:pst-buffer-set 'sub buf t)
      t))))

(defun e2wm:dp-code2-after-bury (buried-buffer window)
  "Close sub window if it is the current window."
  (e2wm:message "#DP CODE AFTER BURY %s %s" buried-buffer window)
  (e2wm:$pst-class-super)
  (let ((wm (e2wm:pst-get-wm)))
    (when (or (e2wm:buffer-completion-p buried-buffer)
              (eq (wlf:get-window-name wm window) 'sub))
      (wlf:hide wm 'sub)
      (wlf:select wm (e2wm:$pst-main (e2wm:pst-get-instance))))))

;; -----------------------------------------------------------------------------
;;; Commands / Keybindings

(defun e2wm:dp-code2 ()
  (interactive)
  (e2wm:pst-change 'code2))

(defun e2wm:dp-code2-history-toggle-command ()
  (interactive)
  (wlf:toggle (e2wm:pst-get-wm) 'history)
  (e2wm:pst-update-windows))
(defun e2wm:dp-code2-sub-toggle-command ()
  (interactive)
  (wlf:toggle (e2wm:pst-get-wm) 'sub)
  (e2wm:pst-update-windows))

(defun e2wm:dp-code2-navi-left-command ()
  (interactive)
  (e2wm:pst-window-select 'left))
(defun e2wm:dp-code2-navi-right-command ()
  (interactive)
  (e2wm:pst-window-select 'right))
(defun e2wm:dp-code2-navi-files-command ()
  (interactive)
  (e2wm:pst-window-select 'files))
(defun e2wm:dp-code2-navi-sub-command ()
  (interactive)
  (e2wm:pst-window-select 'sub))
(defun e2wm:dp-code2-navi-history-command ()
  (interactive)
  (e2wm:pst-window-select 'history))

(defun e2wm:dp-code2-update-history-list ()
  (e2wm:plugin-exec-update-by-plugin-name
   (selected-frame) (e2wm:pst-get-wm) 'history-list2))

(defun e2wm:dp-code2-double-column-command ()
  (interactive)
  (e2wm:pst-buffer-set 'right (e2wm:history-get-main-buffer))
  (e2wm:dp-code2-update-history-list))

(defun e2wm:dp-code2-right-history-forward-command ()
  (interactive)
  (e2wm:pst-buffer-set
   'right (e2wm:history-get-next
           (e2wm:pst-buffer-get 'right)))
  (e2wm:dp-code2-update-history-list))

(defun e2wm:dp-code2-right-history-back-command ()
  (interactive)
  (e2wm:pst-buffer-set
   'right (e2wm:history-get-prev
           (e2wm:pst-buffer-get 'right)))
  (e2wm:dp-code2-update-history-list))

(defalias 'e2wm:dp-code2-right-history-up-command
  'e2wm:dp-code2-right-history-forward-command)
(defalias 'e2wm:dp-code2-right-history-down-command
  'e2wm:dp-code2-right-history-back-command)

(defun e2wm:dp-code2-swap-buffers-command ()
  (interactive)
  (let ((left  (e2wm:pst-buffer-get 'left))
        (right (e2wm:pst-buffer-get 'right)))
    (e2wm:pst-buffer-set 'left  right)
    (e2wm:pst-buffer-set 'right left)
  (e2wm:dp-code2-update-history-list)))

(defun e2wm:dp-code2-main-maximize-toggle-command ()
  (interactive)
  (wlf:toggle-maximize (e2wm:pst-get-wm) 'left))

(defvar e2wm:dp-code2-minor-mode-map
  (e2wm:define-keymap
   '(("prefix d" . e2wm:dp-code2-double-column-command)
     ("prefix S" . e2wm:dp-code2-sub-toggle-command)
     ("prefix -" . e2wm:dp-code2-swap-buffers-command)
     ("prefix N" . e2wm:dp-code2-right-history-down-command)
     ("prefix P" . e2wm:dp-code2-right-history-up-command)
     ("prefix H" . e2wm:dp-code2-history-toggle-command)
     ("prefix M" . e2wm:dp-code2-main-maximize-toggle-command))
   e2wm:prefix-key))

(e2wm:add-keymap e2wm:pst-minor-mode-keymap
                 '(("prefix c" . e2wm:dp-code2)) e2wm:prefix-key)

;; -----------------------------------------------------------------------------
;;; history-list2

;; Add mouse-1 as a select key
(define-key e2wm:def-plugin-history-list2-mode-map [mouse-1]
  'e2wm:def-plugin-history-list2-select-command)

(provide 'e2wm-code2)

;; -----------------------------------------------------------------------------
;;; e2wm-code2.el ends here
