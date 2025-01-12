;;;
;;;Part of: Vicare Scheme
;;;Contents: tests for R6RS records, procedural layer
;;;Date: Fri Mar 16, 2012
;;;
;;;Abstract
;;;
;;;
;;;
;;;Copyright (C) 2012-2015 Marco Maggi <marco.maggi-ipsu@poste.it>
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


#!r6rs
(import (rename (vicare)
		(make-record-type-descriptor		make-record-type-descriptor*)
		(make-record-constructor-descriptor	make-record-constructor-descriptor*))
  (vicare language-extensions syntaxes)
  (vicare checks))

(check-set-mode! 'report-failed)
(check-display "*** testing Vicare R6RS records, procedural layer\n")


;;;; syntax helpers

(define-auxiliary-syntaxes
  name: parent: uid: sealed: opaque: fields:)

(define-syntax make-record-type-descriptor
  (syntax-rules (name: parent: uid: sealed: opaque: fields:)
    ((_ (name: ?name) (parent: ?parent) (uid: ?uid)
	(sealed: ?sealed) (opaque: ?opaque) (fields: ?fields))
     (make-record-type-descriptor* ?name ?parent ?uid ?sealed ?opaque ?fields))))

(define-syntax make-record-constructor-descriptor
  (syntax-rules (rtd: parent-rcd: protocol:)
    ((_ (rtd: ?rtd) (parent-rcd: ?prcd) (protocol: ?protocol))
     (make-record-constructor-descriptor* ?rtd ?prcd ?protocol))))

;;; --------------------------------------------------------------------

(define-syntax check-argument-violation
  (syntax-rules (=>)
    ((_ ?body => ?result)
     (check
	 (guard (E ((procedure-signature-argument-violation? E)
		    #;(print-condition E)
		    (procedure-signature-argument-violation.offending-value E))
		   ((procedure-arguments-consistency-violation? E)
		    #;(print-condition E)
		    (condition-irritants E))
		   ((procedure-argument-violation? E)
		    (when #f
		      (debug-print (condition-message E)))
		    (let ((D (cdr (condition-irritants E))))
		      (if (pair? D)
			  (car D)
			(condition-irritants E))))
		   ((assertion-violation? E)
		    (condition-irritants E))
		   (else
		    (print-condition E)
		    E))
	   ?body)
       => ?result))))



(parametrise ((check-test-name	'make-rtd))

  (define parent-0
    (make-record-type-descriptor
     (name: 'rtd-parent-0) (parent: #f) (uid: 'rtd-parent-0)
     (sealed: #f) (opaque: #f) (fields: '#())))

  (define parent-1
    (make-record-type-descriptor
     (name: 'rtd-parent-1) (parent: #f) (uid: 'rtd-parent-1)
     (sealed: #f) (opaque: #f) (fields: '#())))

;;; --------------------------------------------------------------------

  (check	;;some correct configuration values
      (let ((rtd (make-record-type-descriptor (name:	'make-rtd)
					      (parent:	#f)
					      (uid:	'make-rtd-0)
					      (sealed:	#f)
					      (opaque:	#f)
					      (fields:	'#()))))
	(list (record-type-descriptor? rtd)
	      (record-type-name rtd)
	      (record-type-parent rtd)
	      (record-type-uid rtd)
	      (record-type-generative? rtd)
	      (record-type-sealed? rtd)
	      (record-type-opaque? rtd)
	      (record-type-field-names rtd)))
    => '(#t make-rtd #f make-rtd-0 #f #f #f #()))

  (check	;;other correct configuration values
      (let ((rtd (make-record-type-descriptor (name:	'make-rtd)
					      (parent:	#f)
					      (uid:	#f)
					      (sealed:	#t)
					      (opaque:	#t)
					      (fields:	'#((mutable a) (immutable b))))))
	(list (record-type-descriptor? rtd)
	      (record-type-name rtd)
	      (record-type-parent rtd)
	      (gensym? (record-type-uid rtd))
	      (record-type-generative? rtd)
	      (record-type-sealed? rtd)
	      (record-type-opaque? rtd)
	      (record-type-field-names rtd)
	      (record-field-mutable? rtd 0)
	      (record-field-mutable? rtd 1)))
    => '(#t make-rtd #f #t #t #t #t #(a b) #t #f))

  (check	;;non-generative defined twice
      (let ((rtd1 (make-record-type-descriptor (name:	'make-rtd)
					       (parent:	#f)
					       (uid:	'make-rtd-1)
					       (sealed:	#f)
					       (opaque:	#f)
					       (fields:	'#())))
	    (rtd2 (make-record-type-descriptor (name:	'make-rtd)
					       (parent:	#f)
					       (uid:	'make-rtd-1)
					       (sealed:	#f)
					       (opaque:	#f)
					       (fields:	'#()))))
	(eq? rtd1 rtd2))
    => #t)

  (check	;;non-generative defined twice with different names
      (let ((name1	'make-rtd-one)
	    (name2	'make-rtd-two)
	    (parent	#f)
	    (uid	'make-rtd-2)
	    (sealed?	#f)
	    (opaque?	#f)
	    (fields	'#()))
	(let ((rtd1 (make-record-type-descriptor* name1 parent uid sealed? opaque? fields))
	      (rtd2 (make-record-type-descriptor* name2 parent uid sealed? opaque? fields)))
	  (eq? rtd1 rtd2)))
    => #t)

;;; --------------------------------------------------------------------
;;; errors, non-generative defined twice with different values

  (let ((rtd (make-record-type-descriptor* 'N parent-0 'make-rtd-3 #f #f '#())))
    ;;different parent
    (check-argument-violation
;;;                                             name parent uid sealed? opaque? fields
	(eq? rtd (make-record-type-descriptor* 'N #f 'make-rtd-3 #f #f '#()))
      => (list rtd (list 'N #f 'make-rtd-3 #f #f '#()))))

  (let ((rtd (make-record-type-descriptor* 'N #f 'make-rtd-4 #f #f '#())))
    (check-argument-violation	;;different parent
;;;                                             name parent uid sealed? opaque? fields
	(eq? rtd (make-record-type-descriptor* 'N parent-0 'make-rtd-4 #f #f '#()))
      => (list rtd (list 'N parent-0 'make-rtd-4 #f #f '#()))))

  (let ((rtd (make-record-type-descriptor* 'N #f 'make-rtd-5 #f #f '#())))
    (check-argument-violation	;;different sealed
;;;                                             name parent uid sealed? opaque? fields
	  (eq? rtd (make-record-type-descriptor* 'N #f 'make-rtd-5 #t #f '#()))
      => (list rtd (list 'N #f 'make-rtd-5 #t #f '#()))))

  (let ((rtd (make-record-type-descriptor* 'N #f 'make-rtd-6 #f #f '#())))
    (check-argument-violation ;;different opaque
;;;                                             name parent uid sealed? opaque? fields
	(eq? rtd (make-record-type-descriptor* 'N #f 'make-rtd-6 #f #t '#()))
      => (list rtd (list 'N #f 'make-rtd-6 #f #t '#()))))

  (let ((rtd (make-record-type-descriptor* 'N #f 'make-rtd-7 #f #f '#())))
    (check-argument-violation ;;different fields
;;;                                             name parent uid sealed? opaque? fields
	(eq? rtd (make-record-type-descriptor* 'N #f 'make-rtd-7 #f #f '#((mutable a))))
      => (list rtd (list 'N #f 'make-rtd-7 #f #f '#((mutable a))))))

  (let ((rtd (make-record-type-descriptor* 'N #f 'make-rtd-8 #f #f '#((mutable a)))))
    (check-argument-violation ;;different fields
;;;                                             name parent uid sealed? opaque? fields
	(eq? rtd (make-record-type-descriptor* 'N #f 'make-rtd-8 #f #f '#((immutable a))))
      => (list rtd (list 'N #f 'make-rtd-8 #f #f '#((immutable a))))))

  (let ((rtd (make-record-type-descriptor* 'N #f 'make-rtd-9 #f #f '#((immutable a)))))
    (check-argument-violation ;;different fields
;;;                                             name parent uid sealed? opaque? fields
	(eq? rtd (make-record-type-descriptor* 'N #f 'make-rtd-9 #f #f '#((immutable b))))
      => (list rtd (list 'N #f 'make-rtd-9 #f #f '#((immutable b))))))

;;; --------------------------------------------------------------------
;;; errors, wrong UID

  (check-argument-violation
      (make-record-type-descriptor
       (name: 'a-name) (parent: #f) (uid: "ciao")
       (sealed: #f) (opaque: #f) (fields: '#()))
    => "ciao")

  (check-argument-violation
      (make-record-type-descriptor
       (name: 'a-name) (parent: #f) (uid: #t)
       (sealed: #f) (opaque: #f) (fields: '#()))
    => #t)

;;; --------------------------------------------------------------------
;;; errors, wrong sealed

  (check-argument-violation
      (make-record-type-descriptor
       (name: 'a-name) (parent: #f) (uid: #f)
       (sealed: "ciao") (opaque: #f) (fields: '#()))
    => "ciao")

;;; --------------------------------------------------------------------
;;; errors, wrong opaque

  (check-argument-violation
      (make-record-type-descriptor
       (name: 'a-name) (parent: #f) (uid: #f)
       (sealed: #f) (opaque: "ciao") (fields: '#()))
    => "ciao")

;;; --------------------------------------------------------------------
;;; errors, wrong fields

  (check-argument-violation
      (make-record-type-descriptor
       (name: 'a-name) (parent: #f) (uid: #f)
       (sealed: #f) (opaque: #f) (fields: '()))
    => '())

  (check-argument-violation
      (make-record-type-descriptor
       (name: 'a-name) (parent: #f) (uid: #f)
       (sealed: #f) (opaque: #f) (fields: '#(a)))
    => '#(a))

  (check-argument-violation
      (make-record-type-descriptor
       (name: 'a-name) (parent: #f) (uid: #f)
       (sealed: #f) (opaque: #f) (fields: '#((a b c))))
    => '#((a b c)))

  (check-argument-violation
      (make-record-type-descriptor
       (name: 'a-name) (parent: #f) (uid: #f)
       (sealed: #f) (opaque: #f) (fields: '#((mutable 123))))
    => '#((mutable 123)))

  (check-argument-violation
      (make-record-type-descriptor
       (name: 'a-name) (parent: #f) (uid: #f)
       (sealed: #f) (opaque: #f) (fields: '#((ciao ciao))))
    => '#((ciao ciao)))

  (check-argument-violation
      (make-record-type-descriptor
       (name: 'a-name) (parent: #f) (uid: #f)
       (sealed: #f) (opaque: #f) (fields: '#((mutable a) (immutable 1))))
    => '#((mutable a) (immutable 1)))

  #t)


(parametrise ((check-test-name	'make-rcd))

;;; no parent

  (check	;;correct configuration values, no fields
      (let* ((rtd	(make-record-type-descriptor
			 (name: 'rtd-0) (parent: #f) (uid: #f)
			 (sealed: #f) (opaque: #f) (fields: '#())))
	     (rcd	(make-record-constructor-descriptor
			 (rtd: rtd) (parent-rcd: #f) (protocol: #f)))
	     (maker	(record-constructor rcd))
	     (pred	(record-predicate   rtd)))
	(pred (maker)))
    => #t)

  (check	;;correct configuration values, with fields
      (let* ((rtd	(make-record-type-descriptor
			 (name: 'rtd-0) (parent: #f) (uid: #f)
			 (sealed: #f) (opaque: #f)
			 (fields: '#((mutable a) (immutable b)))))
	     (rcd	(make-record-constructor-descriptor
			 (rtd: rtd) (parent-rcd: #f) (protocol: #f)))
	     (maker	(record-constructor rcd))
	     (pred	(record-predicate   rtd))
	     (get-a	(record-accessor rtd 0))
	     (get-b	(record-accessor rtd 1)))
	(let ((R (maker 1 2)))
	  (list (pred R)
		(get-a R)
		(get-b R))))
    => '(#t 1 2))

;;; --------------------------------------------------------------------
;;; with parent

  (check	;;correct configuration values, no fields
      (let* ((prtd	(make-record-type-descriptor
			 (name: 'parent) (parent: #f) (uid: #f)
			 (sealed: #f) (opaque: #f) (fields: '#())))
	     (rtd	(make-record-type-descriptor
			 (name: 'name) (parent: prtd) (uid: #f)
			 (sealed: #f) (opaque: #f) (fields: '#())))
	     (prcd	(make-record-constructor-descriptor
			 (rtd: prtd) (parent-rcd: #f) (protocol: #f)))
	     (rcd	(make-record-constructor-descriptor
			 (rtd: rtd) (parent-rcd: prcd) (protocol: #f)))
	     (maker	(record-constructor rcd))
	     (pred	(record-predicate   rtd)))
	(pred (maker)))
    => #t)

  (check	;;correct configuration values, with child fields
      (let* ((prtd	(make-record-type-descriptor
			 (name: 'parent) (parent: #f) (uid: #f)
			 (sealed: #f) (opaque: #f) (fields: '#())))
	     (rtd	(make-record-type-descriptor
			 (name: 'name) (parent: prtd) (uid: #f)
			 (sealed: #f) (opaque: #f)
			 (fields: '#((mutable a) (immutable b)))))
	     (prcd	(make-record-constructor-descriptor
			 (rtd: prtd) (parent-rcd: #f) (protocol: #f)))
	     (rcd	(make-record-constructor-descriptor
			 (rtd: rtd) (parent-rcd: prcd) (protocol: #f)))
	     (maker	(record-constructor rcd))
	     (pred	(record-predicate   rtd))
	     (get-a	(record-accessor    rtd 0))
	     (get-b	(record-accessor    rtd 1)))
	(let ((R (maker 1 2)))
	  (list (pred R)
		(get-a R)
		(get-b R))))
    => '(#t 1 2))

  (check	;;correct configuration values, with parent fields
      (let* ((prtd	(make-record-type-descriptor
			 (name: 'parent) (parent: #f) (uid: #f)
			 (sealed: #f) (opaque: #f)
			 (fields: '#((mutable a) (immutable b)))))
	     (rtd	(make-record-type-descriptor
			 (name: 'name) (parent: prtd) (uid: #f)
			 (sealed: #f) (opaque: #f)
			 (fields: '#())))
	     (prcd	(make-record-constructor-descriptor
			 (rtd: prtd) (parent-rcd: #f) (protocol: #f)))
	     (rcd	(make-record-constructor-descriptor
			 (rtd: rtd) (parent-rcd: prcd) (protocol: #f)))
	     (maker	(record-constructor rcd))
	     (pred	(record-predicate   rtd))
	     ;;parent accessors
	     (get-a	(record-accessor    prtd 0))
	     (get-b	(record-accessor    prtd 1)))
	(let ((R (maker 1 2)))
	  (list (pred R)
		(get-a R)
		(get-b R))))
    => '(#t 1 2))

  (check     ;correct configuration values, with parent and child fields
      (let* ((prtd	(make-record-type-descriptor
			 (name: 'parent) (parent: #f) (uid: #f)
			 (sealed: #f) (opaque: #f)
			 (fields: '#((mutable a) (immutable b)))))
	     (rtd	(make-record-type-descriptor
			 (name: 'name) (parent: prtd) (uid: #f)
			 (sealed: #f) (opaque: #f)
			 (fields: '#((mutable c) (immutable d)))))
	     (prcd	(make-record-constructor-descriptor
			 (rtd: prtd) (parent-rcd: #f) (protocol: #f)))
	     (rcd	(make-record-constructor-descriptor
			 (rtd: rtd) (parent-rcd: prcd) (protocol: #f)))
	     (maker	(record-constructor rcd))
	     (pred	(record-predicate   rtd))
	     ;;parent accessors
	     (get-a	(record-accessor    prtd 0))
	     (get-b	(record-accessor    prtd 1))
	     ;;child accessors
	     (get-c	(record-accessor    rtd 0))
	     (get-d	(record-accessor    rtd 1)))
	(let ((R (maker 1 2 3 4)))
	  (list (pred R)
		(get-a R)
		(get-b R)
		(get-c R)
		(get-d R))))
    => '(#t 1 2 3 4))

  (check ;correct configuration values, with "many" parent and child fields
      (let* ((prtd	(make-record-type-descriptor
			 (name: 'parent) (parent: #f) (uid: #f)
			 (sealed: #f) (opaque: #f)
			 (fields: '#((mutable a)
				     (immutable b)
				     (immutable c)
				     (immutable d)
				     (immutable e)
				     (immutable f)
				     (immutable g)))))
	     (rtd	(make-record-type-descriptor
			 (name: 'name) (parent: prtd) (uid: #f)
			 (sealed: #f) (opaque: #f)
			 (fields: '#((mutable h)
				     (immutable i)
				     (immutable l)
				     (immutable m)
				     (immutable n)
				     (immutable o)
				     (immutable p)
				     (immutable q)
				     (immutable r)))))
	     (prcd	(make-record-constructor-descriptor
			 (rtd: prtd) (parent-rcd: #f) (protocol: #f)))
	     (rcd	(make-record-constructor-descriptor
			 (rtd: rtd) (parent-rcd: prcd) (protocol: #f)))
	     (maker	(record-constructor rcd))
	     (pred	(record-predicate   rtd))
	     ;;parent accessors
	     (get-a	(record-accessor    prtd 0))
	     (get-b	(record-accessor    prtd 1))
	     (get-c	(record-accessor    prtd 2))
	     (get-d	(record-accessor    prtd 3))
	     (get-e	(record-accessor    prtd 4))
	     (get-f	(record-accessor    prtd 5))
	     (get-g	(record-accessor    prtd 6))
	     ;;child accessors
	     (get-h	(record-accessor    rtd 0))
	     (get-i	(record-accessor    rtd 1))
	     (get-l	(record-accessor    rtd 2))
	     (get-m	(record-accessor    rtd 3))
	     (get-n	(record-accessor    rtd 4))
	     (get-o	(record-accessor    rtd 5))
	     (get-p	(record-accessor    rtd 6))
	     (get-q	(record-accessor    rtd 7))
	     (get-r	(record-accessor    rtd 8)))
	(let ((R (maker 1 2 3  4 5 6  7 8 9  10 11 12  13 14 15  16)))
	  (list (pred R)
		(get-a R)	(get-b R)	(get-c R)
		(get-d R)	(get-e R)	(get-f R)
		(get-g R)	(get-h R)	(get-i R)
		(get-l R)	(get-m R)	(get-n R)
		(get-o R)	(get-p R)	(get-q R)
		(get-r R))))
    => '(#t 1 2 3  4 5 6  7 8 9  10 11 12  13 14 15  16))

;;; --------------------------------------------------------------------
;;; error, rtd argument

  (check-argument-violation
      ;;not an rtd
      (let* ((rtd	(make-record-type-descriptor
			 (name: 'rtd-0) (parent: #f) (uid: #f)
			 (sealed: #f) (opaque: #f) (fields: '#()))))
	(make-record-constructor-descriptor
	 (rtd: 123) (parent-rcd: #f) (protocol: #f)))
    => 123)

;;; --------------------------------------------------------------------
;;; error, rcd argument

  ;;not an rcd
  (check-argument-violation
      (let* ((prtd	(make-record-type-descriptor
			 (name: 'parent) (parent: #f) (uid: #f)
			 (sealed: #f) (opaque: #f) (fields: '#())))
	     (rtd	(make-record-type-descriptor
			 (name: 'name) (parent: prtd) (uid: #f)
			 (sealed: #f) (opaque: #f) (fields: '#()))))
	(make-record-constructor-descriptor
	 (rtd: rtd) (parent-rcd: 123) (protocol: #f)))
    => 123)

  (let* ((rtd-0	(make-record-type-descriptor
		 (name: 'rtd-0) (parent: #f) (uid: #f)
		 (sealed: #f) (opaque: #f) (fields: '#())))
	 (rtd-1	(make-record-type-descriptor
		 (name: 'rtd-1) (parent: #f) (uid: #f)
		 (sealed: #f) (opaque: #f) (fields: '#())))
	 (rcd-0	(make-record-constructor-descriptor
		 (rtd: rtd-0) (parent-rcd: #f) (protocol: #f))))
    (check-argument-violation ;;parent RCD for RTD without parent
	(make-record-constructor-descriptor
	 (rtd: rtd-1) (parent-rcd: rcd-0) (protocol: #f))
      => (list rtd-1 rcd-0)))

  (let* ((rtd-0	(make-record-type-descriptor
		 (name: 'rtd-0) (parent: #f) (uid: #f)
		 (sealed: #f) (opaque: #f) (fields: '#())))
	 (rtd-1	(make-record-type-descriptor
		 (name: 'rtd-1) (parent: #f) (uid: #f)
		 (sealed: #f) (opaque: #f) (fields: '#())))
	 (rtd-2	(make-record-type-descriptor
		 (name: 'rtd-1) (parent: rtd-1) (uid: #f)
		 (sealed: #f) (opaque: #f) (fields: '#())))
	 (rcd-0	(make-record-constructor-descriptor
		 (rtd: rtd-0) (parent-rcd: #f) (protocol: #f))))
    (check-argument-violation ;;parent RCD for wrong RTD
	(make-record-constructor-descriptor
	 (rtd: rtd-2) (parent-rcd: rcd-0) (protocol: #f))
      => (list rtd-2 rcd-0)))

;;; --------------------------------------------------------------------
;;; error, protocol argument

  (check-argument-violation ;;not a function
      (let* ((rtd	(make-record-type-descriptor
			 (name: 'rtd-0) (parent: #f) (uid: #f)
			 (sealed: #f) (opaque: #f) (fields: '#()))))
	(make-record-constructor-descriptor
	 (rtd: rtd) (parent-rcd: #f) (protocol: 123)))
    => 123)

  (let ((prot (lambda (a b)
		(list a b))))
    (check-argument-violation	;;protocol accepting wrong num of args
	(let* ((rtd	(make-record-type-descriptor
			 (name: 'rtd-0) (parent: #f) (uid: #f)
			 (sealed: #f) (opaque: #f) (fields: '#())))
	       (rcd	(make-record-constructor-descriptor
			 (rtd: rtd) (parent-rcd: #f) (protocol: prot)))
	       (maker	(record-constructor rcd)))
	  (maker))
      => (list prot 1)))

  (let* ((builder	(lambda (a b)
			  (list a b)))
	 (prot		(lambda (make-top)
			  builder)))
    (check-argument-violation ;;builder accepting wrong num of args
	(let* ((rtd	(make-record-type-descriptor
			 (name: 'rtd-0) (parent: #f) (uid: #f)
			 (sealed: #f) (opaque: #f) (fields: '#())))
	       (rcd	(make-record-constructor-descriptor
			 (rtd: rtd) (parent-rcd: #f) (protocol: prot)))
	       (builder	(record-constructor rcd)))
	  (builder))
      => (list builder 0)))

  (let ((prot (lambda (make-top)
		(add-result 1)
		(lambda ()
		  (make-top)))))
    (check-argument-violation	;;protocol function called only once
	(with-result
	  (let* ((rtd	(make-record-type-descriptor
			 (name: 'rtd-0) (parent: #f) (uid: #f)
			 (sealed: #f) (opaque: #f) (fields: '#())))
		 (rcd	(make-record-constructor-descriptor
			 (rtd: rtd) (parent-rcd: #f) (protocol: prot)))
		 (builder (record-constructor rcd)))
	    (builder)
	    (builder)
	    #t))
      => '(#t (1))))

  (let* ((flag 0)
	 (prot (lambda (make-top)
		 (add-result flag)
		 (set! flag (fx+ 1 flag))
		 (lambda ()
		   (make-top)))))
    (check-argument-violation ;;protocol function called only once
	(with-result
	  (let* ((rtd	(make-record-type-descriptor
			 (name: 'rtd-0) (parent: #f) (uid: #f)
			 (sealed: #f) (opaque: #f) (fields: '#())))
		 (rcd	(make-record-constructor-descriptor
			 (rtd: rtd) (parent-rcd: #f) (protocol: prot)))
		 (builder1 (record-constructor rcd))
		 (builder2 (record-constructor rcd)))
	    ((record-predicate rtd) (builder1))))
      => '(#t (0))))

  (let* ((builder	(lambda ()
			  (void)))
	 (prot		(lambda (make-top)
			  builder))
	 (rtd		(make-record-type-descriptor
			 (name: 'rtd-0) (parent: #f) (uid: #f)
			 (sealed: #f) (opaque: #f) (fields: '#()))))
    (check-argument-violation	;;builder returning void
	(let* ((rcd	(make-record-constructor-descriptor
			 (rtd: rtd) (parent-rcd: #f) (protocol: prot)))
	       (builder	(record-constructor rcd)))
	  (builder))
      => (list rtd (void))))

  (let* ((builder	(lambda ()
			  123))
	 (prot		(lambda (make-top)
			  builder))
	 (rtd		(make-record-type-descriptor
			 (name: 'rtd-0) (parent: #f) (uid: #f)
			 (sealed: #f) (opaque: #f) (fields: '#()))))
    (check-argument-violation	;;builder returning non-record
	(let* ((rcd		(make-record-constructor-descriptor
				 (rtd: rtd) (parent-rcd: #f) (protocol: prot)))
	       (builder	(record-constructor rcd)))
	  (builder))
      => (list rtd 123)))

  (check-argument-violation	;;protocol function calling maker directly
      (let* ((rtd	(make-record-type-descriptor
			 (name: 'rtd-0) (parent: #f) (uid: #f)
			 (sealed: #f) (opaque: #f) (fields: '#()))))
	(make-record-constructor-descriptor
	 (rtd: rtd) (parent-rcd: #f) (protocol: (lambda (maker) (maker)))))
    => '())

  #t)


(parametrise ((check-test-name	'record-accessor))

  (check	;;record accessor with index argument
      (let* ((rtd	(make-record-type-descriptor
			 (name: 'rtd-0) (parent: #f) (uid: #f)
			 (sealed: #f) (opaque: #f)
			 (fields: '#((mutable a) (mutable b)))))
	     (rcd	(make-record-constructor-descriptor
			 (rtd: rtd) (parent-rcd: #f) (protocol: #f)))
	     (builder	(record-constructor rcd))
	     (get-a	(record-accessor rtd 0))
	     (get-b	(record-accessor rtd 1)))
	(define R
	  (builder 1 2))
	(list (get-a R) (get-b R)))
    => '(1 2))

  (check	;;record accessor constructor with symbol argument
      (let* ((rtd	(make-record-type-descriptor
			 (name: 'rtd-0) (parent: #f) (uid: #f)
			 (sealed: #f) (opaque: #f)
			 (fields: '#((mutable a) (mutable b)))))
	     (rcd	(make-record-constructor-descriptor
			 (rtd: rtd) (parent-rcd: #f) (protocol: #f)))
	     (builder	(record-constructor rcd))
	     (get-a	(record-accessor rtd 'a))
	     (get-b	(record-accessor rtd 'b)))
	(define R
	  (builder 1 2))
	(list (get-a R) (get-b R)))
    => '(1 2))

;;; --------------------------------------------------------------------
;;; errors

  (check-argument-violation	;;negative field index
      (let ((rtd (make-record-type-descriptor
		  (name: 'rtd-0) (parent: #f) (uid: #f)
		  (sealed: #f) (opaque: #f)
		  (fields: '#((mutable a) (mutable b))))))
	(record-accessor rtd -1))
    => '(-1))

  (let ((rtd (make-record-type-descriptor
	      (name: 'rtd-0) (parent: #f) (uid: #f)
	      (sealed: #f) (opaque: #f)
	      (fields: '#((mutable a) (mutable b))))))
    (check-argument-violation ;;field index too big
	(record-accessor rtd 2)
      => (list rtd 2)))

  (let* ((rtd0 (make-record-type-descriptor
		(name: 'rtd-0) (parent: #f) (uid: #f)
		(sealed: #f) (opaque: #f)
		(fields: '#((mutable a) (mutable b)))))
	 (rtd1 (make-record-type-descriptor
		(name: 'rtd-1) (parent: rtd0) (uid: #f)
		(sealed: #f) (opaque: #f)
		(fields: '#((mutable c) (mutable d))))))
    (check-argument-violation ;;field index too big
	(record-accessor rtd1 2)
      => (list rtd1 2)))

  #t)


(parametrise ((check-test-name	'record-mutator))

  (check	;;mutator constructor with index argument
      (let* ((rtd	(make-record-type-descriptor
			 (name: 'rtd-0) (parent: #f) (uid: #f)
			 (sealed: #f) (opaque: #f)
			 (fields: '#((mutable a) (mutable b)))))
	     (rcd	(make-record-constructor-descriptor
			 (rtd: rtd) (parent-rcd: #f) (protocol: #f)))
	     (builder	(record-constructor rcd))
	     (get-a	(record-accessor rtd 0))
	     (set-a	(record-mutator  rtd 0))
	     (get-b	(record-accessor rtd 1))
	     (set-b	(record-mutator  rtd 1)))
	(let ((o (builder 1 2)))
	  (set-a o 19)
	  (set-b o 29)
	  (list (get-a o) (get-b o))))
    => '(19 29))

  (check	;;mutator constructor with symbol argument
      (let* ((rtd	(make-record-type-descriptor
			 (name: 'rtd-0) (parent: #f) (uid: #f)
			 (sealed: #f) (opaque: #f)
			 (fields: '#((mutable a) (mutable b)))))
	     (rcd	(make-record-constructor-descriptor
			 (rtd: rtd) (parent-rcd: #f) (protocol: #f)))
	     (builder	(record-constructor rcd))
	     (get-a	(record-accessor rtd 'a))
	     (set-a	(record-mutator  rtd 'a))
	     (get-b	(record-accessor rtd 'b))
	     (set-b	(record-mutator  rtd 'b)))
	(let ((o (builder 1 2)))
	  (set-a o 19)
	  (set-b o 29)
	  (list (get-a o) (get-b o))))
    => '(19 29))

;;; --------------------------------------------------------------------
;;; errors

  (check-argument-violation	;;negative field index
      (let ((rtd (make-record-type-descriptor
		  (name: 'rtd-0) (parent: #f) (uid: #f)
		  (sealed: #f) (opaque: #f)
		  (fields: '#((mutable a) (mutable b))))))
	(record-mutator rtd -1))
    => '(-1))

  (let ((rtd (make-record-type-descriptor
	      (name: 'rtd-0) (parent: #f) (uid: #f)
	      (sealed: #f) (opaque: #f)
	      (fields: '#((mutable a) (mutable b))))))
    (check-argument-violation	;;field index too big
	(record-mutator rtd 2)
      => (list rtd 2)))

  (let* ((rtd0 (make-record-type-descriptor
		(name: 'rtd-0) (parent: #f) (uid: #f)
		(sealed: #f) (opaque: #f)
		(fields: '#((mutable a) (mutable b)))))
	 (rtd1 (make-record-type-descriptor
		(name: 'rtd-1) (parent: rtd0) (uid: #f)
		(sealed: #f) (opaque: #f)
		(fields: '#((mutable c) (mutable d))))))
    (check-argument-violation	;;field index too big
	(record-mutator rtd1 2)
      => (list rtd1 2)))

  #t)


(parametrise ((check-test-name	'printer))

  (check
      (let* ((rtd	(make-record-type-descriptor
			 (name: 'rtd-0) (parent: #f) (uid: #f)
			 (sealed: #f) (opaque: #f) (fields: '#((mutable a) (mutable b)))))
	     (rcd	(make-record-constructor-descriptor
			 (rtd: rtd) (parent-rcd: #f) (protocol: #f)))
	     (builder	(record-constructor rcd)))
	(call-with-string-output-port
	    (lambda (port)
	      (display (builder 1 2) port)
	      )))
    => "#[record rtd-0 a=1 b=2]")

  #t)


(parametrise ((check-test-name	'reset))

  (check
      (let* ((rtd	(make-record-type-descriptor
			 (name: 'rtd-0) (parent: #f) (uid: #f)
			 (sealed: #f) (opaque: #f) (fields: '#((mutable a) (mutable b)))))
	     (rcd	(make-record-constructor-descriptor
			 (rtd: rtd) (parent-rcd: #f) (protocol: #f)))
	     (builder	(record-constructor rcd))
	     (get-a	(record-accessor rtd 0))
	     (get-b	(record-accessor rtd 1)))
	(let ((R (builder 1 2)))
	  (record-reset R)
	  (list (get-a R)
		(get-b R))))
    => `(,(void) ,(void)))

  #t)


(parametrise ((check-test-name	'record-and-rtd))

  (check
      (internal-body
	(define-record-type duo
	  (fields one two))
	(record-and-rtd? (make-duo 1 2) (record-type-descriptor duo)))
    => #t)

  (check
      (internal-body
	(define-record-type duo
	  (opaque #t)
	  (fields one two))
	(record-and-rtd? (make-duo 1 2) (record-type-descriptor duo)))
    => #t)

  #t)


;;;; done

(check-report)

;;; end of file
;;Local Variables:
;;coding: utf-8-unix
;;eval: (put 'check-argument-violation		'scheme-indent-function 1)
;;End:
