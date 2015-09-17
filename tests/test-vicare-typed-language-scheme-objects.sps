;;;
;;;Part of: Vicare Scheme
;;;Contents: tests for built-in Scheme object types under typed language
;;;Date: Thu Sep 17, 2015
;;;
;;;Abstract
;;;
;;;
;;;
;;;Copyright (C) 2015 Marco Maggi <marco.maggi-ipsu@poste.it>
;;;
;;;This program is free software: you can  redistribute it and/or modify it under the
;;;terms  of  the GNU  General  Public  License as  published  by  the Free  Software
;;;Foundation,  either version  3  of the  License,  or (at  your  option) any  later
;;;version.
;;;
;;;This program is  distributed in the hope  that it will be useful,  but WITHOUT ANY
;;;WARRANTY; without  even the implied warranty  of MERCHANTABILITY or FITNESS  FOR A
;;;PARTICULAR PURPOSE.  See the GNU General Public License for more details.
;;;
;;;You should have received a copy of  the GNU General Public License along with this
;;;program.  If not, see <http://www.gnu.org/licenses/>.
;;;


#!vicare
(program (test-vicare-typed-language-scheme-objects)
  (options typed-language)
  (import (vicare)
    (vicare checks))

(check-set-mode! 'report-failed)
(check-display "*** testing Vicare libraries: typed language, built-in Scheme object types\n")


(parametrise ((check-test-name	'top))

  (check
      (is-a? 123 <top>)
    => #t)

  #t)


(parametrise ((check-test-name	'pair))

;;; type predicate

  (check-for-true
   (is-a? '(1 . 2) <pair>))

  (check-for-true
   (let ((O '(1 . 2)))
     (is-a? O <pair>)))

  (check-for-true
   (let (({O <pair>} '(1 . 2)))
     (is-a? O <pair>)))

  (check-for-false
   (is-a? 123 <pair>))

  (check
      (expansion-of (is-a? '(1 . 2) <pair>))
    => '(quote #t))

;;; --------------------------------------------------------------------
;;; constructor

  (check
      (new <pair> 1 2)
    => '(1 . 2))

;;; --------------------------------------------------------------------
;;; expand-time methods call

  (check
      (.car (new <pair> 1 2))
    => 1)

  (check
      (.cdr (new <pair> 1 2))
    => 2)

;;; --------------------------------------------------------------------
;;; run-time methods call

  (check
      (method-call-late-binding 'car (new <pair> 1 2))
    => 1)

  (check
      (method-call-late-binding 'cdr (new <pair> 1 2))
    => 2)

  #t)


;;;; done

(check-report)

#| end of program |# )

;;; end of file
;; Local Variables:
;; mode: vicare
;; coding: utf-8
;; End:
