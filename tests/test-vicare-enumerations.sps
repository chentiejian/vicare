;;; -*- coding: utf-8-unix -*-
;;;
;;;Part of: Vicare Scheme
;;;Contents: tests for enumerations
;;;Date: Sat Mar 24, 2012
;;;
;;;Abstract
;;;
;;;
;;;
;;;Copyright (C) 2012-2015 Marco Maggi <marco.maggi-ipsu@poste.it>
;;;
;;;This program is free software:  you can redistribute it and/or modify
;;;it under the terms of the  GNU General Public License as published by
;;;the Free Software Foundation, either version 3 of the License, or (at
;;;your option) any later version.
;;;
;;;This program is  distributed in the hope that it  will be useful, but
;;;WITHOUT  ANY   WARRANTY;  without   even  the  implied   warranty  of
;;;MERCHANTABILITY  or FITNESS FOR  A PARTICULAR  PURPOSE.  See  the GNU
;;;General Public License for more details.
;;;
;;;You should  have received  a copy of  the GNU General  Public License
;;;along with this program.  If not, see <http://www.gnu.org/licenses/>.
;;;


#!r6rs
(program (test)
  (options strict-r6rs)
  (import (vicare)
    (vicare checks))

(check-set-mode! 'report-failed)
(check-display "*** testing Vicare enumerations\n")


;;;; helpers

(define environment-for-syntax-errors
  (environment '(rnrs)))

(define environment-for-assertion-errors
  environment-for-syntax-errors)

(define-syntax check-syntax-violation
  (syntax-rules (=>)
    ((_ ?body => ?result)
     (check
	 (guard (E ((syntax-violation? E)
		    (list (condition-message E)
;;;			  (syntax-violation-form E)
			  (syntax->datum (syntax-violation-subform E))))
		   (else E))
	   (eval (quote ?body) environment-for-syntax-errors
		 (expander-options strict-r6rs)
		 (compiler-options strict-r6rs)))
       (=> syntax=?) ?result))))

(define-syntax check-assertion-violation
  (syntax-rules (=>)
    ((_ ?body => ?result)
     (check
	 (guard (E ((assertion-violation? E)
		    (cons (condition-message E)
			  (condition-irritants E)))
		   (else E))
	   (eval (quote ?body) environment-for-assertion-errors
		 (expander-options strict-r6rs)
		 (compiler-options strict-r6rs)))
       => ?result))))

(define-syntax check-argument-violation
  (syntax-rules (=>)
    ((_ ?body => ?result)
     (check
	 (guard (E ((procedure-signature-argument-violation? E)
		    (procedure-signature-argument-violation.offending-value E))
		   ((procedure-argument-violation? E)
		    (when #f
		      (debug-print (condition-message E)))
		    (let ((D (cdr (condition-irritants E))))
		      (if (pair? D)
			  (car D)
			(condition-irritants E))))
		   (else E))
	   (eval (quote ?body) environment-for-assertion-errors
		 (expander-options strict-r6rs)
		 (compiler-options strict-r6rs)))
       => ?result))))


(parametrise ((check-test-name	'syntax-violations))

  (check-syntax-violation ;invalid type name
   (define-enumeration 123 (alpha beta delta) woppa)
   => '("expected identifier as enumeration type name" 123))

  (check-syntax-violation ;invalid constructor nam
   (define-enumeration enum-woppa (alpha beta delta) 123)
   => '("expected identifier as enumeration constructor syntax name" 123))

  (check-syntax-violation ;invalid list of symbols
   (define-enumeration enum-woppa 123 woppa)
   => '("invalid syntax, no clause matches the input form" #f))
;;;   => '("expected list of symbols as enumeration elements" 123))

  (check-syntax-violation ;invalid list of symbols
   (define-enumeration enum-woppa (123) woppa)
   => '("expected list of symbols as enumeration elements" (123)))

  (check-syntax-violation ;invalid list of symbols
   (define-enumeration enum-woppa (alpha beta 123 gamma) woppa)
   => '("expected list of symbols as enumeration elements" (alpha beta 123 gamma)))

;;; --------------------------------------------------------------------

  (check-syntax-violation ;wrong argument to validator
   (let ()
     (define-enumeration enum-woppa (alpha beta gamma) woppa)
     (enum-woppa 123))
   => '("expected symbol as argument to enumeration validator" 123))

  (check-syntax-violation ;invalid symbol to validator
   (let ()
     (define-enumeration enum-woppa (alpha beta gamma) woppa)
     (enum-woppa delta))
   => '("expected symbol in enumeration as argument to enumeration validator" delta))

  (check-syntax-violation ;wrong argument to constructor
   (let ()
     (define-enumeration enum-woppa (alpha beta gamma) woppa)
     (woppa 123))
   => '("expected symbols as arguments to enumeration constructor syntax" 123))

  (check-syntax-violation ;wrong argument to constructor
   (let ()
     (define-enumeration enum-woppa (alpha beta gamma) woppa)
     (woppa alpha beta 123))
   => '("expected symbols as arguments to enumeration constructor syntax" 123))

  (check-syntax-violation ;invalid symbol to constructor
   (let ()
     (define-enumeration enum-woppa (alpha beta gamma) woppa)
     (woppa delta))
   => '("expected symbols in enumeration as arguments to enumeration constructor syntax" (delta)))

  (check-syntax-violation ;invalid symbols to constructor
   (let ()
     (define-enumeration enum-woppa (alpha beta gamma) woppa)
     (woppa delta zeta))
   => '("expected symbols in enumeration as arguments to enumeration constructor syntax" (delta zeta)))

  (check-syntax-violation ;invalid symbol to constructor
   (let ()
     (define-enumeration enum-woppa (alpha beta gamma) woppa)
     (woppa alpha beta delta))
   => '("expected symbols in enumeration as arguments to enumeration constructor syntax"
	(delta)))

  #t)


(parametrise ((check-test-name	'assertion-violations))

  (check-argument-violation
      (make-enumeration 123)
    => 123)

  (check-argument-violation
      (make-enumeration '(123))
    => '(123))

  (check-argument-violation
      (make-enumeration '(alpha beta 123 gamma))
    => '(alpha beta 123 gamma))

;;; --------------------------------------------------------------------

  (check-argument-violation
      (enum-set-universe 123)
    => 123)

;;; --------------------------------------------------------------------

  (check-argument-violation
      (enum-set-indexer 123)
    => 123)

  (check-argument-violation
      (let* ((S (make-enumeration '(a b c)))
	     (I (enum-set-indexer S)))
	(I 123))
    => '(123))

;;; --------------------------------------------------------------------

  (check-argument-violation
      (enum-set-constructor 123)
    => 123)

  (check-argument-violation
      (let* ((S (make-enumeration '(a b c)))
	     (C (enum-set-constructor S)))
	(C 123))
    => '(123))

  (check-argument-violation
      (let* ((S (make-enumeration '(a b c)))
	     (C (enum-set-constructor S)))
	(C '(a b 123)))
    => '((a b 123)))

;;; --------------------------------------------------------------------

  (check-argument-violation
      (enum-set->list 123)
    => 123)

;;; --------------------------------------------------------------------

  (check-argument-violation
      (let ((A (make-enumeration '(a b c))))
	(enum-set-member? 123 A))
    => 123)

  (check-argument-violation
      (enum-set-member? 'ciao 123)
    => 123)

;;; --------------------------------------------------------------------

  (check-argument-violation
      (enum-set-subset? 123 (make-enumeration '(a b c)))
    => 123)

  (check-argument-violation
      (enum-set-subset? (make-enumeration '(a b c)) 123)
    => 123)

;;; --------------------------------------------------------------------

  (check-argument-violation
      (enum-set=? 123 (make-enumeration '(a b c)))
    => 123)

  (check-argument-violation
      (enum-set=? (make-enumeration '(a b c)) 123)
    => 123)

;;; --------------------------------------------------------------------

  (check-argument-violation
      (enum-set-union 123 (make-enumeration '(a b c)))
    => 123)

  (check-argument-violation
      (enum-set-union (make-enumeration '(a b c)) 123)
    => 123)

;;; --------------------------------------------------------------------

  (check-argument-violation
      (enum-set-intersection 123 (make-enumeration '(a b c)))
    => 123)

  (check-argument-violation
      (enum-set-intersection (make-enumeration '(a b c)) 123)
    => 123)

;;; --------------------------------------------------------------------

  (check-argument-violation
      (enum-set-difference 123 (make-enumeration '(a b c)))
    => 123)

  (check-argument-violation
      (enum-set-difference (make-enumeration '(a b c)) 123)
    => 123)

;;; --------------------------------------------------------------------

  (check-argument-violation
      (enum-set-complement 123)
    => 123)

;;; --------------------------------------------------------------------

  (check-argument-violation
      (enum-set-projection 123 (make-enumeration '(a b c)))
    => 123)

  (check-argument-violation
      (enum-set-projection (make-enumeration '(a b c)) 123)
    => 123)

  #t)


;;;; done

(check-report)

#| end of program |# )

;;; end of file
;; Local Variables:
;; eval: (put 'check-argument-violation 'scheme-indent-function 1)
;; End:
