;;;
;;;Part of: Vicare Scheme
;;;Contents: helpers for OOPP
;;;Date: Tue May  1, 2012
;;;
;;;Abstract
;;;
;;;	This  library implements  helper  functions and  macros for  the
;;;	expand phase of the library (nausicaa language oopp).
;;;
;;;Copyright (C) 2012-2014 Marco Maggi <marco.maggi-ipsu@poste.it>
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


#!vicare
(library (nausicaa language oopp helpers)
  (export
    parse-label-definition		parse-class-definition
    parse-mixin-definition
    parse-tag-name-spec			filter-and-validate-mixins-clauses

    parse-with-tags-bindings
    parse-let-bindings			parse-let-values-bindings
    parse-formals-bindings		make-tagged-variable-transformer
    process-method-application		oopp-syntax-transformer

    tag-public-syntax-transformer	tag-private-common-syntax-transformer

    ;; helpers
    case-symbol				case-identifier
    single-identifier-subst		multi-identifier-subst

    ;; special identifier builders
    tag-id->record-type-id		tag-id->from-fields-constructor-id
    tag-id->constructor-id		tag-id->default-protocol-id
    tag-id->nongenerative-uid		tag-id->private-predicate-id
    tag-id->public-predicate-id		tag-id->list-of-uids-id

    ;; data types

    <parsed-spec>?
    <parsed-spec>-name-id		<parsed-spec>-member-identifiers
    <parsed-spec>-definitions		<parsed-spec>-public-constructor-id
    <parsed-spec>-public-predicate-id	<parsed-spec>-private-predicate-id
    <parsed-spec>-parent-id		<parsed-spec>-concrete-fields
    <parsed-spec>-virtual-fields	<parsed-spec>-methods-table
    <parsed-spec>-getter		<parsed-spec>-setter
    <parsed-spec>-abstract?		<parsed-spec>-sealed?
    <parsed-spec>-opaque?		<parsed-spec>-maker-transformer
    <parsed-spec>-finaliser-expression
    <parsed-spec>-shadowed-identifier
    <parsed-spec>-nongenerative-uid	<parsed-spec>-mutable-fields-data
    <parsed-spec>-immutable-fields-data	<parsed-spec>-concrete-fields-data
    <parsed-spec>-concrete-fields-names	<parsed-spec>-common-protocol
    <parsed-spec>-public-protocol	<parsed-spec>-super-protocol
    <parsed-spec>-satisfactions
    <parsed-spec>-accessor-transformer	<parsed-spec>-mutator-transformer

    <class-spec>?
    <class-spec>-record-type-id		<class-spec>-satisfaction-clauses

    <label-spec>?
    <label-spec>-satisfaction-clauses

    <mixin-spec>?
    <mixin-spec>-clauses

    <field-spec>?
    <field-spec>-name-id		<field-spec>-tag-id
    <field-spec>-accessor-id		<field-spec>-mutator-id

    <concrete-field-spec>?		<virtual-field-spec>?
    )
  (import (for (vicare) run expand)
    (for (only (rnrs)
	       lambda define define-syntax set!)
      (meta -1))
    (vicare unsafe operations)
    (vicare language-extensions identifier-substitutions)
    (prefix (only (nausicaa language oopp configuration)
		  validate-tagged-values?
		  enable-satisfactions)
	    config.)
    (for (nausicaa language oopp auxiliary-syntaxes)
      (meta -1))
    (for (only (nausicaa language oopp conditions)
	       tagged-binding-violation)
      (meta -1))
    (for (prefix (only (nausicaa language auxiliary-syntaxes)
		       parent		nongenerative
		       sealed		opaque
		       predicate	abstract
		       fields		virtual-fields
		       mutable		immutable
		       method		method-syntax		methods
		       protocol		public-protocol		super-protocol
		       getter		setter
		       shadows		satisfies
		       mixins
		       maker		finaliser
		       <>)
		 aux.)
      (meta -1)))


;;;; private helpers

(define-auxiliary-syntaxes
  parser-name
  clause-keyword
  next-who
  body
  flag-accessor)

(define (%false-or-identifier? obj)
  (or (not obj)
      (identifier? obj)))


;;;; public helpers

(define-syntax case-symbol
  ;;Like  CASE defined  by R6RS,  but specialised  to branch  on symbols
  ;;using EQ?.
  ;;
  (syntax-rules (else)
    ((_ ?expr
	((?symbol0 ?symbol ...)
	 ?sym-body0 ?sym-body ...)
	...
	(else
	 ?else-body0 ?else-body ...))
     (let ((sym ?expr))
       (cond ((or (eq? sym '?symbol0)
		  (eq? sym '?symbol)
		  ...)
	      ?sym-body0 ?sym-body ...)
	     ...
	     (else
	      ?else-body0 ?else-body ...))))
    ((_ ?expr
	((?symbol0 ?symbol ...)
	 ?sym-body0 ?sym-body ...)
	...)
     (let ((sym ?expr))
       (cond ((or (eq? sym '?symbol0)
		  (eq? sym '?symbol)
		  ...)
	      ?sym-body0 ?sym-body ...)
	     ...)))
    ))

(define-syntax case-identifier
  ;;Like CASE defined by R6RS,  but specialised to branch on identifiers
  ;;using FREE-IDENTIIFER=?.
  ;;
  (syntax-rules (else)
    ((_ ?expr
	((?id0 ?id ...)
	 ?id-body0 ?id-body ...)
	...
	(else
	 ?else-body0 ?else-body ...))
     (let ((sym ?expr))
       (cond ((or (free-identifier=? sym #'?id0)
		  (free-identifier=? sym #'?id)
		  ...)
	      ?id-body0 ?id-body ...)
	     ...
	     (else
	      ?else-body0 ?else-body ...))))
    ((_ ?expr
	((?id0 ?id ...)
	 ?id-body0 ?id-body ...)
	...)
     (let ((sym ?expr))
       (cond ((or (free-identifier=? sym #'?id0)
		  (free-identifier=? sym #'?id)
		  ...)
	      ?id-body0 ?id-body ...)
	     ...)))
    ))


;;;; public helpers: visible identifiers composition

(define (make-method-identifier tag-id method-id)
  (identifier-append tag-id
		     (identifier->string tag-id)
		     "-"
		     (identifier->string method-id)))

;;; --------------------------------------------------------------------

(define-inline (tag-id->record-type-id id)
  (identifier-suffix id "-record-type"))

(define-inline (tag-id->nongenerative-uid id)
  id)

;;; --------------------------------------------------------------------

(define-inline (tag-id->from-fields-constructor-id id)
  (identifier-prefix "make-from-fields-" id))

(define-inline (tag-id->constructor-id id)
  (identifier-prefix "make-" id))

(define-inline (tag-id->common-rcd-id id)
  (identifier-suffix id "-common-rcd"))

(define-inline (tag-id->common-constructor-id id)
  (identifier-prefix "make-" id))

;;; --------------------------------------------------------------------

(define-inline (tag-id->superclass-rcd-id id)
  (identifier-suffix id "-superclass-rcd"))

;;; --------------------------------------------------------------------

(define-inline (tag-id->custom-maker-rcd-id id)
  (identifier-suffix id "-custom-maker-rcd"))

(define-inline (tag-id->custom-maker-constructor-id id)
  (identifier-prefix "make-" id))

(define-inline (tag-id->default-protocol-id id)
  (identifier-suffix id "-default-protocol"))

;;; --------------------------------------------------------------------

(define-inline (tag-id->private-predicate-id id)
  (identifier-suffix id "-private-predicate"))

(define-inline (tag-id->public-predicate-id id)
  (identifier-suffix id "?"))

;;; --------------------------------------------------------------------

(define-inline (tag-id->list-of-uids-id id)
  (identifier-suffix id "-list-of-uids"))


(define (tag-private-common-syntax-transformer stx the-public-constructor the-public-predicate the-list-of-uids
					       the-getter the-setter kont)
  ;;Transformer function  for the  private syntaxes available  through a
  ;;tag identifier,  only the ones  common for both labels  and classes.
  ;;STX is a syntax object representing the use of a tag identifier.
  ;;
  ;;KONT is  a continuation thunk to  be invoked if none  of the clauses
  ;;defined here match.
  ;;
  ;;Notice that  "<procedure>" and "<top>" define  some special variants
  ;;of these syntaxes; such variants are matched before this function is
  ;;called.
  ;;
  (syntax-case stx ( ;;
		    :define :make :is-a? :list-of-unique-ids :predicate-function
		    :setter :getter
		    :assert-type-and-return :assert-procedure-argument
		    :assert-expression-return-value)

    ;;Define  internal   bindings  for   a  tagged   variable.   Without
    ;;initialisation expression.
    ((?tag :define ?var)
     (identifier? #'?var)
     #'(begin
	 (define src-var)
	 (define-syntax ?var
	   (make-tagged-variable-transformer #'?tag #'src-var))))

    ;;Define   internal   bindings   for  a   tagged   variable.    With
    ;;initialisation expression.
    ((?tag :define ?var ?expr)
     (identifier? #'?var)
     #'(begin
	 (define src-var (?tag :assert-type-and-return ?expr))
	 (define-syntax ?var
	   (make-tagged-variable-transformer #'?tag #'src-var))))

    ((_ :make . ??args)
     #`(#,the-public-constructor . ??args))

    ((_ :is-a? . ??args)
     #`(#,the-public-predicate . ??args))

    ((_ :list-of-unique-ids)
     the-list-of-uids)

    ((_ :predicate-function)
     the-public-predicate)

    ((_ :getter (?expr ((?key0 ...) (?key ...) ...)))
     (the-getter #'(?expr ((?key0 ...) (?key  ...) ...))))

    ((_ :setter (?expr ((?key0 ...) (?key ...) ...) ?value))
     (the-setter #'(?expr ((?key0 ...) (?key ...) ...) ?value)))

    ((?tag :assert-type-and-return ?expr)
     (if config.validate-tagged-values?
	 #'(receive-and-return (val)
	       ?expr
	     (unless (?tag :is-a? val)
	       (tagged-binding-violation '?tag
		 (string-append "invalid expression result, expected value of type "
				(symbol->string '?tag))
		 '(expression: ?expr)
		 `(result: ,val))))
       #'?expr))

    ((?tag :assert-procedure-argument ?id)
     (identifier? #'?id)
     ;;This DOES NOT return the value.
     (if config.validate-tagged-values?
	 #'(unless (?tag :is-a? ?id)
	     (procedure-argument-violation '?tag
	       "tagged procedure argument of invalid type" ?id))
       #'(void)))

    ((?tag :assert-expression-return-value ?expr)
     ;;This DOES return the value.
     (if config.validate-tagged-values?
	 #'(receive-and-return (val)
	       ?expr
	     (unless (?tag :is-a? val)
	       (expression-return-value-violation '?tag
		 "tagged expression return value of invalid type" val)))
       #'?expr))

    (_
     (kont))))


(define (tag-public-syntax-transformer stx the-maker set-tags-id synner)
  ;;Transformer function for the public syntaxes available through a tag
  ;;identifier.  STX  is a syntax object  representing the use of  a tag
  ;;identifier.
  ;;
  ;;THE-MAKER is  the maker  transformer function or  false if  no maker
  ;;transformer was defined.
  ;;
  ;;SET-TAGS-ID must be the keyword  identifier of the syntax SET!/TAGS.
  ;;It is used to process the syntax with keyword #:oopp-syntax.
  ;;
  ;;Notice that  "<procedure>" and "<top>" define  some special variants
  ;;of these syntaxes; such variants are matched before this function is
  ;;called.
  ;;
  (syntax-case stx (:make :define :flat-oopp-syntax aux.<>)

    ;;NOTE Put the clauses with literals and keyword objects first!!!

    ;;OOPP syntax for arbitrary expression.
    ;;
    ((?tag #:oopp-syntax (?expr ?arg ...))
     (oopp-syntax-transformer #'?tag #'(?expr ?arg ...) set-tags-id synner))

    ;;OOPP syntax for arbitrary expression spliced when first subform.
    ;;
    ((?tag #:nested-oopp-syntax ?expr)
     #'(splice-first-expand (?tag :flat-oopp-syntax ?expr)))

    ;;Clauses to process spliced OOPP syntax forms.  These rules must be
    ;;invoked only by the expansion of:
    ;;
    ;;   (?tag #:nested-oopp-syntax ?expr)
    ;;
    ;;if it  appears as  first subform  and there  are arguments  in the
    ;;enclosing form, we want the expansion:
    ;;
    ;;   ((?tag #:nested-oopp-syntax ?expr) ?arg ...)
    ;;   ==> (?tag #:oopp-syntax (?expr ?arg ...))
    ;;
    ;;otherwise we want the expansion:
    ;;
    ;;   (begin (?tag #:nested-oopp-syntax ?expr))
    ;;   ==> (begin ?expr)
    ;;
    ((?tag :flat-oopp-syntax ?expr)
     #'?expr)
    ((?tag :flat-oopp-syntax ?expr ?arg ...)
     #'(?tag #:oopp-syntax (?expr ?arg ...)))

    ;;Predicate application.
    ;;
    ((?tag #:is-a? ?expr)
     #'(?tag :is-a? ?expr))

    ;;Reference to predicate function.
    ;;
    ((?tag #:predicate)
     #'(?tag :predicate-function))

    ;; ------------------------------------------------------------

    ;;Define an  internal variable with initialisation  expression using
    ;;the tag constructor.
    ((?tag ?var (aux.<> (?arg ...)))
     (identifier? #'?var)
     #'(?tag ?var (?tag (?arg ...))))

    ;;Internal definition with initialisation expression.
    ((?tag ?var ?expr)
     (identifier? #'?var)
     #'(?tag :define ?var ?expr))

    ;;Internal definition without initialisation expression.
    ((?tag ?var)
     (identifier? #'?var)
     #'(?tag :define ?var))

    ;;Constructor call.   If a  maker transformer  was defined:  use it,
    ;;otherwise default to the public constructor.
    ((?tag (?arg ...))
     #`(?tag #:nested-oopp-syntax #,(if the-maker
					(the-maker stx)
				      #'(?tag :make ?arg ...))))

    ;;Cast operator.  It is meant to be used as:
    ;;
    ;;  ((?tag) '#())
    ;;  ==> ((splice-first-expand (?tag #:nested-oopp-syntax)) '#())
    ;;  ==> (?tag #:nested-oopp-syntax '#())
    ;;
    ((?tag)
     #'(splice-first-expand (?tag #:nested-oopp-syntax)))

    (_
     (synner "invalid tag syntax" #f))))


(define* (make-tagged-variable-transformer (tag-id identifier?) (src-var-id identifier?))
  ;;Build  and   return  the   transformer  function   implementing  the
  ;;identifier syntax  for tagged  variables.  When  we define  a tagged
  ;;variable with:
  ;;
  ;;   (<integer> a 123)
  ;;
  ;;we can imagine the following expansion:
  ;;
  ;;   (define src-var 123)
  ;;   (define-syntax a
  ;;     (make-tagged-variable-transformer #'<integer> #'src-var))
  ;;
  ;;and when we define a tagged variable with:
  ;;
  ;;   (let/tags (((a <integer>) 123)) ---)
  ;;
  ;;we can imagine the following expansion:
  ;;
  ;;   (let ((src-var 123))
  ;;     (let-syntax
  ;;         ((a (make-tagged-variable-transformer
  ;;               #'<integer> #'src-var)))
  ;;       ---))
  ;;
  ;;TAG-ID must be the identifier  bound to the tag syntax (defined with
  ;;DEFINE-LABEL or DEFINE-CLASS).
  ;;
  ;;SRC-VAR-ID must be  the identifier to which the  value of the tagged
  ;;variable is bound.
  ;;
  (make-variable-transformer
   (lambda (stx)
     (syntax-case stx (set!)

       ;;Syntax to reference the value of the binding.
       (?var
	(identifier? #'?var)
	src-var-id)

       ;;Syntax to mutate the value of the binding.
       ((set! ?var ?val)
	#`(set! #,src-var-id (#,tag-id :assert-type-and-return ?val)))

       (?form
	#`(#,tag-id #:oopp-syntax ?form))

       (_
	(syntax-violation (syntax->datum tag-id)
	  "invalid tagged-variable syntax use" stx))))))

(define (oopp-syntax-transformer tag-id form-stx set-bang-id synner)
  ;;This function is  called to expand the usage of  OOPP syntax, either
  ;;through a tagged variable:
  ;;
  ;;  (?tag ?id ?expr)
  ;;  (?id ?arg ...) ;OOPP syntax
  ;;
  ;;or directly by using the #:oopp-syntax keyword:
  ;;
  ;;  (?tag #:oopp-syntax (?expr ?arg ...))
  ;;
  ;;Notice setter syntaxes are supported, too.
  ;;
  (syntax-case form-stx (:mutator :setter)

    ;;Setter syntax.   Main syntax to invoke  the setter for the  tag of
    ;;?VAR;  it  supports  multiple  sets  of  keys  for  nested  setter
    ;;invocations.
    ((?set (?expr (?key0 ...) (?key ...) ...) ?value)
     (and (identifier? #'?set)
	  (free-identifier=? #'?set set-bang-id))
     #`(#,tag-id :setter (?expr ((?key0 ...) (?key ...) ...) ?value)))

    ;;Setter syntax.   Alternative syntax to  invoke the setter  for the
    ;;tag of ?EXPR; it supports multiple  sets of keys for nested setter
    ;;invocations.
    ((?set ?expr (?key0 ...) (?key ...) ... ?value)
     (and (identifier? #'?set)
	  (free-identifier=? #'?set set-bang-id))
     #`(#,tag-id :setter (?expr ((?key0 ...) (?key ...) ...) ?value)))

    ;;Setter syntax.  Syntax to invoke the  field mutator for the tag of
    ;;?EXPR.  Notice that  this may also be a  nested setter invocation,
    ;;as in:
    ;;
    ;;   (set!/tags (O a b c[777]) 999)
    ;;
    ;;for this reason we do not validate ?ARG in any way.
    ;;
    ((?set (?expr ?field-name ?arg ...) ?val)
     (and (identifier? #'?set)
	  (free-identifier=? #'?set set-bang-id))
     #`(#,tag-id :mutator ?expr (?field-name ?arg ...) ?val))

    ;;Syntax to apply the field mutator for the tag of ?EXPR.
    ((?expr :mutator (?field-name ?arg ...) ?value)
     (identifier? #'?field-name)
     #`(#,tag-id :mutator ?expr (?field-name ?arg ...) ?value))

    ;;Syntax to apply the setter for the tag of ?EXPR.
    ((?expr :setter ((?key ...) ...) ?value)
     #`(#,tag-id :setter (?expr ((?key ...) ...) ?value)))

    ;;Syntax to  apply the getter for  the tag of ?EXPR.   A plain getter
    ;;syntax is as follows:
    ;;
    ;;  (?expr (?key0 ...) (?key ...) ...)
    ;;
    ;;where "<tag>"  is the  tag assigned to  the getter  runtime return
    ;;value from the getter transformer function.
    ;;
    ((?expr (?key0 ...) (?key ...) ...)
     #`(#,tag-id :getter (?expr ((?key0 ...) (?key ...) ...))))

    ;;Syntax to apply a method or reference a field of the tag of ?EXPR.
    ((?expr . ?stuff)
     #`(#,tag-id :dispatch (?expr . ?stuff)))

    (_
     (synner "invalid OOPP syntax" form-stx))))


(define (process-method-application rv-tag-id application-stx)
  ;;Process a  tag's method application  to support spliced  OOPP syntax
  ;;using the tag of a method's single return value.
  ;;
  ;;RV-TAG-ID must  be false to  indicate a method with  untagged return
  ;;value or a  method with multiple return values; RV-TAG-ID  must be a
  ;;tag identifier to indicate a method  with a single and tagged return
  ;;value.
  ;;
  ;;APPLICATION-STX  must be  a  syntax object  representing the  method
  ;;application.
  ;;
  ;;When there  is no  return-value tag or  the method  returns multiple
  ;;values: RV-TAG-ID is false and we just return the application syntax
  ;;object.
  ;;
  ;;When the method  has a single tagged return value:  we want to allow
  ;;OOPP syntax  for the returned  value.  For example, knowing  the the
  ;;method SUBVECTOR of "<vector>" has return value with tag "<vector>":
  ;;
  ;;  (<vector> V '#(0 1 2 3))
  ;;
  ;;  (V subvector 0 2) => #(0 1)	;plain method application
  ;;  ((V subvector 0 2) length) => 2	;return value OOPP syntax
  ;;
  ;;we want the expansion:
  ;;
  ;;  (V subvector 0 2)
  ;;  ==> (<vector> #:nested-oopp-syntax (subvector V 0 1)))
  ;;  ==> (splice-first-expand
  ;;       (<vector> :flat-oopp-syntax (subvector V 0 1)))
  ;;
  ;;so that  if the  application is  the first  subform of  an enclosing
  ;;subform and there are arguments, the full expansion is:
  ;;
  ;;  ((V subvector 0 2) length)
  ;;  ==> ((<vector> #:nested-oopp-syntax (subvector V 0 1)) length)
  ;;  ==> ((splice-first-expand
  ;;        (<vector> :flat-oopp-syntax (subvector V 0 1))) length)
  ;;  ==> (<vector> :flat-oopp-syntax (subvector V 0 1) length)
  ;;  ==> (<vector> #:oopp-syntax ((subvector V 0 1) length))
  ;;  ==> (vector-length (subvector V 0 1))
  ;;
  ;;otherwise the expansion is just:
  ;;
  ;;  (begin (V subvector 0 2))
  ;;  ==> (begin
  ;;       (<vector> #:nested-oopp-syntax (subvector V 0 1)))
  ;;  ==> (begin
  ;;       (splice-first-expand
  ;;        (<vector> :flat-oopp-syntax (subvector V 0 1))))
  ;;  ==> (begin
  ;;       (<vector> :flat-oopp-syntax (subvector V 0 1)))
  ;;  ==> (begin (subvector V 0 1))
  ;;
  ;; (debug-print 'process-method-application
  ;; 	       'return-value-tag (syntax->datum rv-tag-id)
  ;; 	       'method-call (syntax->datum (if (syntax->datum rv-tag-id)
  ;; 					       #`(#,rv-tag-id #:nested-oopp-syntax #,application-stx)
  ;; 					     application-stx)))
  (if (syntax->datum rv-tag-id)
      #`(#,rv-tag-id #:nested-oopp-syntax #,application-stx)
    application-stx))


(case-define parse-with-tags-bindings
  ((bindings-stx synner)
   (parse-with-tags-bindings bindings-stx synner '() '() '()))
  ((bindings-stx synner vars tags syntax-bindings)
   ;;Recursive function.  Parse the syntax object BINDINGS-STX expecting
   ;;it to  be a list  of tagged WITH-TAGS bindings;  supported syntaxes
   ;;for the bindings are:
   ;;
   ;;   ()
   ;;   (?var0 ?var ...)
   ;;
   ;;where each ?VAR must have the following syntax:
   ;;
   ;;   (?var-id ?tag-id)
   ;;   #(?var-id ?tag-id)
   ;;
   ;;The return value is a syntax object with the structure:
   ;;
   ;;   ((VAR ...) (TAG ...) (SYNTAX-BINDING ...))
   ;;
   ;;where each  VAR is an  identifier to be  used to create  a binding,
   ;;each TAG is the identifier of  the type tag and each SYNTAX-BINDING
   ;;is the associated LET-SYNTAX binding.
   ;;
   ;;SYNNER must be a closure to be used to raise syntax violations.
   ;;
   (syntax-case bindings-stx ()
     ;;No more bindings.
     (()
      (list (reverse vars) (reverse tags) (reverse syntax-bindings)))

     ;;Tagged binding, parentheses envelope.
     (((?var ?tag) . ?other-bindings)
      (and (identifier? #'?var)
	   (identifier? #'?tag))
      (let ((tag-id #'?tag))
	(parse-with-tags-bindings #'?other-bindings synner
				  (cons #'?var vars)
				  (cons tag-id tags)
				  (cons #'(?var (make-tagged-variable-transformer #'?tag #'?var))
					syntax-bindings))))

     ;;Tagged binding, vector envelope.
     ((#(?var ?tag) . ?other-bindings)
      (and (identifier? #'?var)
	   (identifier? #'?tag))
      (let ((tag-id #'?tag))
	(parse-with-tags-bindings #'?other-bindings synner
				  (cons #'?var vars)
				  (cons tag-id tags)
				  (cons #'(?var (make-tagged-variable-transformer #'?tag #'?var))
					syntax-bindings))))

     ;;Syntax error.
     (_
      (synner "invalid bindings syntax" bindings-stx)))))

(case-define parse-let-bindings
  ((bindings-stx top-id synner)
   (parse-let-bindings bindings-stx top-id synner '() '() '()))
  ((bindings-stx top-id synner vars tags syntax-bindings)
   ;;Recursive function.  Parse the syntax object BINDINGS-STX expecting
   ;;it to be a list of  tagged LET bindings; supported syntaxes for the
   ;;bindings are:
   ;;
   ;;   ()
   ;;   (?var0 ?var ...)
   ;;
   ;;where each ?VAR must have one of the following syntaxes:
   ;;
   ;;   ?var-id
   ;;   (?var-id)
   ;;   (?var-id ?tag-id)
   ;;   #(?var-id ?tag-id)
   ;;
   ;;The return value is a syntax object with the structure:
   ;;
   ;;   ((VAR ...) (TAG ...) (SYNTAX-BINDING ...))
   ;;
   ;;where each  VAR is an  identifier to be  used to create  a binding,
   ;;each TAG is the identifier of  the type tag and each SYNTAX-BINDING
   ;;is the associated LET-SYNTAX binding.  If a variable is tagged with
   ;;TOP-ID: no syntax binding is generated.
   ;;
   ;;When the BINDINGS-STX comes from  a LET, the returned syntax object
   ;;should be used to compose an output form as:
   ;;
   ;;   #'(let ((VAR (TAG :assert-type-and-return ?init)) ...)
   ;;       (let-syntax (SYNTAX-BINDING ...)
   ;;         ?body0 ?body ...))
   ;;
   ;;TOP-ID must the  the identifier bound to the "<top>"  tag; this tag
   ;;is used as default when no tag is given for a binding.  SYNNER must
   ;;be a closure to be used to raise syntax violations.
   ;;
   (syntax-case bindings-stx ()
     ;;No more bindings.
     (()
      (list (reverse vars) (reverse tags) (reverse syntax-bindings)))

     ;;Tagged binding, parentheses envelope.
     (((?var ?tag) . ?other-bindings)
      (and (identifier? #'?var)
	   (identifier? #'?tag))
      (let ((tag-id #'?tag))
	(parse-let-bindings #'?other-bindings top-id synner
			    (cons #'?var vars)
			    (cons tag-id tags)
			    (if (free-identifier=? tag-id top-id)
				syntax-bindings
			      (cons #'(?var (make-tagged-variable-transformer #'?tag #'?var))
				    syntax-bindings)))))

     ;;Tagged binding, vector envelope.
     ((#(?var ?tag) . ?other-bindings)
      (and (identifier? #'?var)
	   (identifier? #'?tag))
      (let ((tag-id #'?tag))
	(parse-let-bindings #'?other-bindings top-id synner
			    (cons #'?var vars)
			    (cons tag-id tags)
			    (if (free-identifier=? tag-id top-id)
				syntax-bindings
			      (cons #'(?var (make-tagged-variable-transformer #'?tag #'?var))
				    syntax-bindings)))))

     ;;Non-tagged binding.
     ((?var . ?other-bindings)
      (identifier? #'?var)
      (parse-let-bindings #'?other-bindings top-id synner
			  (cons #'?var vars)
			  (cons top-id tags)
			  syntax-bindings))

     ;;Special case of non-tagged binding in parens.
     ;;
     ;;FIXME Why are we supporting this?  Is there some special case I do
     ;;not rememeber?  (Marco Maggi; Thu Jul 18, 2013)
     (((?var) . ?other-bindings)
      (identifier? #'?var)
      (parse-let-bindings #'?other-bindings top-id synner
			  (cons #'?var vars)
			  (cons top-id tags)
			  syntax-bindings))

     ;;Syntax error.
     (_
      (synner "invalid bindings syntax" bindings-stx)))))

(case-define parse-let-values-bindings
  ((bindings-stx top-id synner)
   (parse-let-values-bindings bindings-stx top-id synner '() '()))
  ((bindings-stx top-id synner values-vars syntax-bindings)
   ;;Recursive function.  Parse the syntax object BINDINGS-STX expecting
   ;;it to be  a list of tagged LET-VALUES  bindings; supported syntaxes
   ;;for the bindings are:
   ;;
   ;;   ()
   ;;   (?vars0 ?vars ...)
   ;;
   ;;where each ?VARS must have the syntax of the tagged LAMBDA formals:
   ;;
   ;;   (?var0 ?var ...)
   ;;   (?var0 ?var ... . ?rest)
   ;;   ?var-id
   ;;
   ;;and each ?VAR must have one of the following syntaxes:
   ;;
   ;;   ?var-id
   ;;   (?var-id)
   ;;   (?var-id ?tag-id)
   ;;   #(?var-id ?tag-id)
   ;;
   ;;The return value is a syntax object with the structure:
   ;;
   ;;   ((VARS ...) (SYNTAX-BINDING ...))
   ;;
   ;;where  each VARS  is a  list of  identifiers to  be used  to create
   ;;bindings  and  the  SYNTAX-BINDING are  the  associated  LET-SYNTAX
   ;;bindings.  If a  variable is tagged with TOP-ID:  no syntax binding
   ;;is generated.
   ;;
   ;;When the BINDINGS-STX comes from  a LET-VALUES, the returned syntax
   ;;object should be used to compose an output form as:
   ;;
   ;;   #'(let-values ((VARS ?init) ...)
   ;;       (let-syntax (SYNTAX-BINDING ...)
   ;;         ?body0 ?body ...))
   ;;
   ;;TOP-ID must the  the identifier bound to the "<top>"  tag; this tag
   ;;is used as default when no tag is given for a binding.  SYNNER must
   ;;be a closure to be used to raise syntax violations.
   ;;
   (define-inline (%final stx)
     (reverse (syntax->list stx)))
   (syntax-case bindings-stx ()
     (()
      (list (%final values-vars) (%final syntax-bindings)))

     ((?vars . ?other-bindings)
      (with-syntax
	  (((FORMALS VALIDATIONS (SYNTAX-BINDING ...))
	    (parse-formals-bindings #'?vars top-id synner)))
	(parse-let-values-bindings #'?other-bindings top-id synner
				   #`(FORMALS . #,values-vars)
				   #`(SYNTAX-BINDING ... . #,syntax-bindings))))

     (_
      (synner "invalid bindings syntax" bindings-stx)))))

(define (parse-formals-bindings formals-stx top-id synner)
  ;;Parse the  syntax object  FORMALS-STX expecting it  to be a  list of
  ;;tagged LAMBDA formals; supported syntaxes for the formals are:
  ;;
  ;;   ()
  ;;   ?args-id
  ;;   #(?args-id ?tag-id)
  ;;   (?var0 ?var ...)
  ;;   (?var0 ?var ... . ?rest)
  ;;
  ;;where  ?ARGS-ID is an  identifier, each  ?VAR must  have one  of the
  ;;following syntaxes:
  ;;
  ;;   ?var-id
  ;;   (?var-id)
  ;;   (?var-id ?tag-id)
  ;;   #(?var-id ?tag-id)
  ;;
  ;;and ?REST must have one of the following syntaxes:
  ;;
  ;;   ?rest-id
  ;;   #(?rest-id ?tag-id)
  ;;
  ;;notice  that  tagging  for  ?ARGS-ID  is not  supported  because  no
  ;;suitable syntax is possible.
  ;;
  ;;The return value is a syntax object with the structure:
  ;;
  ;;   (FORMALS (VALIDATION ...) (SYNTAX-BINDING ...))
  ;;
  ;;the FORMALS  component represents a  valid list of  formal arguments
  ;;for  a LAMBDA  syntax;  each VALIDATION  component  is a  validation
  ;;clause; each SYNTAX-BINDING component represents a valid binding for
  ;;LET-SYNTAX.  If a variable is  tagged with TOP-ID: no syntax binding
  ;;is generated.
  ;;
  ;;When the FORMALS-STX comes from a LAMBDA, the returned syntax object
  ;;should be used to compose an output form as:
  ;;
  ;;   #'(lambda FORMALS (let-syntax (SYNTAX-BINDING ...) ?body0 ?body ...))
  ;;
  ;;When  the  FORMALS-STX  comes  from  a clause  of  CASE-LAMBDA,  the
  ;;returned syntax object should be used to compose an output form as:
  ;;
  ;;   #'(case-lambda
  ;;      (FORMALS (let-syntax (SYNTAX-BINDING ...) ?body0 ?body ...))
  ;;      ...)
  ;;
  ;;TOP-ID must  the the  identifier bound to  the "<top>"  tag.  SYNNER
  ;;must be a closure to be used to raise syntax violations.
  ;;
  (syntax-case formals-stx ()
    ;;No arguments.
    (()
     #'(() () ()))

    ;;List of all the arguments, with tag.
    (#(?args-id ?tag-id)
     (and (identifier? #'?args-id)
	  (identifier? #'?tag-id))
     (with-syntax ((((VAR) (TAG) (BINDING))
		    (parse-let-bindings #'((?args-id ?tag-id)) top-id synner)))
       #'(VAR ((TAG VAR)) (BINDING))))

    ;;List of all the arguments, no tag.
    (?args-id
     (identifier? #'?args-id)
     #'(?args-id () ()))

    ;;Fixed number of arguments.
    ((?var ...)
     (with-syntax ((((VAR ...) (TAG ...) (BINDING ...))
		    (parse-let-bindings #'(?var ...) top-id synner)))
       #'((VAR ...) ((TAG VAR) ...) (BINDING ...))))

    ;;Mandatory arguments plus untagged rest argument.
    ((?var0 ?var ... . ?rest)
     (identifier? #'?rest)
     (with-syntax ((((REST-VAR VAR ...) (REST-TAG TAG ...) (BINDING ...))
		    (parse-let-bindings #'(?rest ?var0 ?var ...) top-id synner)))
       #'((VAR ... . REST-VAR) ((TAG VAR) ...) (BINDING ...))))

    ;;Mandatory arguments plus tagged rest argument.
    ((?var0 ?var ... . #(?rest-id ?tag-id))
     (and (identifier? #'?rest)
	  (identifier? #'?tag-id))
     (with-syntax ((((REST-VAR VAR ...) (REST-TAG TAG ...) (BINDING ...))
		    (parse-let-bindings #'(#(?rest-id ?tag-id) ?var0 ?var ...) top-id synner)))
       #'((VAR ... . REST-VAR) ((TAG VAR) ... (REST-TAG REST-VAR)) (BINDING ...))))

    ))


;;;; data types: parsed clauses representation

;;This record type represents the parsing results of all the clauses for
;;all the tag definitions.  Some clauses  apply only to classes and some
;;clauses apply  only to  labels, but  we do not  represent them  in the
;;class and label specification record type: the mixins must support all
;;the clauses, so  to use this record  type as base for  the mixin type:
;;all the parsing results go here for simplicity.
;;
(define-record-type <parsed-spec>
  (nongenerative nausicaa:language:oopp:<parsed-spec>)
  (protocol
   (lambda (make-instance)
     (lambda* ((name-id identifier?) (top-id identifier?) (lambda-id identifier?))
       (make-instance name-id top-id lambda-id
	 '() #;member-identifiers	'() #;definitions
	 #f  #;abstract?		#f  #;public-constructor-id
	 #f  #;public-predicate-id	#f  #;private-predicate-id
	 #f  #;common-protocol		#f  #;public-protocol
	 #f  #;super-protocol
	 top-id #;parent-id
	 '() #;concrete-fields		'() #;virtual-fields
	 '() #;methods-table
	 #f  #;sealed?			#f  #;opaque?
	 #f  #;getter			#f  #;setter
	 #f  #;nongenerative-uid	#f  #;maker-transformer
	 #f  #;finaliser-expression
	 #f  #;shadowed-identifier	'() #;satisfactions
	 ))))
  (fields (immutable name-id)
		;The identifier representing the type name.
	  (immutable top-id)
		;An identifier bound to the "<top>" tag.
	  (immutable lambda-id)
		;An  identifier bound  to  the  LAMBDA macro  supporting
		;tagged formal arguments.

	  (mutable member-identifiers)
		;Null or  a proper list of  identifiers representing the
		;names of  the members of  this label/class/mixin.  This
		;list  is  used to  check  for  duplicate names  between
		;fields and methods.

	  (mutable definitions)
		;Null or  a proper  list of syntax  objects representing
		;function  definition forms  or syntax  definition forms
		;for  methods,   getter,  setter  and   virtual  fields'
		;accessors and mutators.

	  (mutable abstract?)
		;Boolean  value.  It  is  used for  classes and  mixins.
		;When  true  the class  is  abstract  and it  cannot  be
		;instantiated; when  false the class is  concrete and it
		;can be instantiated.
		;
		;An abstract  class cannot have a common  protocol nor a
		;public protocol:  when this field is set  to true, both
		;the COMMON-PROTOCOL and  PUBLIC-PROTOCOL fields are set
		;to false.

	  (mutable public-constructor-id)
		;Identifier  to   be  used   as  name  for   the  public
		;constructor.

	  (mutable public-predicate-id)
		;Identifier  to  be  used  as  name  for  the  predicate
		;function or syntax.

	  (mutable private-predicate-id)
		;Identifier  to  be  used  as  name  for  the  predicate
		;function or syntax.

	  (mutable common-protocol)
		;False  or   syntax  object  containing   an  expression
		;evaluating to the common constructor protocol.

	  (mutable public-protocol)
		;False  or   syntax  object  containing   an  expression
		;evaluating to the public constructor protocol.

	  (mutable super-protocol)
		;False  or   syntax  object  containing   an  expression
		;evaluating to the  superclass or superlabel constructor
		;protocol.

	  (mutable parent-id)
		;Identifier bound to the parent tag syntax.  Initialised
		;to "<top>".

	  (mutable concrete-fields)
		;Null or a proper list of <CONCRETE-FIELD-SPEC> records.
		;The  order  of the  records  in  the  list matches  the
		;definition order.   Notice that fields  from the mixins
		;come last.

	  (mutable virtual-fields)
		;Null or a proper  list of <VIRTUAL-FIELD-SPEC> records.
		;The  order  of  the  records  is  the  reverse  of  the
		;definition order.

	  (mutable methods-table)
		;Null  or   an  associative  list   having:  identifiers
		;representing method names as keys, lists as values.
		;
		;  ((?method-name-id . (?rv-tag ?method-implementation-id))
		;   ...)
		;
		;The first item in the  list value is the tag identifier
		;of the single  return value from the adddress  or #f if
		;there  is no  such tag.   The second  item in  the list
		;value is  an identifier  representing the  method name,
		;which is bound to a function or syntax.
		;
		;The  order  of  the  entries  is  the  reverse  of  the
		;definition order.

	  (mutable sealed?)
		;Boolean  value.  It  is  used for  classes and  mixins.
		;When true the R6RS record  type associated to the class
		;is sealed.

	  (mutable opaque?)
		;Boolean  value.    When  true  the  R6RS   record  type
		;associated to the class is opaque.

	  (mutable getter)
		;False or a syntax  object representing an expression to
		;evaluate once,  at expand  time, to acquire  the getter
		;syntax transformer function.

	  (mutable setter)
		;False or a syntax  object representing an expression to
		;evaluate once,  at expand  time, to acquire  the setter
		;syntax transformer function.

	  (mutable nongenerative-uid)
		;A symbol  uniquely identifying  this type in  the whole
		;program.   It is  used  for classes  and mixins.   When
		;non-false: the R6RS record type associated to the class
		;is nongenerative.

	  (mutable maker-transformer)
		;False  or   a  syntax  object   holding  an  expression
		;evaluating to  a macro transformer to be  used to parse
		;the maker syntax.

	  (mutable finaliser-expression)
		;False or a  syntax object.  It is used  for classes and
		;mixins.  When  a syntax object: it  holds an expression
		;evaluating to  a function to  be used as  destructor by
		;the garbage  collector when finalising the  R6RS record
		;instance representing the class instance.

	  (mutable shadowed-identifier)
		;False  or  identifier.   It  is  used  for  labels  and
		;classes.  It  is the identifier  to insert in  place of
		;the     label     tag     identifier     when     using
		;WITH-LABEL-SHADOWING.

	  (mutable satisfactions)
		;Null or  list of identifiers being  syntax keywords for
		;satisfactions.
	  ))

(define-record-type <class-spec>
  (nongenerative nausicaa:language:oopp:<class-spec>)
  (parent <parsed-spec>)
  (fields (immutable record-type-id)
		;Identifier to be used as  name for the R6RS record type
		;associated to the class,  in the automatically composed
		;DEFINE-RECORD-TYPE form.
	  #| end of fields |# )
  (protocol
   (lambda (make-spec)
     (lambda (name-id top-id lambda-id)
       ((make-spec name-id top-id lambda-id)
	(tag-id->record-type-id name-id))))))

(define-record-type <label-spec>
  (nongenerative nausicaa:language:oopp:<label-spec>)
  (parent <parsed-spec>))

(define-record-type <mixin-spec>
  (nongenerative nausicaa:language:oopp:<mixin-spec>)
  (parent <parsed-spec>)
  (fields (immutable clauses)
		;The  syntax  object  representing  the clauses  in  the
		;DEFINE-MIXIN form.
	  #| end of fields |# ))


;;;; data types: field specification

(define-record-type <field-spec>
  (nongenerative nausicaa:language:oopp:helpers:<field-spec>)
  (protocol
   (lambda (make-record)
     (lambda* ((name identifier?) (acc identifier?) (mut %false-or-identifier?) (tag %false-or-identifier?))
       (make-record name acc mut tag))))
  (fields (immutable name-id)
		;Identifier representing the field name.
	  (immutable accessor-id)
		;Identifier  representing  the   accessor  name;  it  is
		;automatically built when not specified.
	  (immutable mutator-id)
		;For an  immutable field:  false.  For a  mutable field:
		;identifier  representing   the  mutator  name;   it  is
		;automatically built when not specified.
	  (immutable tag-id)
		;Identifier  representing the type  tag for  this field.
		;If  no type  tag is  specified  in the  label or  class
		;definition: the parser functions must set this field to
		;the top tag identifier.
	  ))

(define-record-type <concrete-field-spec>
  (nongenerative nausicaa:language:oopp:helpers:<concrete-field-spec>)
  (parent <field-spec>))

(define-record-type <virtual-field-spec>
  (nongenerative nausicaa:language:oopp:helpers:<virtual-field-spec>)
  (parent <field-spec>))


;;;; data type methods: small functions

(define* (<parsed-spec>-member-identifiers-cons! (parsed-spec <parsed-spec>?) id what-string synner)
  ;;Add  the  identifier  ID  to  the  list  of  member  identifiers  in
  ;;PARSED-SPEC.  If such identifier  is already present: raise a syntax
  ;;violation.
  ;;
  (let ((member-identifiers ($<parsed-spec>-member-identifiers parsed-spec)))
    (cond ((identifier-memq id member-identifiers free-identifier=?)
	   => (lambda (dummy)
		(synner (string-append what-string " conflicts with other member name") id)))
	  (else
	   ($<parsed-spec>-member-identifiers-set! parsed-spec (cons id member-identifiers))))))

(define* (<parsed-spec>-definitions-cons! (parsed-spec <parsed-spec>?) definition)
  ;;Prepend a definition form to the list of definitions in PARSED-SPEC.
  ;;
  ($<parsed-spec>-definitions-set! parsed-spec (cons definition ($<parsed-spec>-definitions parsed-spec))))

(define* (<parsed-spec>-concrete-fields-cons! (parsed-spec <parsed-spec>?) field-record)
  ;;Prepend a  field record  to the  list of  concrete field  records in
  ;;PARSED-SPEC.
  ;;
  ($<parsed-spec>-concrete-fields-set! parsed-spec (cons field-record ($<parsed-spec>-concrete-fields parsed-spec))))

(define* (<parsed-spec>-virtual-fields-cons! (parsed-spec <parsed-spec>?) field-record)
  ;;Prepend  a field  record to  the list  of virtual  field  records in
  ;;PARSED-SPEC.
  ;;
  ($<parsed-spec>-virtual-fields-set! parsed-spec (cons field-record ($<parsed-spec>-virtual-fields parsed-spec))))

(define* (<parsed-spec>-methods-table-cons! (parsed-spec <parsed-spec>?)
					    method-name-id method-rv-tag-id method-implementation-id)
  ;;Prepend an entry in the methods table.
  ;;
  ($<parsed-spec>-methods-table-set! parsed-spec (cons (list method-name-id method-rv-tag-id method-implementation-id)
						       ($<parsed-spec>-methods-table parsed-spec))))

(define* (<parsed-spec>-satisfactions-cons! (parsed-spec <parsed-spec>?) id)
  (when config.enable-satisfactions
    ($<parsed-spec>-satisfactions-set! parsed-spec (cons id ($<parsed-spec>-satisfactions parsed-spec)))))

(define (generate-unique-id parsed-spec)
  (datum->syntax (<parsed-spec>-name-id parsed-spec) (gensym)))

;;; --------------------------------------------------------------------

(define* (<parsed-spec>-mutable-fields-data (spec <parsed-spec>?))
  ;;Select the mutable fields among  the concrete and virtual fields and
  ;;return a list of lists with the format:
  ;;
  ;;	((?field-name ?accessor ?mutator ?tag) ...)
  ;;
  (map (lambda (field-record)
	 (list ($<field-spec>-name-id		field-record)
	       ($<field-spec>-accessor-id	field-record)
	       ($<field-spec>-mutator-id	field-record)
	       ($<field-spec>-tag-id		field-record)))
    (filter (lambda (field-record)
	      ($<field-spec>-mutator-id field-record))
      (if (<class-spec>? spec)
	  (append ($<parsed-spec>-concrete-fields spec)
		  ($<parsed-spec>-virtual-fields spec))
	($<parsed-spec>-virtual-fields spec)))))

(define* (<parsed-spec>-unsafe-mutable-fields-data (spec <parsed-spec>?))
  ;;Select the  mutable fields  among the concrete  fields and  return a
  ;;list of lists with the format:
  ;;
  ;;	((?field-name ?unsafe-field-name ?tag) ...)
  ;;
  (if (<class-spec>? spec)
      (map (lambda (field-record)
	     (define field-name-id
	       ($<field-spec>-name-id field-record))
	     (list field-name-id
		   (identifier-prefix "$" field-name-id)
		   ($<field-spec>-tag-id field-record)))
	(filter (lambda (field-record)
		  ($<field-spec>-mutator-id field-record))
	  ($<parsed-spec>-concrete-fields spec)))
    '()))

;;; --------------------------------------------------------------------

(define* (<parsed-spec>-immutable-fields-data (spec <parsed-spec>?))
  ;;Select the  immutable fields among  the concrete and  virtual fields
  ;;and return a list of lists with the format:
  ;;
  ;;	((?field-name ?unsafe-field-name ?accessor ?tag) ...)
  ;;
  (map (lambda (field-record)
	 (list ($<field-spec>-name-id		field-record)
	       ($<field-spec>-accessor-id	field-record)
	       ($<field-spec>-tag-id		field-record)))
    (filter (lambda (field-record)
	      (not ($<field-spec>-mutator-id field-record)))
      (if (<class-spec>? spec)
	  (append ($<parsed-spec>-concrete-fields spec)
		  ($<parsed-spec>-virtual-fields  spec))
	($<parsed-spec>-virtual-fields spec)))))

(define* (<parsed-spec>-unsafe-immutable-fields-data (spec <parsed-spec>?))
  ;;Select the immutable  fields among the concrete fields  and return a
  ;;list of lists with the format:
  ;;
  ;;	((?field-name ?unsafe-field-name ?tag) ...)
  ;;
  (if (<class-spec>? spec)
      (map (lambda (field-record)
	     (define field-name-id
	       ($<field-spec>-name-id field-record))
	     (list field-name-id
		   (identifier-prefix "$" field-name-id)
		   ($<field-spec>-tag-id field-record)))
	(filter (lambda (field-record)
		  (not ($<field-spec>-mutator-id field-record)))
	  ($<parsed-spec>-concrete-fields spec)))
    '()))

;;; --------------------------------------------------------------------

(define* (<parsed-spec>-concrete-fields-data (spec <parsed-spec>?))
  ;;Take the concrete fields and return a list of lists with the format:
  ;;
  ;;   (?field-spec ...)
  ;;
  ;;where ?FIELD-SPEC has one of the formats:
  ;;
  ;;   (mutable   ?field-name ?accessor ?mutator)
  ;;   (immutable ?field-name ?accessor)
  ;;
  ;;The returned  list can  be used  as content for  a FIELDS  clause of
  ;;DEFINE-RECORD-TYPE as defined by R6RS.
  ;;
  (map (lambda (field-record)
	 (let ((name-id     ($<field-spec>-name-id     field-record))
	       (accessor-id ($<field-spec>-accessor-id field-record))
	       (mutator     ($<field-spec>-mutator-id  field-record)))
	   (if mutator
	       (list #'aux.mutable name-id accessor-id mutator)
	     (list #'aux.immutable name-id accessor-id))))
    ($<parsed-spec>-concrete-fields spec)))

(define* (<parsed-spec>-concrete-fields-names (spec <parsed-spec>?))
  ;;Take the concrete fields and return a list with the format:
  ;;
  ;;   (?field-name ...)
  ;;
  ;;where ?FIELD-NAME is an identifier representing a field name.
  ;;
  (map (lambda (field-record)
	 ($<field-spec>-name-id field-record))
    ($<parsed-spec>-concrete-fields spec)))

;;; --------------------------------------------------------------------

(module (<label-spec>-satisfaction-clauses
	 <class-spec>-satisfaction-clauses)

  (define* (<label-spec>-satisfaction-clauses (spec <parsed-spec>?))
    (receive (virtual-mutable-fields virtual-immutable-fields)
	(%field-spec-satisfaction-clauses ($<parsed-spec>-virtual-fields spec))
      (list (list ($<parsed-spec>-name-id spec)
		  ($<parsed-spec>-public-constructor-id spec)
		  ($<parsed-spec>-public-predicate-id spec))
	    (list #'aux.parent		($<parsed-spec>-parent-id spec))
	    (cons #'aux.virtual-fields	virtual-mutable-fields)
	    (cons #'aux.virtual-fields	virtual-immutable-fields)
	    (cons #'aux.methods		($<parsed-spec>-methods-table spec))
	    (list #'aux.getter		($<parsed-spec>-getter spec))
	    (list #'aux.setter		($<parsed-spec>-setter spec))
	    (list #'aux.nongenerative	($<parsed-spec>-nongenerative-uid spec))
	    (list #'aux.shadows		($<parsed-spec>-shadowed-identifier spec))
	    )))

  (define* (<class-spec>-satisfaction-clauses (spec <parsed-spec>?))
    (let-values (((concrete-mutable-fields concrete-immutable-fields)
		  (%field-spec-satisfaction-clauses ($<parsed-spec>-concrete-fields spec)))
		 ((virtual-mutable-fields virtual-immutable-fields)
		  (%field-spec-satisfaction-clauses ($<parsed-spec>-virtual-fields  spec))))
      (list (list ($<parsed-spec>-name-id spec)
		  ($<parsed-spec>-public-constructor-id	spec)
		  ($<parsed-spec>-public-predicate-id	spec)
		  ($<class-spec>-record-type-id		spec))
	    (list #'aux.parent		($<parsed-spec>-parent-id spec))
	    (cons #'aux.fields		concrete-mutable-fields)
	    (cons #'aux.fields		concrete-immutable-fields)
	    (cons #'aux.virtual-fields	virtual-mutable-fields)
	    (cons #'aux.virtual-fields	virtual-immutable-fields)
	    (cons #'aux.methods		($<parsed-spec>-methods-table spec))
	    (list #'aux.getter		($<parsed-spec>-getter spec))
	    (list #'aux.setter		($<parsed-spec>-setter spec))
	    (list #'aux.nongenerative	($<parsed-spec>-nongenerative-uid spec))
	    (list #'aux.sealed		($<parsed-spec>-sealed? spec))
	    (list #'aux.opaque		($<parsed-spec>-opaque? spec))
	    (list #'aux.abstract	($<parsed-spec>-abstract? spec))
	    )))

  (define (%field-spec-satisfaction-clauses fields)
    (receive (mutables immutables)
	(partition <field-spec>-mutator-id fields)
      (values (map (lambda (field-record)
		     (let ((name     ($<field-spec>-name-id     field-record))
			   (tag      ($<field-spec>-tag-id      field-record))
			   (accessor ($<field-spec>-accessor-id field-record))
			   (mutator  ($<field-spec>-mutator-id  field-record)))
		       #`(aux.mutable (#,name #,tag) #,accessor #,mutator)))
		mutables)
	      (map (lambda (field-record)
		     (let ((name     ($<field-spec>-name-id     field-record))
			   (tag      ($<field-spec>-tag-id      field-record))
			   (accessor ($<field-spec>-accessor-id field-record)))
		       #`(aux.immutable (#,name #,tag) #,accessor #f)))
		immutables))))

  #| end of module |# )


;;;; data type methods: tag accessor and mutator transformers

(define* (<parsed-spec>-accessor-transformer (spec <parsed-spec>?))
  ;;Given  the "<parsed-spec>"  instance  SPEC: return  a syntax  object
  ;;representing the accessor transformer function for the tag.
  ;;
  ;;Whenever a tagged variable is referenced in a form like:
  ;;
  ;;   (?var ?arg0 ?arg ...)
  ;;
  ;;first the symbol ?ARG0 is compared  to the names of the tag methods:
  ;;
  ;;1. If  it matches,  the form  is a  method call.
  ;;
  ;;2. If  no method name  matches, the form  is handed to  the accessor
  ;;   transformer function to attempt a match between ?ARG0 and a field
  ;;   name.
  ;;
  ;;3. If no field name matches, the form is handed to the parent tag to
  ;;   attempt a match with the parent tag's members.
  ;;
  ;;Let's consider the example:
  ;;
  ;;   (define-label <alpha>
  ;;     (fields a)
  ;;     (getter ---)
  ;;     (method (do O) ---))
  ;;
  ;;   (define-label <beta>
  ;;     (fields (b <alpha>)))
  ;;
  ;;   (define-label <gamma>
  ;;     (fields (c <beta>)))
  ;;
  ;;   (<gamma> O ---)
  ;;
  ;;where  O is  the tagged  variable; the  following  syntax expansions
  ;;should happen:
  ;;
  ;;   (O c)
  ;;   ==> (<gamma>-c O)
  ;;
  ;;   (O c b)
  ;;   ==> (<beta>-b (<gamma>-c O))
  ;;
  ;;   (O c b a)
  ;;   ==> (<alpha>-a (<beta>-b (<gamma>-c O)))
  ;;
  ;;we  also want  to support  nested  getter invocations,  that is  the
  ;;following expansion should happen:
  ;;
  ;;   (O c b[123])
  ;;   ==> (<alpha> :getter ((<beta>-b (<gamma>-c O)) ([123])))
  ;;
  ;;we  also want  to support  nested  method invocations,  that is  the
  ;;following expansion should hapen:
  ;;
  ;;   (O c b do)
  ;;   ==> (<alpha> :dispatch ((<beta>-b (<gamma>-c O)) do))
  ;;
  ;;Notice that the  getter syntax is handled by  the getter transformer
  ;;function, not by the accessor function.
  ;;
  (with-syntax
      ((THE-TAG
	($<parsed-spec>-name-id spec))
       (THE-PARENT
	($<parsed-spec>-parent-id spec))
       (THE-RECORD-TYPE
	(if (<class-spec>? spec)
	    ($<class-spec>-record-type-id spec)
	  #f))
       (((IMMUTABLE-FIELD IMMUTABLE-ACCESSOR IMMUTABLE-TAG) ...)
	(<parsed-spec>-immutable-fields-data spec))
       (((MUTABLE-FIELD MUTABLE-ACCESSOR MUTABLE-MUTATOR MUTABLE-TAG) ...)
	(<parsed-spec>-mutable-fields-data spec))
       (((IMMUTABLE-CONCRETE-FIELD UNSAFE-IMMUTABLE-CONCRETE-FIELD IMMUTABLE-CONCRETE-TAG) ...)
	(<parsed-spec>-unsafe-immutable-fields-data spec))
       (((MUTABLE-CONCRETE-FIELD UNSAFE-MUTABLE-CONCRETE-FIELD MUTABLE-CONCRETE-TAG) ...)
	(<parsed-spec>-unsafe-mutable-fields-data spec)))
    #'(lambda (original-stx expr-stx args-stx)
	;;Process  a  field  accessor  form in  which:  EXPR-STX  is  an
	;;expression  evaluating to  a  Scheme object  of type  THE-TAG;
	;;ARGS-STX is the list of  syntax objects representing the field
	;;name and additional subordinate arguments.
	;;
	;;ORIGINAL-STX is  a syntax  object holding the  original syntax
	;;use that generated the accessor call.
	;;
	(syntax-case args-stx ()

	  ;;Try to match the access to a field.
	  ((??field-name)
	   (identifier? #'??field-name)
	   (case-symbol (syntax->datum #'??field-name)
	     ;;Safe accessors.
	     ((IMMUTABLE-FIELD)
	      #`(IMMUTABLE-TAG #:nested-oopp-syntax (IMMUTABLE-ACCESSOR #,expr-stx)))
	     ...
	     ((MUTABLE-FIELD)
	      #`(MUTABLE-TAG   #:nested-oopp-syntax (MUTABLE-ACCESSOR   #,expr-stx)))
	     ...
	     ;;Unsafe accessors.
	     ((UNSAFE-IMMUTABLE-CONCRETE-FIELD)
	      #`(IMMUTABLE-CONCRETE-TAG #:nested-oopp-syntax
					($record-type-field-ref THE-RECORD-TYPE IMMUTABLE-CONCRETE-FIELD #,expr-stx)))
	     ...
	     ((UNSAFE-MUTABLE-CONCRETE-FIELD)
	      #`(MUTABLE-CONCRETE-TAG #:nested-oopp-syntax
				      ($record-type-field-ref THE-RECORD-TYPE   MUTABLE-CONCRETE-FIELD #,expr-stx)))
	     ...
	     (else
	      #`(THE-PARENT :dispatch (#,expr-stx ??field-name)))))

	  ;;Try to match a field name followed by the getter syntax.
	  ((??field-name (??key0 (... ...)) (??key (... ...)) (... ...))
	   (identifier? #'??field-name)
	   (with-syntax ((KEYS #'((??key0 (... ...)) (??key (... ...)) (... ...))))
	     (case-symbol (syntax->datum #'??field-name)
	       ;;Safe accessors.
	       ((IMMUTABLE-FIELD)
		#`(IMMUTABLE-TAG :getter ((IMMUTABLE-ACCESSOR #,expr-stx) KEYS)))
	       ...
	       ((MUTABLE-FIELD)
		#`(MUTABLE-TAG   :getter ((MUTABLE-ACCESSOR   #,expr-stx) KEYS)))
	       ...
	       ;;Unsafe accessors.
	       ((UNSAFE-IMMUTABLE-CONCRETE-FIELD)
		#`(IMMUTABLE-CONCRETE-TAG :getter
					  (($record-type-field-ref THE-RECORD-TYPE IMMUTABLE-CONCRETE-FIELD #,expr-stx) KEYS)))
	       ...
	       ((UNSAFE-MUTABLE-CONCRETE-FIELD)
		#`(MUTABLE-CONCRETE-TAG   :getter
					  (($record-type-field-ref THE-RECORD-TYPE   MUTABLE-CONCRETE-FIELD #,expr-stx) KEYS)))
	       ...
	       (else
		#`(THE-PARENT :dispatch (#,expr-stx ??field-name . KEYS))))))

	  ;;Try to match a field name followed by arguments.
	  ((??field-name . ??args)
	   (identifier? #'??field-name)
	   (case-symbol (syntax->datum #'??field-name)
	     ;;Safe accessors.
	     ((IMMUTABLE-FIELD)
	      #`(IMMUTABLE-TAG :dispatch ((IMMUTABLE-ACCESSOR #,expr-stx) . ??args)))
	     ...
	     ((MUTABLE-FIELD)
	      #`(MUTABLE-TAG   :dispatch ((MUTABLE-ACCESSOR   #,expr-stx) . ??args)))
	     ...
	     ;;Unsafe accessors.
	     ((UNSAFE-IMMUTABLE-CONCRETE-FIELD)
	      #`(IMMUTABLE-CONCRETE-TAG :dispatch
					(($record-type-field-ref THE-RECORD-TYPE IMMUTABLE-CONCRETE-FIELD #,expr-stx) . ??args)))
	     ...
	     ((UNSAFE-MUTABLE-CONCRETE-FIELD)
	      #`(MUTABLE-CONCRETE-TAG   :dispatch
					(($record-type-field-ref THE-RECORD-TYPE   MUTABLE-CONCRETE-FIELD #,expr-stx) . ??args)))
	     ...
	     (else
	      #`(THE-PARENT :dispatch (#,expr-stx ??field-name . ??args)))))

	  (_
	   (syntax-violation 'THE-TAG "invalid :accessor tag syntax" original-stx))))))

(define* (<parsed-spec>-mutator-transformer (spec <parsed-spec>?))
  ;;Given  the "<parsed-spec>"  instance  SPEC: return  a syntax  object
  ;;representing the mutator transformer function for the tag.
  ;;
  ;;Whenever a tagged variable is referenced in a form like:
  ;;
  ;;   (set!/tags (?var ?arg0 ?arg ...) ?val)
  ;;
  ;;the  syntax  object  holding  the  form is  handed  to  the  mutator
  ;;transformer function  to attempt a  match between ?ARG0 and  a field
  ;;name; if  no field name  matches, the form  is handed to  the parent
  ;;tag's mutator transformer.
  ;;
  ;;Let's consider the example:
  ;;
  ;;   (define-label <alpha>
  ;;     (fields a)
  ;;     (setter ---))
  ;;
  ;;   (define-label <beta>
  ;;     (fields (b <alpha>)))
  ;;
  ;;   (define-label <gamma>
  ;;     (fields (c <beta>)))
  ;;
  ;;   (<gamma> O ---)
  ;;
  ;;where  O is  the tagged  variable; the  following  syntax expansions
  ;;should happen:
  ;;
  ;;   (set!/tags (O c) 99)
  ;;   ==> (<gamma>-c-set! O 99)
  ;;
  ;;   (set!/tags (O c b) 99)
  ;;   ==> (<beta>-b-set! (<gamma>-c O) 99)
  ;;
  ;;   (set!/tags (O c b a) 99)
  ;;   ==> (<alpha>-a-set! (<beta>-b (<gamma>-c O)) 99)
  ;;
  ;;we  also want  to support  nested  setter invocations,  that is  the
  ;;following expansion should happen:
  ;;
  ;;   (set!/tags (O c b[77]) 99)
  ;;   ==> (<alpha> :setter ((<gamma>-c (<beta>-b O)) ([77]) 99))
  ;;
  (with-syntax
      ((THE-TAG
	($<parsed-spec>-name-id spec))
       (THE-PARENT
	($<parsed-spec>-parent-id spec))
       (THE-RECORD-TYPE
	(if (<class-spec>? spec)
	    ($<class-spec>-record-type-id spec)
	  #f))
       (((IMMUTABLE-FIELD IMMUTABLE-ACCESSOR IMMUTABLE-TAG) ...)
	(<parsed-spec>-immutable-fields-data spec))
       (((MUTABLE-FIELD MUTABLE-ACCESSOR MUTABLE-MUTATOR MUTABLE-TAG) ...)
	(<parsed-spec>-mutable-fields-data spec))
       (((IMMUTABLE-CONCRETE-FIELD UNSAFE-IMMUTABLE-CONCRETE-FIELD IMMUTABLE-CONCRETE-TAG) ...)
	(<parsed-spec>-unsafe-immutable-fields-data spec))
       (((MUTABLE-CONCRETE-FIELD UNSAFE-MUTABLE-CONCRETE-FIELD MUTABLE-CONCRETE-TAG) ...)
	(<parsed-spec>-unsafe-mutable-fields-data spec)))
    #'(lambda (original-stx expr-stx keys-stx value-stx)
	;;Process a mutator form equivalent to:
	;;
	;;   (set!/tags (?var ?field-name0 ?arg ...) ?value)
	;;
	;;which has been previously decomposed so that KEYS-STX is:
	;;
	;;   (?field-name0 ?arg ...)
	;;
	;;and  VALUE-STX is  ?VALUE.  ?VAR  is a  tagged  variable whose
	;;actual value is in EXPR-STX.
	;;
	;;ORIGINAL-STX is  a syntax  object holding the  original syntax
	;;use that generated the mutator call.
	;;
	(syntax-case keys-stx ()
	  ((??field-name)
	   (identifier? #'??field-name)
	   (case-symbol (syntax->datum #'??field-name)
	     ;;Safe mutators.
	     ((MUTABLE-FIELD)
	      #`(MUTABLE-MUTATOR #,expr-stx (MUTABLE-TAG :assert-type-and-return #,value-stx)))
	     ...
	     ((IMMUTABLE-FIELD)
	      (syntax-violation 'THE-TAG "attempt to mutate immutable field" original-stx #'IMMUTABLE-FIELD))
	     ...
	     ;;Unsafe mutators.
	     ((UNSAFE-MUTABLE-CONCRETE-FIELD)
	      #`($record-type-field-set! THE-RECORD-TYPE MUTABLE-CONCRETE-FIELD #,expr-stx
					 (MUTABLE-CONCRETE-TAG :assert-type-and-return #,value-stx)))
	     ...
	     ((UNSAFE-IMMUTABLE-CONCRETE-FIELD)
	      (syntax-violation 'THE-TAG "attempt to mutate immutable field" original-stx #'IMMUTABLE-CONCRETE-FIELD))
	     ...
	     (else
	      #`(THE-PARENT :mutator #,expr-stx (??field-name) #,value-stx))))

	  ;;Try to  match a  field name followed  by the  getter syntax.
	  ;;This is the setter syntax with  the keys *not* enclosed in a
	  ;;list.
	  ((??field-name (??key0 (... ...)) (??key (... ...)) (... ...))
	   (identifier? #'??field-name)
	   (with-syntax ((KEYS #'((??key0 (... ...)) (??key (... ...)) (... ...))))
	     (case-symbol (syntax->datum #'??field-name)
	       ;;Safe mutators.
	       ((MUTABLE-FIELD)
		#`(MUTABLE-TAG   :setter ((MUTABLE-ACCESSOR   #,expr-stx) KEYS #,value-stx)))
	       ...
	       ((IMMUTABLE-FIELD)
		#`(IMMUTABLE-TAG :setter ((IMMUTABLE-ACCESSOR #,expr-stx) KEYS #,value-stx)))
	       ...
	       ;;Unsafe mutators.
	       ((UNSAFE-MUTABLE-CONCRETE-FIELD)
		#`(MUTABLE-CONCRETE-TAG   :setter
					  (($record-type-field-ref THE-RECORD-TYPE   MUTABLE-CONCRETE-FIELD #,expr-stx)
					   KEYS #,value-stx)))
	       ...
	       ((UNSAFE-IMMUTABLE-CONCRETE-FIELD)
		#`(IMMUTABLE-CONCRETE-TAG :setter
					  (($record-type-field-ref THE-RECORD-TYPE IMMUTABLE-CONCRETE-FIELD #,expr-stx)
					   KEYS #,value-stx)))
	       ...
	       (else
		#`(THE-PARENT :mutator #,expr-stx #,keys-stx #,value-stx)))))

	  ;;Try to match a field name followed by arguments.
	  ((??field-name0 ??arg (... ...))
	   (identifier? #'??field-name0)
	   (case-symbol (syntax->datum #'??field-name0)
	     ;;Safe mutators.
	     ((MUTABLE-FIELD)
	      #`(MUTABLE-TAG   :mutator (MUTABLE-ACCESSOR   #,expr-stx) (??arg (... ...)) #,value-stx))
	     ...
	     ((IMMUTABLE-FIELD)
	      #`(IMMUTABLE-TAG :mutator (IMMUTABLE-ACCESSOR #,expr-stx) (??arg (... ...)) #,value-stx))
	     ...
	     ;;Unsafe mutators.
	     ((UNSAFE-MUTABLE-CONCRETE-FIELD)
	      #`(MUTABLE-CONCRETE-TAG   :mutator ($record-type-field-ref THE-RECORD-TYPE   MUTABLE-CONCRETE-FIELD #,expr-stx)
					(??arg (... ...)) #,value-stx))
	     ...
	     ((UNSAFE-IMMUTABLE-CONCRETE-FIELD)
	      #`(IMMUTABLE-CONCRETE-TAG :mutator ($record-type-field-ref THE-RECORD-TYPE IMMUTABLE-CONCRETE-FIELD #,expr-stx)
					(??arg (... ...)) #,value-stx))
	     ...
	     (else
	      #`(THE-PARENT :mutator #,expr-stx (??field-name0 ??arg (... ...)) #,value-stx))))

	  (_
	   (syntax-violation 'THE-TAG "invalid :mutator tag syntax" original-stx))))))


;;;; clauses verification and unwrapping

(define (%verify-and-partially-unwrap-clauses clauses synner)
  ;;Non-tail  recursive  function.   Parse  the  syntax  object  CLAUSES
  ;;validating  it as  list  of clauses;  return  a partially  unwrapped
  ;;syntax object holding the same clauses.
  ;;
  ;;The structure of  the returned object is "list  of pairs" whose cars
  ;;are identifiers  representing a clauses' keyword and  whose cdrs are
  ;;syntax objects representing the clauses' arguments.  Input clauses:
  ;;
  ;;   #<syntax expr=((?id . ?args) ...)>
  ;;
  ;;output clauses:
  ;;
  ;;   ((#<syntax expr=?id> . #<syntax expr=?args>) ...)
  ;;
  (syntax-case clauses ()
    (() '())

    (((?keyword . ?args) . ?other-input-clauses)
     (identifier? #'?keyword)
     (cons (cons #'?keyword #'?args)
	   (%verify-and-partially-unwrap-clauses #'?other-input-clauses synner)))

    ((?input-clause . ?other-input-clauses)
     (synner "invalid clause syntax" #'?input-clause))))


;;;; parsers entry points

(module (parse-class-definition
	 parse-label-definition
	 parse-mixin-definition
	 parse-tag-name-spec)

  (define (parse-class-definition stx top-id lambda-id synner)
    ;;Parse the full  DEFINE-CLASS form in the syntax  object STX (after
    ;;mixin clauses  insertion) and  return an  instance of  record type
    ;;"<class-spec>".
    ;;
    ;;TOP-ID must be an identifier  bound to the "<top>" tag.  LAMBDA-ID
    ;;must be an identifier bound  to the LAMBDA macro supporting tagged
    ;;formal arguments.   SYNNER must be a  closure to be used  to raise
    ;;syntax violations.
    ;;
    (define (%combine class-spec clause-spec args)
      ((syntax-clause-spec-custom-data clause-spec) class-spec args synner)
      class-spec)
    (syntax-case stx ()
      ((_ ?tag-spec ?clause ...)
       (receive (name-id public-constructor-id predicate-id)
	   (parse-tag-name-spec #'?tag-spec synner)
	 (receive-and-return (class-spec)
	     (make-<class-spec> name-id top-id lambda-id)
	   ($<parsed-spec>-public-constructor-id-set! class-spec public-constructor-id)
	   ($<parsed-spec>-public-predicate-id-set!   class-spec predicate-id)
	   (syntax-clauses-fold-specs %combine class-spec CLASS-CLAUSES-SPECS
				      (syntax-clauses-unwrap #'(?clause ...) synner)
				      synner)
	   (%finalise-clauses-parsing! class-spec synner))))
      (_
       (synner "syntax error in class definition"))))

  (define (parse-label-definition stx top-id lambda-id synner)
    ;;Parse the full  DEFINE-LABEL form in the syntax  object STX (after
    ;;mixin clauses  insertion) and  return an  instance of  record type
    ;;"<label-spec>".
    ;;
    ;;TOP-ID must be an identifier  bound to the "<top>" tag.  LAMBDA-ID
    ;;must be an identifier bound  to the LAMBDA macro supporting tagged
    ;;formal arguments.   SYNNER must be a  closure to be used  to raise
    ;;syntax violations.
    ;;
    (define (%combine label-spec clause-spec args)
      ((syntax-clause-spec-custom-data clause-spec) label-spec args synner)
      label-spec)
    (syntax-case stx ()
      ((_ ?tag-spec ?clause ...)
       (receive (name-id public-constructor-id predicate-id)
	   (parse-tag-name-spec #'?tag-spec synner)
	 (receive-and-return (label-spec)
	     (make-<label-spec> name-id top-id lambda-id)
	   ($<parsed-spec>-public-constructor-id-set! label-spec public-constructor-id)
	   ($<parsed-spec>-public-predicate-id-set!   label-spec predicate-id)
	   (syntax-clauses-fold-specs %combine label-spec LABEL-CLAUSES-SPECS
				      (syntax-clauses-unwrap #'(?clause ...) synner)
				      synner)
	   (%finalise-clauses-parsing! label-spec synner))))
      (_
       (synner "syntax error in label definition"))))

  (define (parse-mixin-definition stx top-id lambda-id synner)
    ;;Parse the full  DEFINE-MIXIN form in the syntax  object STX (after
    ;;nested mixin clauses  insertion) and return an  instance of record
    ;;type "<mixin-spec>".
    ;;
    ;;TOP-ID must be an identifier  bound to the "<top>" tag.  LAMBDA-ID
    ;;must be an identifier bound  to the LAMBDA macro supporting tagged
    ;;formal arguments.   SYNNER must be a  closure to be used  to raise
    ;;syntax violations.
    ;;
    ;;We  perform the  full parsing  of the  definition to  catch errors
    ;;early, but we discard the results  of such parsing: the clauses in
    ;;a mixin definition are used by  the label or class definition that
    ;;imports them.
    ;;
    (define (%combine mixin-spec clause-spec args)
      ((syntax-clause-spec-custom-data clause-spec) mixin-spec args synner)
      mixin-spec)
    (syntax-case stx ()
      ((_ ?mixin-name ?clause ...)
       (identifier? #'?mixin-name)
       (receive-and-return (mixin-spec)
	   (make-<mixin-spec> #'?mixin-name top-id lambda-id #'(?clause ...))
	 (syntax-clauses-fold-specs %combine mixin-spec MIXIN-CLAUSES-SPECS
				    (syntax-clauses-unwrap #'(?clause ...) synner)
				    synner)
	 (%finalise-clauses-parsing! mixin-spec synner)))
      (_
       (synner "syntax error in mixin definition"))))

  (define (parse-tag-name-spec stx synner)
    ;;Parse the first component of a class or label definition:
    ;;
    ;;  (define-class ?tag-name-spec . ?clauses)
    ;;  (define-label ?tag-name-spec . ?clauses)
    ;;
    ;;supported syntaxes for ?TAG-NAME-SPEC are:
    ;;
    ;;  ?name-id
    ;;  (?name-id ?public-constructor-id ?predicate-id)
    ;;
    ;;Return  3  values:  an  identifier  representing the  tag  name;  an
    ;;identifier representing  the public constructor  name; an identifier
    ;;representing the predicate name.
    ;;
    (syntax-case stx ()
      (?name-id
       (identifier? #'?name-id)
       (let ((name-id #'?name-id))
	 (values name-id
		 (tag-id->constructor-id      name-id)
		 (tag-id->public-predicate-id name-id))))

      ((?name-id ?public-constructor-id ?predicate-id)
       (and (identifier? #'?name-id)
	    (identifier? #'?public-constructor-id)
	    (identifier? #'?predicate-id))
       (values #'?name-id #'?public-constructor-id #'?predicate-id))

      (_
       (synner "invalid name specification in tag definition" stx))))

  (define* (%finalise-clauses-parsing! (parsed-spec <parsed-spec>?) synner)
    ;;Normalise  the results  of parsing  class, label  or mixin  clauses.
    ;;Mutate PARSED-SPEC.  Return unspecified values.
    ;;
    (when (<class-spec>? parsed-spec)
      (let ((concrete-fields ($<parsed-spec>-concrete-fields parsed-spec)))
	(unless (null? concrete-fields)
	  ($<parsed-spec>-concrete-fields-set! parsed-spec (reverse concrete-fields))))
      (when ($<parsed-spec>-abstract? parsed-spec)
	(when (<parsed-spec>-common-protocol parsed-spec)
	  (synner "common protocol clause forbidden in definition of abstract class"))
	(when (<parsed-spec>-public-protocol parsed-spec)
	  (synner "public protocol clause forbidden in definition of abstract class"))))
    (let ((definitions ($<parsed-spec>-definitions parsed-spec)))
      (unless (null? definitions)
	($<parsed-spec>-definitions-set! parsed-spec (reverse definitions))))
    (unless ($<parsed-spec>-nongenerative-uid parsed-spec)
      ($<parsed-spec>-nongenerative-uid-set! parsed-spec (generate-unique-id parsed-spec))))

  #| end of module |# )


;;;; parsers entry points: mixins clauses filtering

(define filter-and-validate-mixins-clauses
  (case-lambda
   ((input-clauses synner)
    (filter-and-validate-mixins-clauses (%verify-and-partially-unwrap-clauses input-clauses synner) synner '() '()))
   ((input-clauses synner collected-mixins output-clauses)
    ;;Tail-recursive function.   Parse clauses  with keyword  MIXINS and
    ;;prepend  the  mixin  identifiers to  COLLECTED-MIXINS.   Return  2
    ;;values: a  list of identifiers  being the mixin identifiers  to be
    ;;inserted in the given order, the list of other clauses.
    ;;
    (define-syntax %recurse
      (syntax-rules ()
	((_ ?input-clauses ?output-clauses)
	 (filter-and-validate-mixins-clauses ?input-clauses synner collected-mixins ?output-clauses))
	((_ ?collected-mixins ?input-clauses ?output-clauses)
	 (filter-and-validate-mixins-clauses ?input-clauses synner ?collected-mixins ?output-clauses))))
    (cond
     ;;No more input clauses.
     ((null? input-clauses)
      (values (reverse collected-mixins)
	      (reverse output-clauses)))
     ;;Parse matching clause.
     ((free-identifier=? #'aux.mixins (caar input-clauses))
      (syntax-case ($cdar input-clauses) ()
	(()
	 (%recurse ($cdr input-clauses) output-clauses))
	((?mixin ...)
	 (let loop ((collected-mixins	collected-mixins)
		    (new-mixins		#'(?mixin ...)))
	   (syntax-case new-mixins ()
	     (()
	      (%recurse collected-mixins ($cdr input-clauses) output-clauses))
	     ;;No substitutions.
	     ((?mixin . ?other-mixins)
	      (identifier? #'?mixin)
	      (loop (cons #'(?mixin) collected-mixins) #'?other-mixins))
	     ;;With map of substitutions.
	     (((?mixin (?from ?to) ...) . ?other-mixins)
	      (and (identifier? #'?mixin)
		   (all-identifiers? #'(?from ... ?to ...)))
	      (loop (cons #'(?mixin (?from ?to) ...) collected-mixins) #'?other-mixins))
	     (_
	      (synner "expected identifier as mixin" ($car input-clauses))))))
	(_
	 (synner "invalid mixins specification" ($car input-clauses)))))

     ;;Parse non-matching clause.
     (else
      (%recurse ($cdr input-clauses)
		(cons ($car input-clauses) output-clauses)))))))


;;;; some at-most-once clause parsers: parent, opaque, sealed, nongenerative, shadows, maker

(define (clause-arguments-parser:parent parsed-spec args synner)
  ;;Parser function for  the PARENT clause; this clause  must be present
  ;;at most once.  The expected syntax for the clause is:
  ;;
  ;;   (parent ?parent-tag-id)
  ;;
  ;;where ?parent-TAG-ID  is the identifier  bound to the tag  syntax of
  ;;the parent type.
  ;;
  (syntax-case args ()
    (#(#(?parent-tag-id))
     (if (identifier? #'?parent-tag-id)
	 (<parsed-spec>-parent-id-set! parsed-spec #'?parent-tag-id)
       (synner "invalid tag parent type specification" #'?parent-tag-id)))))

(define (clause-arguments-parser:sealed parsed-spec args synner)
  ;;Parser function for  the SEALED clause; this clause  must be present
  ;;at most once.  The expected syntax for the clause is:
  ;;
  ;;   (sealed #t)
  ;;   (sealed #f)
  ;;
  (syntax-case args ()
    (#(#(?sealed))
     (let ((sealed? (syntax->datum #'?sealed)))
       (if (boolean? sealed?)
	   (<parsed-spec>-sealed?-set! parsed-spec sealed?)
	 (synner "invalid tag type sealed specification" #'?sealed))))))

(define (clause-arguments-parser:opaque parsed-spec args synner)
  ;;Parser function for  the OPAQUE clause; this clause  must be present
  ;;at most once.  The expected syntax for the clause is:
  ;;
  ;;   (opaque #t)
  ;;   (opaque #f)
  ;;
  (syntax-case args ()
    (#(#(?opaque))
     (let ((opaque? (syntax->datum #'?opaque)))
       (if (boolean? opaque?)
	   (<parsed-spec>-opaque?-set! parsed-spec opaque?)
	 (synner "invalid tag type opaque specification" #'?opaque))))))

(define (clause-arguments-parser:shadows parsed-spec args synner)
  ;;Parser function for the SHADOWS  clause; this clause must be present
  ;;at most once.  The expected syntax for the clause is:
  ;;
  ;;   (shadows ?id)
  ;;
  ;;where ?ID is an identifier.  The  selected identifier is used by the
  ;;syntax  WITH-LABEL-SHADOWING to  hide  some type  definition with  a
  ;;label.  For  example: this  mechanism allows  to shadow  a condition
  ;;type definition  with a label  type and so  to use the  tag syntaxes
  ;;with condition objects.
  ;;
  (syntax-case args ()
    (#(#(?shadowed-id))
     (if (identifier? #'?shadowed-id)
	 (<parsed-spec>-shadowed-identifier-set! parsed-spec #'?shadowed-id)
       (synner "invalid tag type shadowed identifier specification" #'?shadowed-id)))))

(define (clause-arguments-parser:maker parsed-spec args synner)
  ;;Parser function for the MAKER clause; this clause must be present at
  ;;most once.  The expected syntax for the clause is:
  ;;
  ;;   (maker ?transformer-expr)
  ;;
  ;;where  ?TRANSFORMER-EXPR  is an  expression  evaluating  to a  macro
  ;;transformer to  be used to parse  the maker syntax.  We  can imagine
  ;;the definition:
  ;;
  ;;   (define-class <alpha>
  ;;     (fields a b)
  ;;     (maker (lambda (stx)
  ;;              (syntax-case stx ()
  ;;                ((?tag (?a ?b))
  ;;                 #'(make-<alpha> ?a ?b))))))
  ;;
  ;;to expand to:
  ;;
  ;;   (define-syntax <alpha>
  ;;     (let ((the-maker (lambda (stx)
  ;;                       (syntax-case stx ()
  ;;                         ((?tag (?a ?b))
  ;;                          #'(make-<alpha> ?a ?b))))))
  ;;       (lambda (stx)
  ;;         ---)))
  ;;
  ;;and so the following expansion happens:
  ;;
  ;;   (<alpha> (1 2))	---> (make-<alpha> 1 2)
  ;;
  (syntax-case args ()
    (#(#(?transformer-expr))
     (<parsed-spec>-maker-transformer-set! parsed-spec #'?transformer-expr))))

(define (clause-arguments-parser:finaliser parsed-spec args synner)
  ;;Parser  function  for the  FINALISER  clause;  this clause  must  be
  ;;present at most once.  The expected syntax for the clause is:
  ;;
  ;;   (finaliser ?lambda-expr)
  ;;
  ;;where ?LAMBDA-EXPR is  an expression evaluating to a  function to be
  ;;used by the garbage collector to finalise the record.
  ;;
  (syntax-case args ()
    (#(#(?lambda-expr))
     (<parsed-spec>-finaliser-expression-set! parsed-spec #'?lambda-expr))))

(define (clause-arguments-parser:nongenerative parsed-spec args synner)
  ;;Parser function  for the NONGENERATIVE  clause; this clause  must be
  ;;present at  most once;  this clause  must have  zero arguments  or a
  ;;single argument:
  ;;
  ;;   (nongenerative)
  ;;   (nongenerative ?unique-id)
  ;;
  ;;where ?UNIQUE-ID is the symbol  which uniquely identifies the record
  ;;type in a whole program.  If the clause has no argument: a unique id
  ;;is automatically generated.
  ;;
  (syntax-case args ()
    (#(#(?unique-id))
     (if (identifier? #'?unique-id)
	 (<parsed-spec>-nongenerative-uid-set! parsed-spec #'?unique-id)
       (synner "expected identifier as NONGENERATIVE clause argument" #'?unique-id)))

    (#(#())
     (<parsed-spec>-nongenerative-uid-set! parsed-spec (generate-unique-id parsed-spec)))))


;;;; some at-most-once clause parsers: protocols, abstract, predicate

(define (clause-arguments-parser:common-protocol parsed-spec args synner)
  ;;Parser function for the PROTOCOL clause; this clause must be present
  ;;at most once.  The expected syntax for the clause is:
  ;;
  ;;   (protocol ?expr)
  ;;
  (syntax-case args ()
    (#(#(?protocol-expr))
     (<parsed-spec>-common-protocol-set! parsed-spec #'?protocol-expr))))

(define (clause-arguments-parser:public-protocol parsed-spec args synner)
  ;;Parser function for the PUBLIC-PROTOCOL  clause; this clause must be
  ;;present at most once.  The expected syntax for the clause is:
  ;;
  ;;   (public-protocol ?expr)
  ;;
  (syntax-case args ()
    (#(#(?protocol-expr))
     (<parsed-spec>-public-protocol-set! parsed-spec #'?protocol-expr))))

(define (clause-arguments-parser:super-protocol parsed-spec args synner)
  ;;Parser function for  the SUPER-PROTOCOL clause; this  clause must be
  ;;present at most once.  The expected syntax for the clause is:
  ;;
  ;;   (super-protocol ?expr)
  ;;
  (syntax-case args ()
    (#(#(?protocol-expr))
     (<parsed-spec>-super-protocol-set! parsed-spec #'?protocol-expr))))

(define (clause-arguments-parser:abstract parsed-spec args synner)
  ;;Parser function for the ABSTRACT clause; this clause must be present
  ;;at  most once  and  only  in a  DEFINE-CLASS  or DEFINE-MIXIN.   The
  ;;expected syntax for the clause is:
  ;;
  ;;   (abstract)
  ;;
  (syntax-case args ()
    (#(#())
     (<parsed-spec>-abstract?-set! parsed-spec #t))))

(define (clause-arguments-parser:predicate parsed-spec args synner)
  ;;Parser  function  for the  PREDICATE  clause;  this clause  must  be
  ;;present at most once.  The expected syntax for the clause is:
  ;;
  ;;   (predicate ?predicate)
  ;;
  ;;When a function predicate expression is specified as an identifier:
  ;;
  ;;  (define-label <list>
  ;;    (parent <pair>)
  ;;    (predicate list?))
  ;;
  ;;the tag definition expands to:
  ;;
  ;;  (define (<list>? obj)
  ;;    (and (<pair> :is-a? obj)
  ;;         (list? obj)))
  ;;
  ;;and the following tag syntax expansion happens:
  ;;
  ;;  (<list> is-a? ?obj) ==> (<list>? ?obj)
  ;;
  ;;When a function predicate expression is specified as an expression:
  ;;
  ;;  (define-label <list-of-numbers>
  ;;    (parent <pair>)
  ;;    (predicate (lambda (obj)
  ;;                 (and (list? obj)
  ;;                      (for-all number? obj)))))
  ;;
  ;;the tag definition expands to:
  ;;
  ;;  (define <list-of-numbers>-private-predicate
  ;;    (lambda (obj)
  ;;      (and (list? obj)
  ;;           (for-all number? obj))))
  ;;
  ;;  (define (<list-of-numbers>? obj)
  ;;    (and (<pair> :is-a? obj)
  ;;         (<list-of-numbers>-private-predicate obj)))
  ;;
  ;;and the following tag syntax expansion happens:
  ;;
  ;;  (<list-of-numbers> is-a? ?obj) ==> (<list-of-numbers>? ?obj)
  ;;
  (syntax-case args ()
    (#(#(?predicate))
     (if (identifier? #'?predicate)
	 (<parsed-spec>-private-predicate-id-set! parsed-spec #'?predicate)
       (let ((pred-id (tag-id->private-predicate-id (<parsed-spec>-name-id parsed-spec))))
	 (<parsed-spec>-private-predicate-id-set! parsed-spec pred-id)
	 (<parsed-spec>-definitions-cons!         parsed-spec (list #'define pred-id #'?predicate)))))))


;;;; single method function clauses

(module (clause-arguments-parser:single-method)
  ;;Parser function for METHOD clauses;  this clause can be present zero
  ;;or more times.  A METHOD clause has one of the following syntaxes:
  ;;
  ;;  (method (?method-int ?arg ... . ?rest) ?body0 ?body ...)
  ;;  (method ?method-ext ?lambda-expr)
  ;;
  ;;where ?METHOD-INT has one of the syntaxes:
  ;;
  ;;  ?method-name-id
  ;;  (?method-name-id ?rv-tag0 ?rv-tag ...)
  ;;  #(?method-name-id ?rv-tag0 ?rv-tag ...)
  ;;
  ;;where ?METHOD-EXT has one of the syntaxes:
  ;;
  ;;  ?method-name-id
  ;;  #(?method-name-id ?rv-tag)
  ;;
  ;;?ARG has one of the syntaxes:
  ;;
  ;;  ?arg-id
  ;;  (?arg-id ?arg-tag-id)
  ;;  #(?arg-id ?arg-tag-id)
  ;;
  ;;?REST has one of the syntaxes:
  ;;
  ;;  ()
  ;;  ?rest-id
  ;;  #(?rest-id ?rest-tag-id)
  ;;
  (define (clause-arguments-parser:single-method parsed-spec args synner)
    ;;We expect ARGS to have the format:
    ;;
    ;;  #(#(?method-spec ...) ...)
    ;;
    (vector-for-each
	(lambda (method-spec-stx)
	  (%parse-method-spec (vector->list method-spec-stx) parsed-spec synner))
      args))

  (define (%parse-method-spec method-spec-stx parsed-spec synner)
    (define-syntax TOP-ID	(identifier-syntax (<parsed-spec>-top-id    parsed-spec)))
    (define-syntax NAME-ID	(identifier-syntax (<parsed-spec>-name-id   parsed-spec)))
    (define-syntax LAMBDA-ID	(identifier-syntax (<parsed-spec>-lambda-id parsed-spec)))
    (syntax-case method-spec-stx ()
      (((?method-name-id . ?formals) ?body0 ?body ...)
       (identifier? #'?method-name-id)
       (%add-method parsed-spec #'?method-name-id TOP-ID
		    (make-method-identifier NAME-ID #'?method-name-id)
		    #`(#,LAMBDA-ID ?formals ?body0 ?body ...)
		    synner))

      ;;Tagged  single   return  value  method  definition.    List  tag
      ;;specification.
      ((((?method-name-id ?rv-tag) . ?formals) ?body0 ?body ...)
       (and (identifier? #'?method-name-id)
	    (identifier? #'?rv-tag))
       (%add-method parsed-spec #'?method-name-id #'?rv-tag
		    (make-method-identifier NAME-ID #'?method-name-id)
		    #`(#,LAMBDA-ID ((_ ?rv-tag) . ?formals) ?body0 ?body ...)
		    synner))

      ;;Tagged  single  return  value  method  definition.   Vector  tag
      ;;specification.
      (((#(?method-name-id ?rv-tag) . ?formals) ?body0 ?body ...)
       (and (identifier? #'?method-name-id)
	    (identifier? #'?rv-tag))
       (%add-method parsed-spec #'?method-name-id #'?rv-tag
		    (make-method-identifier NAME-ID #'?method-name-id)
		    #`(#,LAMBDA-ID ((_ ?rv-tag) . ?formals) ?body0 ?body ...)
		    synner))

      ;;Tagged  multiple  return  values method  definition.   List  tag
      ;;specification.
      ((((?method-name-id ?rv-tag0 ?rv-tag ...) . ?formals) ?body0 ?body ...)
       (and (identifier? #'?method-name-id)
	    (all-identifiers? #'(?rv-tag0 ?rv-tag ...)))
       (%add-method parsed-spec #'?method-name-id TOP-ID
		    (make-method-identifier NAME-ID #'?method-name-id)
		    #`(#,LAMBDA-ID ((_ ?rv-tag0 ?rv-tag ...) . ?formals) ?body0 ?body ...)
		    synner))

      ;;Tagged  multiple return  values method  definition.  Vector  tag
      ;;specification.
      (((#(?method-name-id ?rv-tag0 ?rv-tag ...) . ?formals) ?body0 ?body ...)
       (and (identifier? #'?method-name-id)
	    (all-identifiers? #'(?rv-tag0 ?rv-tag ...)))
       (%add-method parsed-spec #'?method-name-id TOP-ID
		    (make-method-identifier NAME-ID #'?method-name-id)
		    #`(#,LAMBDA-ID ((_ ?rv-tag0 ?rv-tag ...) . ?formals) ?body0 ?body ...)
		    synner))

      ;;Untagged external lambda method definition.
      ((?method-name-id ?lambda-expr)
       (identifier? #'?method-name-id)
       (%add-method parsed-spec #'?method-name-id TOP-ID
		    (make-method-identifier NAME-ID #'?method-name-id)
		    #'?lambda-expr synner))

      ;;Tagged external lambda method definition.
      ((#(?method-name-id ?rv-tag) ?lambda-expr)
       (and (identifier? #'?method-name-id)
	    (identifier? #'?rv-tag))
       (%add-method parsed-spec #'?method-name-id #'?rv-tag
		    (make-method-identifier NAME-ID #'?method-name-id)
		    #'?lambda-expr synner))

      (_
       (synner "invalid method specification in METHOD-SYNTAX clause" method-spec-stx))))

  (define (%add-method parsed-spec method-name-id method-rv-tag-id method-implementation-id method-expr synner)
    (<parsed-spec>-member-identifiers-cons! parsed-spec method-name-id "method name" synner)
    (<parsed-spec>-methods-table-cons!      parsed-spec method-name-id method-rv-tag-id method-implementation-id)
    (<parsed-spec>-definitions-cons!        parsed-spec `(,#'define ,method-implementation-id ,method-expr)))

  #| end of module: clause-arguments-parser:single-method |# )


;;;; single method syntax clauses

(module (clause-arguments-parser:method-syntax)
  ;;Parser  function  for  METHOD-SYNTAX  clauses; this  clause  can  be
  ;;present  zero  or  more  times.   A  METHOD-SYNTAX  clause  has  the
  ;;following syntax:
  ;;
  ;;  (method-syntax ?method ?transformer-expr)
  ;;
  ;;and ?METHOD has one of the following syntaxes:
  ;;
  ;;  ?method-name-id
  ;;  (?method-name-id ?rv-tag)
  ;;  #(?method-name-id ?rv-tag)
  ;;
  ;;where:  ?METHOD-NAME-ID is  an  identifier  representing the  method
  ;;name;  ?RV-TAG is  an identifier  representing the  type tag  of the
  ;;method  single  return  value; ?TRANSFORMER-EXPR  is  an  expression
  ;;which, evaluated at expand-time, must return the a macro transformer
  ;;representing the method implementation.
  ;;
  (define (clause-arguments-parser:method-syntax parsed-spec args synner)
    (vector-for-each
	(lambda (method-spec-stx)
	  (%parse-method-spec (vector->list method-spec-stx) parsed-spec synner))
      args))

  (define (%parse-method-spec method-spec-stx parsed-spec synner)
    (define-syntax TOP-ID
      (identifier-syntax (<parsed-spec>-top-id parsed-spec)))
    (define-syntax NAME-ID
      (identifier-syntax (<parsed-spec>-name-id parsed-spec)))
    (syntax-case method-spec-stx ()
      ;;Untagged return value method definition.
      ;;
      ((?method-name ?transformer-expr)
       (identifier? #'?method-name)
       (%add-method parsed-spec #'?method-name TOP-ID (make-method-identifier NAME-ID #'?method-name) #'?transformer-expr synner))

      ;;Tagged return value method definition.  List tag specification.
      ;;
      (((?method-name ?rv-tag) ?transformer-expr)
       (and (identifier? #'?method-name)
	    (identifier? #'?rv-tag))
       (%add-method parsed-spec #'?method-name #'?rv-tag (make-method-identifier NAME-ID #'?method-name) #'?transformer-expr synner))

      ;;Tagged return value method definition.  Vector tag specification.
      ;;
      ((#(?method-name ?rv-tag) ?transformer-expr)
       (and (identifier? #'?method-name)
	    (identifier? #'?rv-tag))
       (%add-method parsed-spec #'?method-name #'?rv-tag (make-method-identifier NAME-ID #'?method-name) #'?transformer-expr synner))

      (_
       (synner "invalid method specification in METHOD-SYNTAX clause" method-spec-stx))))

  (define (%add-method parsed-spec method-name-id method-rv-tag-id method-implementation-id transformer-expr-stx synner)
    (<parsed-spec>-member-identifiers-cons! parsed-spec method-name-id "method name" synner)
    (<parsed-spec>-methods-table-cons!      parsed-spec method-name-id method-rv-tag-id method-implementation-id)
    (<parsed-spec>-definitions-cons!        parsed-spec `(,#'define-syntax ,method-implementation-id ,transformer-expr-stx)))

  #| end of module: CLAUSE-ARGUMENTS-PARSER:MULTIPLE-METHODS |# )


;;;; multiple methods clauses

(module (clause-arguments-parser:multiple-methods)
  ;;Parser function for METHODS clauses; this clause can be present zero
  ;;or more times.  A METHODS clause has the following syntaxe:
  ;;
  ;;  (methods ?method-spec ...)
  ;;
  ;;where ?METHOD has one of the following syntaxes:
  ;;
  ;;  ?method
  ;;  (?method ?invocable-name)
  ;;
  ;;and ?METHOD has one of the following syntaxes:
  ;;
  ;;  ?method-name-id
  ;;  (?method-name-id ?rv-tag)
  ;;  #(?method-name-id ?rv-tag)
  ;;
  ;;where:  ?METHOD-NAME-ID is  an  identifier  representing the  method
  ;;name;  ?RV-TAG is  an identifier  representing the  type tag  of the
  ;;method single  return value; ?INVOCABLE-NAME is  an identifier bound
  ;;to the method implementation, a function or macro.
  ;;
  ;;When ?INVOCABLE-NAME is not specified  a default identifier is built
  ;;and used in its place.
  ;;
  (define (clause-arguments-parser:multiple-methods parsed-spec args synner)
    (vector-for-each
	(lambda (methods-clause-stx)
	  (vector-for-each
	      (lambda (method-spec-stx)
		(%parse-method-spec method-spec-stx parsed-spec synner))
	    methods-clause-stx))
      args))

  (define (%parse-method-spec method-spec-stx parsed-spec synner)
    (define-syntax TOP-ID
      (identifier-syntax (<parsed-spec>-top-id parsed-spec)))
    (define-syntax NAME-ID
      (identifier-syntax (<parsed-spec>-name-id parsed-spec)))
    (syntax-case method-spec-stx ()
      (?method-name
       (identifier? #'?method-name)
       (%add-method parsed-spec #'?method-name TOP-ID (make-method-identifier NAME-ID #'?method-name) synner))

      ;;Untagged return value method definition.
      ((?method-name ?invocable-name)
       (and (identifier? #'?method-name)
	    (identifier? #'?invocable-name))
       (%add-method parsed-spec #'?method-name TOP-ID #'?invocable-name synner))

      ;;Tagged return value method definition.  List tag specification.
      (((?method-name ?rv-tag) ?invocable-name)
       (and (identifier? #'?method-name)
	    (identifier? #'?rv-tag)
	    (identifier? #'?invocable-name))
       (%add-method parsed-spec #'?method-name #'?rv-tag #'?invocable-name synner))

      ;;Tagged   return    value   method   definition.     Vector   tag
      ;;specification.
      ((#(?method-name ?rv-tag) ?invocable-name)
       (and (identifier? #'?method-name)
	    (identifier? #'?rv-tag)
	    (identifier? #'?invocable-name))
       (%add-method parsed-spec #'?method-name #'?rv-tag #'?invocable-name synner))

      (_
       (synner "invalid method specification in METHODS clause" method-spec-stx))))

  (define (%add-method parsed-spec method-name-id method-rv-tag-id method-implementation-id synner)
    (<parsed-spec>-member-identifiers-cons! parsed-spec method-name-id "method name" synner)
    (<parsed-spec>-methods-table-cons!      parsed-spec method-name-id method-rv-tag-id method-implementation-id))

  #| end of module: CLAUSE-ARGUMENTS-PARSER:MULTIPLE-METHODS |# )


;;;; concrete and virtual fields helpers

(module FIELD-SPEC-PARSER
  (%parse-field-spec)

  (define* (%parse-field-spec field-spec-stx
			      (parsed-spec <parsed-spec>?)
			      (register-mutable-field   procedure?)
			      (register-immutable-field procedure?)
			      (synner procedure?))
    ;;Parse  a concrete  or virtual  field specification  and apply  the
    ;;proper function to the result.
    ;;
    (syntax-case field-spec-stx (aux.mutable aux.immutable)
      ((aux.mutable ?field ?accessor ?mutator)
       (receive (field-name-id type-tag-id)
	   (%parse-field #'?field parsed-spec synner)
	 (register-mutable-field field-name-id type-tag-id #'?accessor #'?mutator parsed-spec synner)))

      ((aux.immutable ?field ?accessor)
       (receive (field-name-id type-tag-id)
	   (%parse-field #'?field parsed-spec synner)
	 (register-immutable-field field-name-id type-tag-id #'?accessor parsed-spec synner)))

      ((aux.mutable ?field)
       (receive (field-name-id type-tag-id)
	   (%parse-field #'?field parsed-spec synner)
	 (register-mutable-field field-name-id type-tag-id #f #f parsed-spec synner)))

      ((aux.immutable ?field)
       (receive (field-name-id type-tag-id)
	   (%parse-field #'?field parsed-spec synner)
	 (register-immutable-field field-name-id type-tag-id #f parsed-spec synner)))

      (?field
       (receive (field-name-id type-tag-id)
	   (%parse-field #'?field parsed-spec synner)
	 (register-immutable-field field-name-id type-tag-id #f parsed-spec synner)))

      (_
       (synner "invalid virtual-field specification" field-spec-stx))))

  (define (%parse-field field-stx parsed-spec synner)
    (syntax-case field-stx ()
      (?field-name-id
       (identifier? #'?field-name-id)
       (values #'?field-name-id (<parsed-spec>-top-id parsed-spec)))

      ((?field-name-id ?type-tag-id)
       (and (identifier? #'?field-name-id)
	    (identifier? #'?type-tag-id))
       (values #'?field-name-id #'?type-tag-id))

      (#(?field-name-id ?type-tag-id)
       (and (identifier? #'?field-name-id)
	    (identifier? #'?type-tag-id))
       (values #'?field-name-id #'?type-tag-id))

      (_
       (synner "invalid field name and type tag specification" field-stx))))

  #| end of module: %PARSE-FIELD-SPEC |# )


;;;; concrete fields clauses

(module (clause-arguments-parser:concrete-fields)
  ;;Parser function for FIELDS clauses;  this clause can be present zero
  ;;or more times; this clause accepts zero or more arguments.  A FIELDS
  ;;clause has the following syntax:
  ;;
  ;;  (fields ?field-spec ...)
  ;;
  ;;where ?FIELD-SPEC has one of the following syntaxes:
  ;;
  ;;  (mutable   ?field)
  ;;  (mutable   ?field ?accessor ?mutator)
  ;;  (immutable ?field)
  ;;  (immutable ?field ?accessor)
  ;;  ?field
  ;;
  ;;where ?FIELD has one of the following syntaxes:
  ;;
  ;;  ?field-name-id
  ;;  (?field-name-id ?type-tag-id)
  ;;  #(?field-name-id ?type-tag-id)
  ;;
  ;;both ?ACCESSOR and ?MUTATOR must be identifiers.
  ;;
  (define (clause-arguments-parser:concrete-fields parsed-spec args synner)
    (vector-for-each
	(lambda (fields-clause-stx)
	  (vector-for-each
	      (lambda (field-spec-stx)
		(import FIELD-SPEC-PARSER)
		(%parse-field-spec field-spec-stx parsed-spec
				   %register-mutable-field %register-immutable-field synner))
	    fields-clause-stx))
      args))

  (define (%register-mutable-field field-name-id type-tag-id accessor-stx mutator-stx parsed-spec synner)
    (define accessor-id
      (%parse-concrete-field-acc/mut-spec field-name-id accessor-stx parsed-spec
					  identifier-record-field-accessor synner))
    (define mutator-id
      (%parse-concrete-field-acc/mut-spec field-name-id mutator-stx parsed-spec
					  identifier-record-field-mutator synner))
    (define field-spec
      (make-<concrete-field-spec> field-name-id accessor-id mutator-id type-tag-id))
    (%add-field-record parsed-spec field-spec synner))

  (define (%register-immutable-field field-name-id type-tag-id accessor-stx parsed-spec synner)
    (define accessor-id
      (%parse-concrete-field-acc/mut-spec field-name-id accessor-stx parsed-spec
					  identifier-record-field-accessor synner))
    (define field-spec
      (make-<concrete-field-spec> field-name-id accessor-id #f type-tag-id))
    (%add-field-record parsed-spec field-spec synner))

  (define* (%parse-concrete-field-acc/mut-spec (field-name-id identifier?)
					       acc/mut-stx
					       (parsed-spec <parsed-spec>?)
					       make-default-id synner)
    ;;Arguments:  the  field  name identifier  FIELD-NAME-ID,  a  syntax
    ;;object   ACC/MUT-STX   representing   the  accessor   or   mutator
    ;;specification,  the parsed  spec  record.   Support the  following
    ;;cases:
    ;;
    ;;If ACC/MUT-STX is an identifier:  such identifier will be bound to
    ;;the accessor or mutator function.
    ;;
    ;;If  ACC/MUT-STX  is  false:  it means  no  specification  for  the
    ;;accessor or  mutator was present.   A default accessor  or mutator
    ;;identifier is built  and returned.  Such identifier  will be bound
    ;;to the accessor or mutator function.
    ;;
    (cond ((identifier? acc/mut-stx)
	   acc/mut-stx)
	  ((not acc/mut-stx)
	   (make-default-id (<parsed-spec>-name-id parsed-spec) field-name-id))
	  (else
	   (synner "expected identifier as field accessor or mutator specification"
		   acc/mut-stx))))

  (define* (%add-field-record (parsed-spec <parsed-spec>?) (field-record <field-spec>?) synner)
    ;;Add a record representing a field specification to the appropriate
    ;;field in PARSED-SPEC.  Check for duplicate names in members.
    ;;
    (<parsed-spec>-member-identifiers-cons! parsed-spec (<field-spec>-name-id field-record)
					    "field name" synner)
    (<parsed-spec>-concrete-fields-cons! parsed-spec field-record))

  #| end of module |# )


;;;; virtual fields clauses

(module (clause-arguments-parser:virtual-fields)
  ;;Parser  function  for VIRTUAL-FIELDS  clauses;  this  clause can  be
  ;;present  zero  or more  times;  this  clause  accepts zero  or  more
  ;;arguments.  A VIRTUAL-FIELDS clause has the following syntax:
  ;;
  ;;  (virtual-fields ?field-spec ...)
  ;;
  ;;where ?FIELD-SPEC has one of the following syntaxes:
  ;;
  ;;  (mutable   ?field)
  ;;  (mutable   ?field ?accessor ?mutator)
  ;;  (immutable ?field)
  ;;  (immutable ?field ?accessor)
  ;;  ?field
  ;;
  ;;where ?FIELD has one of the following syntaxes:
  ;;
  ;;  ?field-name-id
  ;;  (?field-name-id ?type-tag-id)
  ;;  #(?field-name-id ?type-tag-id)
  ;;
  ;;both ?ACCESSOR  and ?MUTATOR can  be identifiers bound  to functions
  ;;and syntaxes or arbitrary expressions evaluating to the accessor and
  ;;mutator functions or syntax keyword.
  ;;
  (define (clause-arguments-parser:virtual-fields parsed-spec args synner)
    (vector-for-each
	(lambda (virtual-fields-clause-stx)
	  (vector-for-each
	      (lambda (field-spec-stx)
		(import FIELD-SPEC-PARSER)
		(%parse-field-spec field-spec-stx parsed-spec
				   %register-mutable-field %register-immutable-field synner))
	    virtual-fields-clause-stx))
      args))

  (define (%register-mutable-field field-name-id type-tag-id accessor-stx mutator-stx parsed-spec synner)
    (define accessor-id
      (%parse-virtual-field-acc/mut-spec field-name-id accessor-stx parsed-spec
					 identifier-record-field-accessor synner))
    (define mutator-id
      (%parse-virtual-field-acc/mut-spec field-name-id mutator-stx parsed-spec
					 identifier-record-field-mutator synner))
    (define field-spec
      (make-<virtual-field-spec> field-name-id accessor-id mutator-id type-tag-id))
    (%add-field-record parsed-spec field-spec synner))

  (define (%register-immutable-field field-name-id type-tag-id accessor-stx parsed-spec synner)
    (define accessor-id
      (%parse-virtual-field-acc/mut-spec field-name-id accessor-stx parsed-spec
					 identifier-record-field-accessor synner))
    (define field-spec
      (make-<virtual-field-spec> field-name-id accessor-id #f type-tag-id))
    (%add-field-record parsed-spec field-spec synner))

  (define* (%parse-virtual-field-acc/mut-spec (field-name-id identifier?)
					      acc/mut-stx
					      (parsed-spec <parsed-spec>?)
					      make-default-id synner)
    ;;Arguments:  the  field  name identifier  FIELD-NAME-ID,  a  syntax
    ;;object   ACC/MUT-STX   representing   the  accessor   or   mutator
    ;;specification,  the parsed  spec  record.   Support the  following
    ;;cases:
    ;;
    ;;If ACC/MUT-STX  is an identifier:  such identifier is meant  to be
    ;;bound to a function or macro  performing the access or mutation on
    ;;the instance.
    ;;
    ;;If  ACC/MUT-STX  is  false:  it means  no  specification  for  the
    ;;accessor or mutator  was present.  We build a  default accessor or
    ;;mutator identifier  and return  it.  It  is responsibility  of the
    ;;user code to  define a function or macro performing  the access or
    ;;mutation  on  the  instance,  and   to  bind  it  to  the  default
    ;;identifier.
    ;;
    ;;Otherwise  ACC/MUT-STX  must  represent  an  arbitrary  expression
    ;;which, evaluated at run-time, will  return a function.  We build a
    ;;default accessor or mutator identifier  and return it; in addition
    ;;we register in PARSED-SPEC a  definition binding the expression to
    ;;the default identifier.
    ;;
    (if (identifier? acc/mut-stx)
	acc/mut-stx
      (let ((acc/mut-id (make-default-id (<parsed-spec>-name-id parsed-spec)
					 field-name-id)))
	(when acc/mut-stx
	  (<parsed-spec>-definitions-cons! parsed-spec (list #'define acc/mut-id acc/mut-stx)))
	acc/mut-id)))

  (define* (%add-field-record (parsed-spec <parsed-spec>?) (field-record <field-spec>?) synner)
    ;;Add a record representing a field specification to the appropriate
    ;;field in PARSED-SPEC.  Check for duplicate names in members.
    ;;
    (<parsed-spec>-member-identifiers-cons! parsed-spec (<field-spec>-name-id field-record)
					    "field name" synner)
    (<parsed-spec>-virtual-fields-cons! parsed-spec field-record))

  #| end of module |# )


;;;; satisfactions

;;Parser function for SATISFIES clauses;  this clause can be present any
;;number of times and can have any number of arguments.
;;
(define (clause-arguments-parser:satisfies parsed-spec args synner)
  (vector-for-each
      (lambda (satisfaction-clause-stx)
	(vector-for-each
	    (lambda (satisfaction-stx)
	      (if (identifier? satisfaction-stx)
		  (<parsed-spec>-satisfactions-cons! parsed-spec satisfaction-stx)
		(synner "expected identifier as satisfaction clause argument" satisfaction-stx)))
	  satisfaction-clause-stx))
    args))


;;;; setter and getter clauses

;;Parser function for the GETTER  clause; this clause must be present at
;;most once.  The expected syntax for the clause is:
;;
;;   (getter ?expr)
;;
;;where ?EXPR is an expression evaluating to a getter syntax function.
;;
(define (clause-arguments-parser:getter parsed-spec args synner)
  (syntax-case args ()
    (#(#(?transformer-expr))
     (<parsed-spec>-getter-set! parsed-spec #'?transformer-expr))
    (_
     (synner "invalid GETTER clause syntax"))))

;;Parser function for the SETTER  clause; this clause must be present at
;;most once.  The expected syntax for the clause is:
;;
;;   (setter ?expr)
;;
;;where ?EXPR is an expression evaluating to a setter syntax function.
;;
(define (clause-arguments-parser:setter parsed-spec args synner)
  (syntax-case args ()
    (#(#(?transformer-expr))
     (<parsed-spec>-setter-set! parsed-spec #'?transformer-expr))
    (_
     (synner "invalid SETTER clause syntax"))))


;;;; clause specifications

(module (CLASS-CLAUSES-SPECS
	 LABEL-CLAUSES-SPECS
	 MIXIN-CLAUSES-SPECS)

  ;;Remember the arguments of MAKE-SYNTAX-CLAUSE-SPEC:
  ;;
  ;; (make-syntax-clause-spec keyword
  ;;    min-occur max-occur
  ;;    min-args max-args
  ;;    mutually-inclusive mutually-exclusive
  ;;    custom-data)
  ;;

;;; --------------------------------------------------------------------

  (define-constant CLAUSE-SPEC-NONGENERATIVE
    (make-syntax-clause-spec #'aux.nongenerative	0 1 0 1 '() '()	clause-arguments-parser:nongenerative))

  (define-constant CLAUSE-SPEC-SEALED
    (make-syntax-clause-spec #'aux.sealed		0 1 1 1 '() '()	clause-arguments-parser:sealed))

  (define-constant CLAUSE-SPEC-OPAQUE
    (make-syntax-clause-spec #'aux.opaque		0 1 1 1 '() '()	clause-arguments-parser:opaque))

  (define-constant CLAUSE-SPEC-ABSTRACT
    (make-syntax-clause-spec #'aux.abstract		0 1 0 0 '() '()	clause-arguments-parser:abstract))

  (define-constant CLAUSE-SPEC-PARENT
    (make-syntax-clause-spec #'aux.parent		0 1 1 1 '() '()	clause-arguments-parser:parent))

;;; --------------------------------------------------------------------

  (define-constant CLAUSE-SPEC-COMMON-PROTOCOL
    (make-syntax-clause-spec #'aux.protocol		0 1 1 1 '() '()	clause-arguments-parser:common-protocol))

  (define-constant CLAUSE-SPEC-PUBLIC-PROTOCOL
    (make-syntax-clause-spec #'aux.public-protocol	0 1 1 1 '() '()	clause-arguments-parser:public-protocol))

  (define-constant CLAUSE-SPEC-SUPER-PROTOCOL
    (make-syntax-clause-spec #'aux.super-protocol	0 1 1 1 '() '()	clause-arguments-parser:super-protocol))

;;; --------------------------------------------------------------------

  (define-constant CLAUSE-SPEC-PREDICATE
    (make-syntax-clause-spec #'aux.predicate		0 1 1 1 '() '()	clause-arguments-parser:predicate))

  (define-constant CLAUSE-SPEC-MAKER
    (make-syntax-clause-spec #'aux.maker		0 1 1 1 '() '()	clause-arguments-parser:maker))

  (define-constant CLAUSE-SPEC-FINALISER
    (make-syntax-clause-spec #'aux.finaliser		0 1 1 1 '() '()	clause-arguments-parser:finaliser))

;;; --------------------------------------------------------------------

  (define-constant CLAUSE-SPEC-CONCRETE-FIELDS
    (make-syntax-clause-spec #'aux.fields		0 +inf.0 0 +inf.0 '() '()	clause-arguments-parser:concrete-fields))

  (define-constant CLAUSE-SPEC-VIRTUAL-FIELDS
    (make-syntax-clause-spec #'aux.virtual-fields	0 +inf.0 0 +inf.0 '() '()	clause-arguments-parser:virtual-fields))

;;; --------------------------------------------------------------------

  (define-constant CLAUSE-SPEC-SINGLE-METHOD
    (make-syntax-clause-spec #'aux.method		0 +inf.0 2 +inf.0 '() '()	clause-arguments-parser:single-method))

  (define-constant CLAUSE-SPEC-SINGLE-METHOD-SYNTAX
    (make-syntax-clause-spec #'aux.method-syntax	0 +inf.0 2 +inf.0 '() '()	clause-arguments-parser:method-syntax))

  (define-constant CLAUSE-SPEC-MULTIPLE-METHODS
    (make-syntax-clause-spec #'aux.methods		0 +inf.0 0 +inf.0 '() '()	clause-arguments-parser:multiple-methods))

;;; --------------------------------------------------------------------

  (define-constant CLAUSE-SPEC-GETTER
    (make-syntax-clause-spec #'aux.getter		0 1 1 1 '() '()	clause-arguments-parser:getter))

  (define-constant CLAUSE-SPEC-SETTER
    (make-syntax-clause-spec #'aux.setter		0 1 1 1 '() '()	clause-arguments-parser:setter))

;;; --------------------------------------------------------------------

  (define-constant CLAUSE-SPEC-SATISFIES
    (make-syntax-clause-spec #'aux.satisfies		0 +inf.0 0 +inf.0 '() '()	clause-arguments-parser:satisfies))

  (define-constant CLAUSE-SPEC-SHADOWS
    (make-syntax-clause-spec #'aux.shadows		0 1 1 1 '() '()	clause-arguments-parser:shadows))

;;; --------------------------------------------------------------------

  ;;Parser functions for the clauses of the DEFINE-LABEL syntax.
  ;;
  (define-constant LABEL-CLAUSES-SPECS
    (syntax-clauses-validate-specs
     (list CLAUSE-SPEC-SINGLE-METHOD
	   CLAUSE-SPEC-VIRTUAL-FIELDS
	   CLAUSE-SPEC-MULTIPLE-METHODS
	   CLAUSE-SPEC-SINGLE-METHOD-SYNTAX
	   CLAUSE-SPEC-COMMON-PROTOCOL
	   CLAUSE-SPEC-PUBLIC-PROTOCOL
	   CLAUSE-SPEC-PREDICATE
	   CLAUSE-SPEC-GETTER
	   CLAUSE-SPEC-SETTER
	   CLAUSE-SPEC-PARENT
	   CLAUSE-SPEC-NONGENERATIVE
	   CLAUSE-SPEC-MAKER
	   CLAUSE-SPEC-SHADOWS
	   CLAUSE-SPEC-SATISFIES)))

  ;;Parser functions for the clauses of the DEFINE-class syntax.
  ;;
  (define-constant CLASS-CLAUSES-SPECS
    (syntax-clauses-validate-specs
     (list
      CLAUSE-SPEC-SINGLE-METHOD
      CLAUSE-SPEC-CONCRETE-FIELDS
      CLAUSE-SPEC-VIRTUAL-FIELDS
      CLAUSE-SPEC-MULTIPLE-METHODS
      CLAUSE-SPEC-SINGLE-METHOD-SYNTAX
      CLAUSE-SPEC-NONGENERATIVE
      CLAUSE-SPEC-PARENT
      CLAUSE-SPEC-COMMON-PROTOCOL
      CLAUSE-SPEC-PUBLIC-PROTOCOL
      CLAUSE-SPEC-SUPER-PROTOCOL
      CLAUSE-SPEC-GETTER
      CLAUSE-SPEC-SETTER
      CLAUSE-SPEC-MAKER
      CLAUSE-SPEC-FINALISER
      CLAUSE-SPEC-SATISFIES
      CLAUSE-SPEC-SEALED
      CLAUSE-SPEC-OPAQUE
      CLAUSE-SPEC-ABSTRACT)))

  ;;Parser functions for the clauses of the DEFINE-MIXIN syntax.
  ;;
  (define-constant MIXIN-CLAUSES-SPECS
    (syntax-clauses-validate-specs
     (list
      CLAUSE-SPEC-SINGLE-METHOD
      CLAUSE-SPEC-CONCRETE-FIELDS
      CLAUSE-SPEC-VIRTUAL-FIELDS
      CLAUSE-SPEC-MULTIPLE-METHODS
      CLAUSE-SPEC-PARENT
      CLAUSE-SPEC-COMMON-PROTOCOL
      CLAUSE-SPEC-PUBLIC-PROTOCOL
      CLAUSE-SPEC-GETTER
      CLAUSE-SPEC-SETTER
      CLAUSE-SPEC-NONGENERATIVE
      CLAUSE-SPEC-MAKER
      CLAUSE-SPEC-FINALISER
      CLAUSE-SPEC-ABSTRACT
      CLAUSE-SPEC-OPAQUE
      CLAUSE-SPEC-PREDICATE
      CLAUSE-SPEC-SATISFIES
      CLAUSE-SPEC-SEALED
      CLAUSE-SPEC-SHADOWS
      CLAUSE-SPEC-SINGLE-METHOD-SYNTAX
      CLAUSE-SPEC-SUPER-PROTOCOL)))

  #| end of module |# )


;;;; done

#| end of library |# )

;;; end of file
;; Local Variables:
;; coding: utf-8
;; eval: (put 'define-clause-parser/at-most-once-clause/single-argument 'scheme-indent-function 1)
;; eval: (put 'define-clause-parser/at-most-once-clause/no-argument 'scheme-indent-function 1)
;; eval: (put 'define-clause-parser/zero-or-more-clauses/zero-or-more-arguments 'scheme-indent-function 1)
;; eval: (put 'define-clause-parser/zero-or-more-clauses/single-argument 'scheme-indent-function 1)
;; End:
