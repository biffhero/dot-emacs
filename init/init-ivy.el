;;; init-ivy.el --- Initialize enhanced minibuffer completion package
;; -----------------------------------------------------------------------------

(use-package avy
  :ensure t
  :init
  ;; Set the avy-keys to the Dvorak home-row
  (setq avy-keys '(?a ?o ?e ?u ?i ?d ?h ?t ?n)))

(use-package ivy
  :ensure t
  :diminish ivy-mode
  :ensure avy
  :init
  (setq ivy-height 10       ;; number of result lines to display
        ivy-wrap t          ;; Wrap at first and last entry
        ivy-count-format "" ;; Don't count canditates

        ;; Add recent files and bookmarks to switch-buffer
        ivy-use-virtual-buffers t

        ;; Display candidates ...
        ivy-display-function nil ;; in minibuffer
        ;; ivy-display-function 'ivy-display-function-overlay ;; in overlay

        ivy-do-completion-in-region t

        magit-completing-read-function 'ivy-completing-read
        )
  :bind
  (:map ivy-mode-map
        ("C-'" . ivy-avy))
  :config
  (ivy-mode 1))

(use-package counsel
  :ensure t
  :ensure swiper
  :ensure smex
  :init (setq counsel-find-file-at-point t)
  :bind (("C-x C-f" . counsel-find-file)
         ("C-x C-r" . counsel-recentf)
         ("C-h f" . counsel-describe-function)
         ("C-h v" . counsel-describe-variable)
         ("M-y" . counsel-yank-pop)
         ;;("C-s" . swiper)
         ("C-c C-r" . ivy-resume)
         ("M-x" . counsel-M-x)
         ;;([f2 ?i] . counsel-info-lookup-symbol)
         ;;("<f2> u" . counsel-unicode-char)
         ("C-c g" . counsel-git)
         ("C-c j" . counsel-git-grep)

         :map read-expression-map
         ("C-r" . counsel-expression-history)))

;; -----------------------------------------------------------------------------
;;; init-ivy.el ends here