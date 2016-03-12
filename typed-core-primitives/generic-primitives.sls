;;
;;Part of: Vicare Scheme
;;Contents: table of expand-time properties for generic core primitives
;;Date: Tue Dec 22, 2015
;;
;;Abstract
;;
;;
;;
;;Copyright (C) 2015, 2016 Marco Maggi <marco.maggi-ipsu@poste.it>
;;
;;This program is free  software: you can redistribute it and/or  modify it under the
;;terms  of  the  GNU General  Public  License  as  published  by the  Free  Software
;;Foundation, either version 3 of the License, or (at your option) any later version.
;;
;;This program  is distributed in the  hope that it  will be useful, but  WITHOUT ANY
;;WARRANTY; without  even the implied  warranty of  MERCHANTABILITY or FITNESS  FOR A
;;PARTICULAR PURPOSE.  See the GNU General Public License for more details.
;;
;;You should have received  a copy of the GNU General Public  License along with this
;;program.  If not, see <http://www.gnu.org/licenses/>.
;;

#!vicare
(library (typed-core-primitives generic-primitives)
  (export typed-core-primitives.generic-primitives)
  (import (vicare)
    (typed-core-primitives syntaxes))

(define (typed-core-primitives.generic-primitives)


;;;; generic primitives

(section

(declare-core-primitive immediate?
    (safe)
  (signatures
   ((<fixnum>)		=> (<true>))
   ((<char>)		=> (<true>))
   ((<null>)		=> (<true>))
   ((<boolean>)		=> (<true>))
   ((<eof>)		=> (<true>))
   ((<void>)		=> (<true>))
   ((<transcoder>)	=> (<true>))

   ((<bignum>)		=> (<false>))
   ((<flonum>)		=> (<false>))
   ((<ratnum>)		=> (<false>))
   ((<compnum>)		=> (<false>))
   ((<cflonum>)		=> (<false>))
   ((<pair>)		=> (<false>))
   ((<string>)		=> (<false>))
   ((<vector>)		=> (<false>))
   ((<bytevector>)	=> (<false>))
   ((<struct>)		=> (<false>))
   ((<port>)		=> (<false>))
   ((<symbol>)		=> (<false>))
   ((<keyword>)		=> (<false>))
   ((<hashtable>)	=> (<false>))
   ((<would-block>)	=> (<false>))

   ((<top>)		=> (<boolean>)))
  (attributes
   ((_)			foldable effect-free)))

(declare-type-predicate code?		<code>)
(declare-type-predicate procedure?	<procedure>)

(declare-core-primitive procedure-annotation
    (safe)
  (signatures
   ((<procedure>)	=> (<top>)))
  (attributes
   ((_)			effect-free)))

(declare-object-binary-comparison eq?)
(declare-object-binary-comparison neq?)
(declare-object-binary-comparison eqv?)
(declare-object-binary-comparison equal?)

(declare-object-predicate not)

;;; --------------------------------------------------------------------

(declare-core-primitive vicare-argv0
    (safe)
  (signatures
   (()			=> (<bytevector>)))
  (attributes
   (()			effect-free result-true)))

(declare-core-primitive vicare-argv0-string
    (safe)
  (signatures
   (()			=> (<string>)))
  (attributes
   (()			effect-free result-true)))

;;; --------------------------------------------------------------------

(declare-core-primitive void
    (safe)
  (signatures
   (()				=> (<void>)))
  (attributes
   (()				foldable effect-free result-true)))

(declare-type-predicate void-object? <void>)

(declare-core-primitive load
    (safe)
  (signatures
   ((<string>)			=> <list>)
   ((<string> <procedure>)	=> <list>)))

(declare-core-primitive make-traced-procedure
    (safe)
  (signatures
   ((<symbol> <procedure>)	=> (<procedure>)))
  (attributes
   ((_ _)		effect-free result-true)))

(declare-core-primitive make-traced-macro
    (safe)
  (signatures
   ((<symbol> <procedure>)	=> (<procedure>)))
  (attributes
   ((_ _)		effect-free result-true)))

;;; --------------------------------------------------------------------

(declare-core-primitive  random
    (safe)
  (signatures
   ((<fixnum>)		=> (<fixnum>)))
  (attributes
   ;;Not foldable  because the random number  must be generated at  run-time, one for
   ;;each invocation.
   ((_)			effect-free result-true)))

;;; --------------------------------------------------------------------

(declare-object-retriever uuid			<string>)

(declare-object-retriever bwp-object)
(declare-object-predicate bwp-object?)

(declare-object-retriever unbound-object)
(declare-object-predicate unbound-object?)

(declare-object-predicate $unbound-object?	unsafe)

;;; --------------------------------------------------------------------

(declare-parameter interrupt-handler	<procedure>)
(declare-parameter engine-handler	<procedure>)

;;; --------------------------------------------------------------------

(declare-core-primitive always-true
    (safe)
  (signatures
   (_				=> (<true>)))
  (attributes
   (_				foldable effect-free result-true)))

(declare-core-primitive always-false
    (safe)
  (signatures
   (_				=> (<false>)))
  (attributes
   (_				foldable effect-free result-false)))

;;; --------------------------------------------------------------------

(declare-core-primitive new-cafe
    (safe)
  (signatures
   (()			=> (<void>))
   ((<procedure>)	=> (<void>)))
  (attributes
   (()			result-true)
   ((_)			result-true)))

(declare-parameter waiter-prompt-string		<string>)
(declare-parameter cafe-input-port		<textual-input-port>)

(declare-core-primitive apropos
    (safe)
  (signatures
   ((<string>)		=> (<void>)))
  (attributes
   ((_)			result-true)))

;;; --------------------------------------------------------------------

(declare-core-primitive readline-enabled?
    (safe)
  (signatures
   (()			=> (<boolean>)))
  (attributes
   (()			effect-free)))

(declare-core-primitive readline
    (safe)
  (signatures
   (()						=> (<string>))
   ((<false>)					=> (<string>))
   ((<bytevector>)				=> (<string>))
   ((<string>)					=> (<string>)))
  (attributes
   (()			result-true)
   ((_)			result-true)))

(declare-core-primitive make-readline-input-port
    (safe)
  (signatures
   (()					=> (<textual-input-port>))
   ((<false>)				=> (<textual-input-port>))
   ((<procedure>)			=> (<textual-input-port>)))
  (attributes
   (()			result-true)
   ((_)			result-true)))

;;; --------------------------------------------------------------------

(declare-core-primitive fasl-write
    (safe)
  (signatures
   ((<top> <binary-output-port>)			=> (<void>))
   ((<top> <binary-output-port> <list>)	=> (<void>)))
  (attributes
   ((_ _)		result-true)
   ((_ _ _)		result-true)))

(declare-core-primitive fasl-read
    (safe)
  (signatures
   ((<binary-input-port>)	=> (<top>))))

/section)


;;;; foldable core primitive variants

(section

(declare-core-primitive foldable-cons
    (safe)
  (signatures
   ((_ _)		=> (<pair>)))
  (attributes
   ((_ _)		foldable effect-free result-true)))

(declare-core-primitive foldable-list
    (safe)
  (signatures
   (()			=> (<null>))
   ((_ . _)		=> (<nlist>)))
  (attributes
   (()			foldable effect-free result-true)
   ((_ . _)		foldable effect-free result-true)))

(declare-core-primitive foldable-string
    (safe)
  (signatures
   (()			=> (<string>))
   ((list-of <char>)	=> (<string>)))
  (attributes
   (()			foldable effect-free result-true)
   (_			foldable effect-free result-true)))

(declare-core-primitive foldable-vector
    (safe)
  (signatures
   (()				=> (<vector>))
   (_				=> (<vector>)))
  (attributes
   (()				foldable effect-free result-true)
   (_				foldable effect-free result-true)))

(declare-core-primitive foldable-list->vector
    (safe)
  (signatures
   ((<list>)			=> (<vector>)))
  (attributes
   ((_)				foldable effect-free result-true)))

(declare-core-primitive foldable-append
    (safe)
  (signatures
   (()				=> (<null>))
   ((<top> . <list>)		=> (<pair>)))
  (attributes
   (()				foldable effect-free result-true)
   ((_ . _)			foldable effect-free result-true)))

/section)


;;;; debugging helpers

(section

(declare-exact-integer-unary integer->machine-word)

(declare-core-primitive machine-word->integer
  (safe)
  (signatures
   ((<top>)			=> (<exact-integer>)))
  (attributes
   ((_)				effect-free result-true)))

;;; --------------------------------------------------------------------

(declare-core-primitive flonum->bytevector
    (safe)
  (signatures
   ((<flonum>)		=> (<bytevector>)))
  (attributes
   ((_)			foldable effect-free result-true)))

(declare-core-primitive bytevector->flonum
    (safe)
  (signatures
   ((<bytevector>)	=> (<flonum>)))
  (attributes
   ((_)			foldable effect-free result-true)))

;;; --------------------------------------------------------------------

(declare-core-primitive bignum->bytevector
    (safe)
  (signatures
   ((<bignum>)		=> (<bytevector>)))
  (attributes
   ((_)			foldable effect-free result-true)))

(declare-core-primitive bytevector->bignum
    (safe)
  (signatures
   ((<bytevector>)	=> (<bignum>)))
  (attributes
   ((_)			foldable effect-free result-true)))

;;; --------------------------------------------------------------------

(declare-core-primitive time-it
    (safe)
  (signatures
   ((<string> <procedure>)	=> <list>)))

(declare-core-primitive time-and-gather
    (safe)
  (signatures
   ((<procedure> <procedure>)	=> <list>)))

(declare-parameter verbose-timer)

;;;

(declare-type-predicate stats?		<stats>)

(letrec-syntax
    ((declare (syntax-rules ()
		((_ ?who)
		 (declare ?who <top>))
		((_ ?who ?return-value-tag)
		 (declare-core-primitive ?who
		     (safe)
		   (signatures
		    ((<stats>)		=> (?return-value-tag)))
		   (attributes
		    ((_)		effect-free))))
		)))
  (declare stats-collection-id)
  (declare stats-user-secs	<exact-integer>)
  (declare stats-user-usecs	<exact-integer>)
  (declare stats-sys-secs	<exact-integer>)
  (declare stats-sys-usecs	<exact-integer>)
  (declare stats-real-secs	<exact-integer>)
  (declare stats-real-usecs	<exact-integer>)
  (declare stats-gc-user-secs	<exact-integer>)
  (declare stats-gc-user-usecs	<exact-integer>)
  (declare stats-gc-sys-secs	<exact-integer>)
  (declare stats-gc-sys-usecs	<exact-integer>)
  (declare stats-gc-real-secs	<exact-integer>)
  (declare stats-gc-real-usecs	<exact-integer>)
  (declare stats-bytes-minor	<exact-integer>)
  (declare stats-bytes-major	<exact-integer>)
  #| end of LET-SYNTAX |# )

/section)


;;;; core syntactic binding descriptors, typed safe OOP core primitives: generic objects

(section

(declare-core-primitive <top>-constructor
    (safe)
  (signatures
   ((<top>)		=> (<top>))))

(declare-core-primitive <top>-type-predicate
    (safe)
  (signatures
   ((<top>)		=> (<true>))))

/section)


;;;; done

#| end of define |# )

#| end of library |# )

;;; end of file
;; Local Variables:
;; mode: vicare
;; eval: (put 'declare-core-primitive		'scheme-indent-function 1)
;; End: