;;;
;;;Part of: Vicare Scheme
;;;Contents: tests for records, typed language
;;;Date: Sat Sep 12, 2015
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
(program (test-vicare-records-typed)
  (options typed-language)
  (import (vicare)
    (vicare checks)
    (vicare expander tags))

(check-set-mode! 'report-failed)
(check-display "*** testing Vicare libraries: records with typed language\n")


(parametrise ((check-test-name	'generic-rtd-syntax))

  (let ()	;application syntax
    (define-record-type alpha
      (fields a b c))

    (check
	(eq? (record-type-descriptor alpha)
	     (type-descriptor alpha))
      => #t)

    (void))

  #t)


(parametrise ((check-test-name	'generic-maker-syntax))

  (internal-body ;application syntax
    (define-record-type alpha
      (fields a b c))

    (define-record-type beta
      (fields a b))

    (check
	(let ((reco (new alpha 1 2 3)))
	  (alpha? reco))
      => #t)

    (check
	(let ((reco (new beta 1 2)))
	  (beta? reco))
      => #t)

    (void))

  #t)


(parametrise ((check-test-name	'generic-predicate-syntax))

  (internal-body

    (define-record-type alpha
      (fields a b c))

    (define-record-type beta
      (fields a b c))

    (check
	(let ((stru (make-alpha 1 2 3)))
	  (is-a? stru alpha))
      => #t)

    (check
	(let ((stru (make-alpha 1 2 3)))
	  (is-a? stru beta))
      => #f)

    (check
	(let ((stru (make-alpha 1 2 3)))
	  ((is-a? _ alpha) stru))
      => #t)

    (check
	(is-a? 123 alpha)
      => #f)

    (check
	(is-a? 123 beta)
      => #f)

    (void))

;;; --------------------------------------------------------------------

  (check
      (internal-body
	(define-record-type duo
	  (fields one two))

	(is-a? (new duo 1 2) duo))
    => #t)

  (check
      (internal-body
	(define-record-type duo
	  (fields one two))

	(expansion-of
	 (is-a? (new duo 1 2) duo)))
    => '(quote #t))

  (check
      (internal-body
	(define-record-type alpha
	  (fields one two))
	(define-record-type beta
	  (fields one two))

	(expansion-of
	 (is-a? (new alpha 1 2) beta)))
    => '(quote #f))

  (check
      (internal-body
	(define-record-type alpha
	  (fields one two))
	(define-struct beta
	  (one two))

	(expansion-of
	 (is-a? (new alpha 1 2) beta)))
    => '(quote #f))

  (check
      (internal-body
	(define-record-type alpha
	  (fields one two))
	(define-struct beta
	  (one two))

	(expansion-of
	 (is-a? (new beta 1 2) alpha)))
    => '(quote #f))

  #t)


(parametrise ((check-test-name	'generic-slots-syntax))

  (define-record-type alpha
    (fields (mutable a)
	    (mutable b)
	    (mutable c)))

  (define-record-type beta
    (parent alpha)
    (fields (mutable d)
	    (mutable e)
	    (mutable f)))

  (define-record-type gamma
    (parent beta)
    (fields (mutable g)
	    (mutable h)
	    (mutable i)))

;;; --------------------------------------------------------------------
;;; accessors and mutators, no parent

  (check
      (let ((stru (new alpha 1 2 3)))
	(list (slot-ref stru a alpha)
	      (slot-ref stru b alpha)
	      (slot-ref stru c alpha)))
    => '(1 2 3))

  (check
      (let ((stru (new alpha 1 2 3)))
	(slot-set! stru a alpha 19)
	(slot-set! stru b alpha 29)
	(slot-set! stru c alpha 39)
	(list (slot-ref stru a alpha)
	      (slot-ref stru b alpha)
	      (slot-ref stru c alpha)))
    => '(19 29 39))

  (check
      (let ((stru (new alpha 1 2 3)))
	(list ((slot-ref _ a alpha) stru)
	      ((slot-ref _ b alpha) stru)
	      ((slot-ref _ c alpha) stru)))
    => '(1 2 3))

  (check
      (let ((stru (new alpha 1 2 3)))
	((slot-set! _ a alpha _) stru 19)
	((slot-set! _ b alpha _) stru 29)
	((slot-set! _ c alpha _) stru 39)
	(list ((slot-ref _ a alpha) stru)
	      ((slot-ref _ b alpha) stru)
	      ((slot-ref _ c alpha) stru)))
    => '(19 29 39))

  (check
      (let (({stru alpha} (new alpha 1 2 3)))
	(list (slot-ref stru a)
	      (slot-ref stru b)
	      (slot-ref stru c)))
    => '(1 2 3))

  (check
      (let (({stru alpha} (new alpha 1 2 3)))
	(slot-set! stru a 19)
	(slot-set! stru b 29)
	(slot-set! stru c 39)
	(list (slot-ref stru a)
	      (slot-ref stru b)
	      (slot-ref stru c)))
    => '(19 29 39))

;;; --------------------------------------------------------------------
;;; accessors and mutators, parent

  (check
      (let ((stru (new beta 1 2 3 4 5 6)))
	(values (slot-ref stru a alpha)
		(slot-ref stru b alpha)
		(slot-ref stru c alpha)
		(slot-ref stru a beta)
		(slot-ref stru b beta)
		(slot-ref stru c beta)
		(slot-ref stru d beta)
		(slot-ref stru e beta)
		(slot-ref stru f beta)))
    => 1 2 3 1 2 3 4 5 6)

  (check
      (let ((stru (new beta 1 2 3 4 5 6)))
	(slot-set! stru a beta 10)
	(slot-set! stru b beta 20)
	(slot-set! stru c beta 30)
	(slot-set! stru d beta 40)
	(slot-set! stru e beta 50)
	(slot-set! stru f beta 60)
	(values (slot-ref stru a beta)
		(slot-ref stru b beta)
		(slot-ref stru c beta)
		(slot-ref stru d beta)
		(slot-ref stru e beta)
		(slot-ref stru f beta)))
    => 10 20 30 40 50 60)

;;; --------------------------------------------------------------------
;;; accessors and mutators, parent and grand-parent

  (check
      (let ((stru (new gamma 1 2 3 4 5 6 7 8 9)))
	(values (slot-ref stru a alpha)
		(slot-ref stru b alpha)
		(slot-ref stru c alpha)))
    => 1 2 3)

  (check
      (let ((stru (new gamma 1 2 3 4 5 6 7 8 9)))
	(values (slot-ref stru a beta)
		(slot-ref stru b beta)
		(slot-ref stru c beta)
		(slot-ref stru d beta)
		(slot-ref stru e beta)
		(slot-ref stru f beta)))
    => 1 2 3 4 5 6)

  (check
      (let ((stru (new gamma 1 2 3 4 5 6 7 8 9)))
	(values (slot-ref stru a gamma)
		(slot-ref stru b gamma)
		(slot-ref stru c gamma)
		(slot-ref stru d gamma)
		(slot-ref stru e gamma)
		(slot-ref stru f gamma)
		(slot-ref stru g gamma)
		(slot-ref stru h gamma)
		(slot-ref stru i gamma)))
    => 1 2 3 4 5 6 7 8 9)

  (check
      (let ((stru (new gamma 1 2 3 4 5 6 7 8 9)))
	(slot-set! stru a gamma 10)
	(slot-set! stru b gamma 20)
	(slot-set! stru c gamma 30)
	(slot-set! stru d gamma 40)
	(slot-set! stru e gamma 50)
	(slot-set! stru f gamma 60)
	(slot-set! stru g gamma 70)
	(slot-set! stru h gamma 80)
	(slot-set! stru i gamma 90)
	(values (slot-ref stru a gamma)
		(slot-ref stru b gamma)
		(slot-ref stru c gamma)
		(slot-ref stru d gamma)
		(slot-ref stru e gamma)
		(slot-ref stru f gamma)
		(slot-ref stru g gamma)
		(slot-ref stru h gamma)
		(slot-ref stru i gamma)))
    => 10 20 30 40 50 60 70 80 90)

  (check
      (let ((stru (new gamma 1 2 3 4 5 6 7 8 9)))
	(slot-set! stru a alpha 10)
	(slot-set! stru b alpha 20)
	(slot-set! stru c alpha 30)
	(slot-set! stru d beta 40)
	(slot-set! stru e beta 50)
	(slot-set! stru f beta 60)
	(slot-set! stru g gamma 70)
	(slot-set! stru h gamma 80)
	(slot-set! stru i gamma 90)
	(values (slot-ref stru a alpha)
		(slot-ref stru b alpha)
		(slot-ref stru c alpha)
		(slot-ref stru d beta)
		(slot-ref stru e beta)
		(slot-ref stru f beta)
		(slot-ref stru g gamma)
		(slot-ref stru h gamma)
		(slot-ref stru i gamma)))
    => 10 20 30 40 50 60 70 80 90)

  #t)


(parametrise ((check-test-name	'methods))

;;; no parent

  (check
      (internal-body

	(define-record-type alpha
	  (fields (mutable a) (mutable b))
	  (method (get-a O)
	    (alpha-a O))
	  (method (get-b O)
	    (alpha-b O)))

	(define {O alpha}
	  (make-alpha 1 2))

	(values (method-call get-a O)
		(method-call get-b O)))
    => 1 2)

  (check
      (internal-body

	(define-record-type alpha
	  (fields (mutable a) (mutable b))
	  (method (get-a O)
	    (alpha-a O))
	  (method (get-b O)
	    (alpha-b O))
	  (method (set-a O v)
	    (alpha-a-set! O v))
	  (method (set-b O v)
	    (alpha-b-set! O v)))

	(define {O alpha}
	  (make-alpha 1 2))

	(method-call set-a O 10)
	(method-call set-b O 20)
	(values (method-call get-a O)
		(method-call get-b O)))
    => 10 20)

  ;;Field accessors.
  ;;
  (check
      (internal-body

	(define-record-type alpha
	  (fields a b))

	(define {O alpha}
	  (make-alpha 1 2))

	(values (method-call a O)
		(method-call b O)))
    => 1 2)

  ;;Field accessors and mutators.
  ;;
  (check
      (internal-body

	(define-record-type alpha
	  (fields (mutable a)
		  (mutable b)))

	(define {O alpha}
	  (make-alpha 1 2))

	(method-call a O 10)
	(method-call b O 20)
	(values (method-call a O)
		(method-call b O)))
    => 10 20)

;;; --------------------------------------------------------------------
;;; calling parent's methods

  ;;Record-type with parent.
  ;;
  (check
      (internal-body

	(define-record-type duo
	  (fields one two)
	  (method (sum-them O)
	    (+ (duo-one O)
	       (duo-two O))))

	(define-record-type trio
	  (parent duo)
	  (fields three)
	  (method (mul-them O)
	    (* (duo-one O)
	       (duo-two O)
	       (trio-three O))))

	(define {O trio}
	  (make-trio 3 5 7))

	(values (method-call sum-them O)
		(method-call mul-them O)))
    => (+ 3 5) (* 3 5 7))

  ;;Record-type with parent and grandparent.
  ;;
  (check
      (internal-body

	(define-record-type duo
	  (fields one two)
	  (method (sum-them O)
	    (+ (duo-one O)
	       (duo-two O))))

	(define-record-type trio
	  (parent duo)
	  (fields three)
	  (method (mul-them O)
	    (* (duo-one O)
	       (duo-two O)
	       (trio-three O))))

	(define-record-type quater
	  (parent trio)
	  (fields four)
	  (method (list-them O)
	    (list (duo-one O)
		  (duo-two O)
		  (trio-three O)
		  (quater-four O))))

	(define {O quater}
	  (make-quater 3 5 7 11))

	(values (method-call sum-them O)
		(method-call mul-them O)
		(method-call list-them O)))
    => (+ 3 5) (* 3 5 7) (list 3 5 7 11))

  ;;Accessing fields of record-type with parent.
  ;;
  (check
      (internal-body

	(define-record-type duo
	  (fields one two))

	(define-record-type trio
	  (parent duo)
	  (fields three))

	(define {O trio}
	  (make-trio 3 5 7))

	(values (method-call one O)
		(method-call two O)
		(method-call three O)))
    => 3 5 7)

  ;;Accessing and mutating fields of record-type with parent.
  ;;
  (check
      (internal-body

	(define-record-type duo
	  (fields (mutable one)
		  (mutable two)))

	(define-record-type trio
	  (parent duo)
	  (fields (mutable three)))

	(define {O trio}
	  (make-trio 3 5 7))

	(method-call one O 30)
	(method-call two O 50)
	(method-call three O 70)
	(values (method-call one O)
		(method-call two O)
		(method-call three O)))
    => 30 50 70)

  ;;Accessing fields of record-type with parent and grandparent.
  ;;
  (check
      (internal-body

	(define-record-type duo
	  (fields one two))

	(define-record-type trio
	  (parent duo)
	  (fields three))

	(define-record-type quater
	  (parent trio)
	  (fields four))

	(define {O quater}
	  (make-quater 3 5 7 11))

	(values (method-call one O)
		(method-call two O)
		(method-call three O)
		(method-call four O)))
    => 3 5 7 11)

  ;;Accessing and mutating fields of record-type with parent and grandparent.
  ;;
  (check
      (internal-body

	(define-record-type duo
	  (fields (mutable one)
		  (mutable two)))

	(define-record-type trio
	  (parent duo)
	  (fields (mutable three)))

	(define-record-type quater
	  (parent trio)
	  (fields (mutable four)))

	(define {O quater}
	  (make-quater 3 5 7 11))

	(method-call one O 1)
	(method-call two O 2)
	(method-call three O 3)
	(method-call four O 4)
	(values (method-call one O)
		(method-call two O)
		(method-call three O)
		(method-call four O)))
    => 1 2 3 4)

;;; --------------------------------------------------------------------
;;; dot notation

  (check
      (internal-body

	(define-record-type alpha
	  (fields (mutable a) (mutable b))
	  (method (get-a O)
	    (alpha-a O))
	  (method (get-b O)
	    (alpha-b O)))

	(define {O alpha}
	  (make-alpha 1 2))

	(values (.get-a O)
		(.get-b O)))
    => 1 2)

  (check
      (internal-body

	(define-record-type alpha
	  (fields (mutable a) (mutable b))
	  (method (get-a O)
	    (alpha-a O))
	  (method (get-b O)
	    (alpha-b O))
	  (method (set-a O v)
	    (alpha-a-set! O v))
	  (method (set-b O v)
	    (alpha-b-set! O v)))

	(define {O alpha}
	  (make-alpha 1 2))

	(.set-a O 10)
	(.set-b O 20)
	(values (.get-a O)
		(.get-b O)))
    => 10 20)

  ;;Accessing and mutating fields of record-type with parent and grandparent.
  ;;
  (check
      (internal-body

	(define-record-type duo
	  (fields (mutable one)
		  (mutable two)))

	(define-record-type trio
	  (parent duo)
	  (fields (mutable three)))

	(define-record-type quater
	  (parent trio)
	  (fields (mutable four)))

	(define {O quater}
	  (make-quater 3 5 7 11))

	(.one O 1)
	(.two O 2)
	(.three O 3)
	(.four O 4)
	(values (.one O)
		(.two O)
		(.three O)
		(.four O)))
    => 1 2 3 4)

;;; --------------------------------------------------------------------
;;; misc method examples

  (check
      (internal-body

	(define-record-type alpha
	  (fields a b)
	  (method (doit O c d)
	    (+ (alpha-a O) (alpha-b O) c d)))

	(define {O alpha}
	  (make-alpha 1 2))

	(.doit O 3 4))
    => (+ 1 2 3 4))

  (check
      (internal-body

	(define-record-type alpha
	  (fields a b)
	  (method (doit O . arg*)
	    (apply + (alpha-a O) (alpha-b O) arg*)))

	(define {O alpha}
	  (make-alpha 1 2))

	(.doit O 3 4))
    => (+ 1 2 3 4))

;;; --------------------------------------------------------------------
;;; documentation examples

  (check
      (internal-body

	(define-record-type duo
	  (fields one two)
	  (method (sum-them self)
	    (+ (duo-one self)
	       (duo-two self)))
	  (method (mul-them self)
	    (* (duo-one self)
	       (duo-two self))))

	(define {O duo}
	  (new duo 3 5))

	(values (method-call sum-them O)
		(method-call mul-them O)))
    => 8 15)

  (check
      (internal-body

	(define-record-type duo
	  (fields one two)
	  (method (sum-them {self duo})
	    (+ (.one self)
	       (.two self)))
	  (method (mul-them {self duo})
	    (* (.one self)
	       (.two self))))

	(define {O duo}
	  (new duo 3 5))

	(values (.sum-them O)
		(.mul-them O)))
    => 8 15)

  (check
      (internal-body
	(define-record-type alpha
	  (fields (mutable a)))

	(define {O alpha}
	  (new alpha 1))

	(method-call a O 2)
	(method-call a O))
    => 2)

  #t)


(parametrise ((check-test-name	'case-methods))

  (check
      (internal-body

	(define-record-type alpha
	  (fields (mutable a) (mutable b))
	  (case-method get-a
	    ((O)
	     (alpha-a O)))
	  (case-method get-b
	    ((O)
	     (alpha-b O))))

	(define {O alpha}
	  (make-alpha 1 2))

	(values (method-call get-a O)
		(method-call get-b O)))
    => 1 2)

  (check
      (internal-body

	(define-record-type alpha
	  (fields (mutable a) (mutable b))
	  (case-method on-a
	    ((O)
	     (alpha-a O))
	    ((O v)
	     (alpha-a-set! O v)))
	  (case-method on-b
	    ((O)
	     (alpha-b O))
	    ((O v)
	     (alpha-b-set! O v))))

	(define {O alpha}
	  (make-alpha 1 2))

	(method-call on-a O 10)
	(method-call on-b O 20)
	(values (method-call on-a O)
		(method-call on-b O)))
    => 10 20)

;;; --------------------------------------------------------------------
;;; dot notation

  (check
      (internal-body

	(define-record-type alpha
	  (fields (mutable a) (mutable b))
	  (case-method on-a
	    ((O)
	     (alpha-a O)))
	  (case-method on-b
	    ((O)
	     (alpha-b O))))

	(define {O alpha}
	  (make-alpha 1 2))

	(values (.on-a O)
		(.on-b O)))
    => 1 2)

  (check
      (internal-body

	(define-record-type alpha
	  (fields (mutable a) (mutable b))
	  (case-method on-a
	    ((O)
	     (alpha-a O))
	    ((O v)
	     (alpha-a-set! O v)))
	  (case-method on-b
	    ((O)
	     (alpha-b O))
	    ((O v)
	     (alpha-b-set! O v))))

	(define {O alpha}
	  (make-alpha 1 2))

	(.on-a O 10)
	(.on-b O 20)
	(values (.on-a O)
		(.on-b O)))
    => 10 20)

;;; --------------------------------------------------------------------
;;; misc method examples

  (check
      (internal-body

	(define-record-type alpha
	  (fields a b)
	  (case-method doit
	    ((O c d)
	     (+ (alpha-a O) (alpha-b O) c d))))

	(define {O alpha}
	  (make-alpha 1 2))

	(.doit O 3 4))
    => (+ 1 2 3 4))

  (check
      (internal-body

	(define-record-type alpha
	  (fields a b)
	  (case-method doit
	    ((O . arg*)
	     (apply + (alpha-a O) (alpha-b O) arg*))))

	(define {O alpha}
	  (make-alpha 1 2))

	(.doit O 3 4))
    => (+ 1 2 3 4))

  #t)


(parametrise ((check-test-name	'methods-late-binding))

;;; METHOD-CALL, late binding, calling methods

  ;;Calling methods.
  ;;
  (check
      (internal-body

	(define-record-type alpha
	  (fields (mutable a) (mutable b))
	  (method (get-a O)
	    (alpha-a O))
	  (method (get-b O)
	    (alpha-b O)))

	(define {O alpha}
	  (make-alpha 1 2))

	(define ({the-record <top>})
	  O)

	#;(debug-print (property-list (record-type-uid (record-type-descriptor alpha))))

	(values (.get-a (the-record))
		(.get-b (the-record))))
    => 1 2)

  ;;Calling methods and parent's methods.
  ;;
  (check
      (internal-body

	(define-record-type alpha
	  (fields a b)
	  (method (add-them {O alpha})
	    (+ (.a O) (.b O))))

	(define-record-type beta
	  (parent alpha)
	  (method (mul-them {O beta})
	    (* (.a O) (.b O))))

	(define {O beta}
	  (make-beta 3 5))

	(define ({the-record <top>})
	  O)

	(values (.add-them (the-record))
		(.mul-them (the-record))))
    => 8 15)

  ;;Calling methods, parent's methods, grandparent's methods.
  ;;
  (check
      (internal-body

	(define-record-type alpha
	  (fields a b)
	  (method (add-them {O alpha})
	    (+ (.a O) (.b O))))

	(define-record-type beta
	  (parent alpha)
	  (method (mul-them {O beta})
	    (* (.a O) (.b O))))

	(define-record-type gamma
	  (parent beta)
	  (method (list-them {O gamma})
	    (list (.a O) (.b O))))

	(define {O gamma}
	  (make-gamma 3 5))

	(define ({the-record <top>})
	  O)

	(values (.add-them (the-record))
		(.mul-them (the-record))
		(.list-them (the-record))))
    => 8 15 '(3 5))

;;; --------------------------------------------------------------------
;;; METHOD-CALL-LATE-BINDING, calling methods

  ;;Calling methods.
  ;;
  (check
      (internal-body

	(define-record-type alpha
	  (fields (mutable a) (mutable b))
	  (method (get-a O)
	    (alpha-a O))
	  (method (get-b O)
	    (alpha-b O)))

	(define {O alpha}
	  (make-alpha 1 2))

	(define ({the-record <top>})
	  O)

	#;(debug-print (property-list (record-type-uid (record-type-descriptor alpha))))

	(values (method-call-late-binding 'get-a (the-record))
		(method-call-late-binding 'get-b (the-record))))
    => 1 2)

  ;;Calling methods and parent's methods.
  ;;
  (check
      (internal-body

	(define-record-type alpha
	  (fields a b)
	  (method (add-them {O alpha})
	    (+ (.a O) (.b O))))

	(define-record-type beta
	  (parent alpha)
	  (method (mul-them {O beta})
	    (* (.a O) (.b O))))

	(define {O beta}
	  (make-beta 3 5))

	(define ({the-record <top>})
	  O)

	(values (method-call-late-binding 'add-them (the-record))
		(method-call-late-binding 'mul-them (the-record))))
    => 8 15)

  ;;Calling methods, parent's methods, grandparent's methods.
  ;;
  (check
      (internal-body

	(define-record-type alpha
	  (fields a b)
	  (method (add-them {O alpha})
	    (+ (.a O) (.b O))))

	(define-record-type beta
	  (parent alpha)
	  (method (mul-them {O beta})
	    (* (.a O) (.b O))))

	(define-record-type gamma
	  (parent beta)
	  (method (list-them {O gamma})
	    (list (.a O) (.b O))))

	(define {O gamma}
	  (make-gamma 3 5))

	(define ({the-record <top>})
	  O)

	(values (method-call-late-binding 'add-them (the-record))
		(method-call-late-binding 'mul-them (the-record))
		(method-call-late-binding 'list-them (the-record))))
    => 8 15 '(3 5))

;;; --------------------------------------------------------------------
;;; METHOD-CALL-LATE-BINDING, accessing fields

  ;;Accessing fields.
  ;;
  (check
      (internal-body

	(define-record-type alpha
	  (fields a b))

	(define O
	  (make-alpha 1 2))

	#;(debug-print (property-list (record-type-uid (record-type-descriptor alpha))))
	(values (method-call-late-binding 'a O)
		(method-call-late-binding 'b O)))
    => 1 2)

  ;;Accessing parent's fields.
  ;;
  (check
      (internal-body

	(define-record-type alpha
	  (fields a b))

	(define-record-type beta
	  (parent alpha)
	  (fields c d))

	(define O
	  (make-beta 1 2 3 4))

	#;(debug-print (property-list (record-type-uid (record-type-descriptor alpha))))
	(values (method-call-late-binding 'a O)
		(method-call-late-binding 'b O)
		(method-call-late-binding 'c O)
		(method-call-late-binding 'd O)))
    => 1 2 3 4)

  ;;Accessing grandparent's fields.
  ;;
  (check
      (internal-body

	(define-record-type alpha
	  (fields a b))

	(define-record-type beta
	  (parent alpha)
	  (fields c d))

	(define-record-type gamma
	  (parent beta)
	  (fields e f))

	(define O
	  (make-gamma 1 2 3 4 5 6))

	#;(debug-print (property-list (record-type-uid (record-type-descriptor alpha))))
	(values (method-call-late-binding 'a O)
		(method-call-late-binding 'b O)
		(method-call-late-binding 'c O)
		(method-call-late-binding 'd O)
		(method-call-late-binding 'e O)
		(method-call-late-binding 'f O)))
    => 1 2 3 4 5 6)

;;; --------------------------------------------------------------------
;;; METHOD-CALL-LATE-BINDING, accessing and mutating fields

  ;;Accessing fields.
  ;;
  (check
      (internal-body

	(define-record-type alpha
	  (fields (mutable a) (mutable b)))

	(define O
	  (make-alpha 1 2))

	(method-call-late-binding 'a O 11)
	(method-call-late-binding 'b O 22)

	#;(debug-print (property-list (record-type-uid (record-type-descriptor alpha))))
	(values (method-call-late-binding 'a O)
		(method-call-late-binding 'b O)))
    => 11 22)

  ;;Accessing parent's fields.
  ;;
  (check
      (internal-body

	(define-record-type alpha
	  (fields (mutable a) (mutable b)))

	(define-record-type beta
	  (parent alpha)
	  (fields (mutable c) (mutable d)))

	(define O
	  (make-beta 1 2 3 4))

	(method-call-late-binding 'a O 11)
	(method-call-late-binding 'b O 22)
	(method-call-late-binding 'c O 33)
	(method-call-late-binding 'd O 44)

	#;(debug-print (property-list (record-type-uid (record-type-descriptor alpha))))
	(values (method-call-late-binding 'a O)
		(method-call-late-binding 'b O)
		(method-call-late-binding 'c O)
		(method-call-late-binding 'd O)))
    => 11 22 33 44)

  ;;Accessing grandparent's fields.
  ;;
  (check
      (internal-body

	(define-record-type alpha
	  (fields (mutable a) (mutable b)))

	(define-record-type beta
	  (parent alpha)
	  (fields (mutable c) (mutable d)))

	(define-record-type gamma
	  (parent beta)
	  (fields (mutable e) (mutable f)))

	(define O
	  (make-gamma 1 2 3 4 5 6))

	(method-call-late-binding 'a O 11)
	(method-call-late-binding 'b O 22)
	(method-call-late-binding 'c O 33)
	(method-call-late-binding 'd O 44)
	(method-call-late-binding 'e O 55)
	(method-call-late-binding 'f O 66)

	#;(debug-print (property-list (record-type-uid (record-type-descriptor alpha))))
	(values (method-call-late-binding 'a O)
		(method-call-late-binding 'b O)
		(method-call-late-binding 'c O)
		(method-call-late-binding 'd O)
		(method-call-late-binding 'e O)
		(method-call-late-binding 'f O)))
    => 11 22 33 44 55 66)

  (void))


;;;; done

(collect 'fullest)
(check-report)

#| end of program |# )

;;; end of file
;; Local Variables:
;; mode: vicare
;; coding: utf-8
;; End:
