;;;Copyright (c) 2010-2015 Marco Maggi <marco.maggi-ipsu@poste.it>
;;;Copyright (c) 2006, 2007 Abdulaziz Ghuloum and Kent Dybvig
;;;
;;;Permission is hereby granted, free of charge, to any person obtaining
;;;a  copy of  this  software and  associated  documentation files  (the
;;;"Software"), to  deal in the Software  without restriction, including
;;;without limitation  the rights to use, copy,  modify, merge, publish,
;;;distribute, sublicense,  and/or sell copies  of the Software,  and to
;;;permit persons to whom the Software is furnished to do so, subject to
;;;the following conditions:
;;;
;;;The  above  copyright notice  and  this  permission  notice shall  be
;;;included in all copies or substantial portions of the Software.
;;;
;;;THE  SOFTWARE IS  PROVIDED "AS  IS",  WITHOUT WARRANTY  OF ANY  KIND,
;;;EXPRESS OR  IMPLIED, INCLUDING BUT  NOT LIMITED TO THE  WARRANTIES OF
;;;MERCHANTABILITY,    FITNESS   FOR    A    PARTICULAR   PURPOSE    AND
;;;NONINFRINGEMENT.  IN NO EVENT  SHALL THE AUTHORS OR COPYRIGHT HOLDERS
;;;BE LIABLE  FOR ANY CLAIM, DAMAGES  OR OTHER LIABILITY,  WHETHER IN AN
;;;ACTION OF  CONTRACT, TORT  OR OTHERWISE, ARISING  FROM, OUT OF  OR IN
;;;CONNECTION  WITH THE SOFTWARE  OR THE  USE OR  OTHER DEALINGS  IN THE
;;;SOFTWARE.


;;;; stuff

(import (prefix (rnrs syntax-case) sys.)
  (only (psyntax.syntax-utilities)
	generate-temporaries))

(define-syntax (define-core-transformer stx)
  (sys.syntax-case stx ()
    ((_ (?who ?input-form.stx ?lexenv.run ?lexenv.expand) ?body0 ?body ...)
     (let* ((who.sym (sys.syntax->datum (sys.syntax ?who)))
	    (who.str (symbol->string who.sym))
	    (who.out (string->symbol (string-append who.str "-transformer"))))
       (sys.with-syntax
	   ((WHO    (sys.datum->syntax (sys.syntax ?who) who.out))
	    (SYNNER (sys.datum->syntax (sys.syntax ?who) '%synner)))
	 (sys.syntax
	  (define (WHO ?input-form.stx ?lexenv.run ?lexenv.expand)
	    (with-who ?who
	      (let-syntax
		  ((SYNNER (syntax-rules ()
			     ((_ ?message)
			      (syntax-violation __who__ ?message ?input-form.stx))
			     ((_ ?message ?subform)
			      (syntax-violation __who__ ?message ?input-form.stx ?subform))
			     )))
		?body0 ?body ...)))))))
    ))

(module ($map-in-order
	 $map-in-order1)

  (case-define $map-in-order
    ((func ell)
     ($map-in-order1 func ell))
    ((func . ells)
     (if (null? ells)
	 '()
       (let recur ((ells ells))
	 (if (pair? ($car ells))
	     (let* ((cars ($map-in-order1 $car ells))
		    (cdrs ($map-in-order1 $cdr ells))
		    (head (apply func cars)))
	       (cons head (recur cdrs)))
	   '())))))

  (define-syntax-rule ($map-in-order1 ?func ?ell)
    (let recur ((ell ?ell))
      (if (pair? ell)
	  (let ((head (?func ($car ell))))
	    (cons head (recur ($cdr ell))))
	ell)))

  #| end of module |# )

;;; --------------------------------------------------------------------

(define-auxiliary-syntaxes object-type vicare-struct-type)

(define-syntax (case-object-type-binding stx)
  ;;This syntax is meant to be used as follows:
  ;;
  ;;   (define-constant __who__ ...)
  ;;   (syntax-match input-stx ()
  ;;     ((_ ?type-id)
  ;;      (identifier? ?type-id)
  ;;      (case-object-type-binding __who__ input-stx ?type-id lexenv.run
  ;;        ((object-type)
  ;;         ...)
  ;;        ((vicare-struct-type)
  ;;         ...)
  ;;        ((tag-type-spec)
  ;;         ...)))
  ;;     )
  ;;
  ;;where  ?TYPE-ID  is  meant to  be  an  identifier  bound  to a  R6RS  record-type
  ;;descriptor or Vicare's struct-type descriptor.
  ;;
  (sys.syntax-case stx (r6rs-record-type vicare-struct-type tag-type-spec)
    ((_ (?who ?input-stx ?type-id ?lexenv)
	((object-type)		?object-type-body0 ?object-type-body ...)
	((vicare-struct-type)	?struct-body0 ?struct-body ...)
	((tag-type-spec)	?spec-body0   ?spec-body   ...))
     (and (sys.identifier? (sys.syntax ?who))
	  (sys.identifier? (sys.syntax ?expr-stx))
	  (sys.identifier? (sys.syntax ?type-id))
	  (sys.identifier? (sys.syntax ?lexenv)))
     (sys.syntax
      (begin
	(visit-library-of-imported-syntactic-binding ?who ?input-stx ?type-id ?lexenv)
	(let* ((label    (id->label/or-error ?who ?input-stx ?type-id))
	       (binding  (label->syntactic-binding-descriptor label ?lexenv)))
	  (cond ((object-type-name-binding-descriptor? binding)
		 ?object-type-body0 ?object-type-body ...)
		((struct-type-name-binding-descriptor? binding)
		 ?struct-body0 ?struct-body ...)
		((identifier-tag-type-spec ?type-id)
		 ?spec-body0 ?spec-body ...)
		(else
		 (syntax-violation ?who
		   "neither a struct type nor an R6RS record type nor a spec type"
		   ?input-stx ?type-id)))))))

    ((_ (?who ?input-stx ?type-id ?lexenv ?binding)
	((object-type)		?object-type-body0   ?object-type-body   ...)
	((vicare-struct-type)	?struct-body0 ?struct-body ...)
	((tag-type-spec)	?spec-body0   ?spec-body   ...))
     (and (sys.identifier? (sys.syntax ?who))
	  (sys.identifier? (sys.syntax ?expr-stx))
	  (sys.identifier? (sys.syntax ?type-id))
	  (sys.identifier? (sys.syntax ?lexenv)))
     (sys.syntax
      (begin
	(visit-library-of-imported-syntactic-binding ?who ?input-stx ?type-id ?lexenv)
	(let* ((label     (id->label/or-error ?who ?input-stx ?type-id))
	       (?binding  (label->syntactic-binding-descriptor label ?lexenv)))
	  (cond ((object-type-name-binding-descriptor? ?binding)
		 ?object-type-body0 ?object-type-body ...)
		((struct-type-name-binding-descriptor? ?binding)
		 ?struct-body0 ?struct-body ...)
		((identifier-tag-type-spec ?type-id)
		 ?spec-body0 ?spec-body ...)
		(else
		 (syntax-violation ?who
		   "neither a struct type nor an R6RS record type"
		   ?input-stx ?type-id)))))))
    ))


;;;; helpers: struct types

(define (%struct-field-name->struct-field-idx who input-form.stx field-names field-id)
  ;;Given a list  of symbols FIELD-NAMES representing a struct's  list of field names
  ;;and an identifier FIELD-ID representing the name  of a field: return the index of
  ;;the selected field in the list.
  ;;
  (define field-sym (identifier->symbol field-id))
  (let loop ((i 0) (ls field-names))
    (if (pair? ls)
	(if (eq? field-sym ($car ls))
	    i
	  (loop ($fxadd1 i) ($cdr ls)))
      (syntax-violation who "invalid struct type field name" input-form.stx field-id))))

(define (%struct-type-id->std who input-form.stx type-id lexenv.run)
  ;;Given the syntactic identifier TYPE-ID  representing a struct-type name and bound
  ;;to a  struct-type descriptor (STD):  find its  label, then its  syntactic binding
  ;;descriptor,  finally return  the struct-type  descriptor itself.   If no  binding
  ;;captures the  identifier or  the binding  does not  describe a  struct-type name:
  ;;raise an exception.
  ;;
  (let* ((label (id->label/or-error who input-form.stx type-id))
	 (descr (label->syntactic-binding-descriptor label lexenv.run)))
    (if (struct-type-name-binding-descriptor? descr)
	(struct-type-name-binding-descriptor.type-descriptor descr)
      (syntax-violation who "not a struct type" input-form.stx type-id))))


;;The  function   CORE-MACRO-TRANSFORMER  maps   symbols  representing
;;non-core macros to their macro transformers.
;;
;;We distinguish between "non-core macros" and "core macros".
;;
;;NOTE This  module is very  long, so it  is split into  multiple code
;;pages.  (Marco Maggi; Sat Apr 27, 2013)
;;
(define* (core-macro-transformer name)
  (case name
    ((quote)					quote-transformer)
    ((lambda)					lambda-transformer)
    ((case-lambda)				case-lambda-transformer)
    ((internal-lambda)				internal-lambda-transformer)
    ((internal-case-lambda)			internal-case-lambda-transformer)
    ((let)					let-transformer)
    ((letrec)					letrec-transformer)
    ((letrec*)					letrec*-transformer)
    ((if)					if-transformer)
    ((foreign-call)				foreign-call-transformer)
    ((syntax-case)				syntax-case-transformer)
    ((syntax)					syntax-transformer)
    ((fluid-let-syntax)				fluid-let-syntax-transformer)
    ((splice-first-expand)			splice-first-expand-transformer)
    ((internal-body)				internal-body-transformer)
    ((predicate-procedure-argument-validation)	predicate-procedure-argument-validation-transformer)
    ((predicate-return-value-validation)	predicate-return-value-validation-transformer)

    ((struct-type-descriptor)			struct-type-descriptor-transformer)

    ((record-type-descriptor)			record-type-descriptor-transformer)
    ((record-constructor-descriptor)		record-constructor-descriptor-transformer)

    ((type-descriptor)				type-descriptor-transformer)
    ((new)					new-transformer)
    ((delete)					delete-transformer)
    ((is-a?)					is-a?-transformer)
    ((slot-ref)					slot-ref-transformer)
    ((slot-set!)				slot-set!-transformer)
    ((method-call)				method-call-transformer)

    ((tag-predicate)				tag-predicate-transformer)
    ((tag-procedure-argument-validator)		tag-procedure-argument-validator-transformer)
    ((tag-return-value-validator)		tag-return-value-validator-transformer)
    ((tag-assert)				tag-assert-transformer)
    ((tag-assert-and-return)			tag-assert-and-return-transformer)
    ((tag-accessor)				tag-accessor-transformer)
    ((tag-mutator)				tag-mutator-transformer)
    ((tag-getter)				tag-getter-transformer)
    ((tag-setter)				tag-setter-transformer)
    ((tag-dispatch)				tag-dispatch-transformer)
    ((tag-cast)					tag-cast-transformer)
    ((tag-unsafe-cast)				tag-unsafe-cast-transformer)

    ((type-of)					type-of-transformer)
    ((expansion-of)				expansion-of-transformer)
    ((expansion-of*)				expansion-of*-transformer)
    ((visit-code-of)				visit-code-of-transformer)
    ((optimisation-of)				optimisation-of-transformer)
    ((further-optimisation-of)			further-optimisation-of-transformer)
    ((optimisation-of*)				optimisation-of*-transformer)
    ((further-optimisation-of*)			further-optimisation-of*-transformer)
    ((assembly-of)				assembly-of-transformer)

    (else
     (assertion-violation/internal-error __who__
       "cannot find transformer" name))))


(module PROCESSING-UTILITIES-FOR-LISTS-OF-BINDINGS
  (%expand-rhs*
   %select-lhs-declared-tag-or-rhs-inferred-tag
   %compose-lhs-specification)
  ;;In  this  module  we  assume  the  argument  INPUT-FORM.STX  can  be  matched  by
  ;;SYNTAX-MATCH patterns like:
  ;;
  ;;  (let            ((?lhs* ?rhs*) ...) . ?body*)
  ;;  (let     ?recur ((?lhs* ?rhs*) ...) . ?body*)
  ;;
  ;;where the ?LHS identifiers can be tagged or not; we have to remember that LET* is
  ;;just expanded in  a set of nested  LET syntaxes.  We assume that  the ?LHS syntax
  ;;objects have been processed with:
  ;;
  ;;   (receive (lhs*.id lhs*.tag)
  ;;       (parse-list-of-tagged-bindings ?lhs* input-form.stx)
  ;;     ...)
  ;;
  ;;We want to provide helper functions to handle the following situations.
  ;;
  ;;
  ;;RHS tag propagation
  ;;-------------------
  ;;
  ;;When we write:
  ;;
  ;;   (let ((a 1)) . ?body)
  ;;
  ;;the identifier A is the left-hand side of the binding and the expression 1 is the
  ;;right-hand side  of the  binding; since  A is  untagged in  the source  code, the
  ;;expander will tag it, by default, with "<top>".
  ;;
  ;;* If  the option  RHS-TAG-PROPAGATION? is  turned OFF: the  identifier A  is left
  ;;  tagged with "<top>".  We are free to assign any object to A, mutating the bound
  ;;  value  multiple times with  objects of different  tag; this is  standard Scheme
  ;;  behaviour.
  ;;
  ;;* When the option RHS-TAG-PROPAGATION? is turned ON: the expander infers that the
  ;;  RHS has  signature "(<fixnum>)", so it  propagates the tag from the  RHS to the
  ;;  LHS overriding "<top>" with "<fixnum>".  This  will cause an error to be raised
  ;;  if we mutate the binding assigning to A an object whose tag is not "<fixnum>".
  ;;
  ;;
  ;;RHS signature validation
  ;;------------------------
  ;;
  ;;When we write:
  ;;
  ;;   (let (({a <fixnum>} 1)) . ?body)
  ;;
  ;;the identifier A is the left-hand side of the binding and the expression 1 is the
  ;;right-hand side of the binding; A is explicitly tagged with "<fixnum>".
  ;;
  ;;We want to make  sure that the RHS expression returns a  single return value with
  ;;signature "<fixnum>"; so  the RHS's retvals signature must  be "(<fixnum>)".  All
  ;;the work  is done  by the  macro TAG-ASSERT-AND-RETURN, so  we transform  the RHS
  ;;expression as if the input form is:
  ;;
  ;;   (let (({a <fixnum>} (tag-assert-and-return (<fixnum>) 1))) . ?body)
  ;;
  ;;and expand the new RHS:
  ;;
  ;;   (tag-assert-and-return (<fixnum>) 1)
  ;;
  ;;if the expander  determines that the signature  of 1 is "(<fixnum>)",  the RHS is
  ;;transformed at expand-time into just "1";  otherwise a run-time object type check
  ;;is inserted.  In  any case we can  be sure at both expand-time  and run-time that
  ;;the signature  of the  identifier A  is correct, otherwise  an exception  will be
  ;;raised before expanding or running the ?BODY.
  ;;

  (define* (%expand-rhs* input-form.stx lexenv.run lexenv.expand
			 lhs*.tag rhs*.stx)
    ;;Expand  a  list  of  right-hand  sides  from  bindings  in  the  syntax  object
    ;;INPUT-FORM.STX; the context  of the expansion is described by  the given LEXENV
    ;;arguments.
    ;;
    ;;LHS*.TAG must be a list of tag identifiers representing the tags resulting from
    ;;parsing the left-hand sides in the source code.
    ;;
    ;;RHS*.STX must be a list of syntax objects representing the expressions from the
    ;;right-hand sides.
    ;;
    ;;Return 2 values: a list of  PSI structures representing the expanded right-hand
    ;;sides; a list of tag identifiers  representing the signatures of the right-hand
    ;;sides.  If  the RHS  are found,  at expand-time,  to return  zero, two  or more
    ;;values: a synatx violation is raised.
    ;;
    ;;The tag identifiers  in the second returned  value can be used  to override the
    ;;ones in LHS*.TAG.
    ;;
    (define rhs*.psi
      (map (lambda (rhs.stx lhs.tag)
	     ;;If LHS.TAG is "<top>", we still want to use the assert and return form
	     ;;to  make sure  that  a single  value is  returned.   If the  signature
	     ;;validation  succeeds at  expand-time:  the returned  PSI  has the  RHS
	     ;;signature  inferred from  the original  RHS.STX, not  "(<top>)".  This
	     ;;allows us to propagate the tag from RHS to LHS.
	     (chi-expr (bless
			`(tag-assert-and-return (,lhs.tag) ,rhs.stx))
		       lexenv.run lexenv.expand))
	rhs*.stx lhs*.tag))
    (define rhs*.sig
      (map psi-retvals-signature rhs*.psi))
    (define rhs*.tag
      (map (lambda (sig)
	     (syntax-match (retvals-signature-tags sig) ()
	       ((?tag)
		;;Single return value: good.
		?tag)
	       (_
		;;If we  are here it  means that the TAG-ASSERT-AND-RETURN  above has
		;;misbehaved.
		(assertion-violation/internal-error __who__
		  "invalid retvals signature" (syntax->datum input-form.stx) sig))))
	rhs*.sig))
    (values rhs*.psi rhs*.tag))

  (define (%select-lhs-declared-tag-or-rhs-inferred-tag lhs*.tag rhs*.inferred-tag)
    ;;Given  a list  of  LHS tags  LHS*.tag  from the  source code  and  the list  of
    ;;corresponding RHS inferred tags RHS*.INFERRED-TAG: return a list of LHS tags to
    ;;replace LHS*.TAG.
    ;;
    (if (option.typed-language.rhs-tag-propagation?)
	(map (lambda (lhs.tag rhs.inferred-tag)
	       (if (top-tag-id? lhs.tag)
		   (if (top-tag-id? rhs.inferred-tag)
		       lhs.tag
		     rhs.inferred-tag)
		 lhs.tag))
	  lhs*.tag rhs*.inferred-tag)
      lhs*.tag))

  (define (%compose-lhs-specification lhs*.id lhs*.tag rhs*.inferred-tag)
    ;;For every LHS identifier build a tagged identifier syntax:
    ;;
    ;;   (brace ?lhs.id ?tag)
    ;;
    ;;in which ?TAG is either the original one specified in the LET syntax or the one
    ;;inferred by expanding the RHS.  If there  is no tag explicitly specified in the
    ;;LET syntax we put in the inferred one.
    ;;
    (if (option.typed-language.rhs-tag-propagation?)
	(map (lambda (lhs.id lhs.tag rhs.tag)
	       (bless
		`(brace ,lhs.id ,(if (top-tag-id? lhs.tag)
				     (if (top-tag-id? rhs.tag)
					 lhs.tag
				       rhs.tag)
				   lhs.tag))))
	  lhs*.id lhs*.tag rhs*.inferred-tag)
      (map (lambda (lhs.id lhs.tag)
	     (bless
	      `(brace ,lhs.id ,lhs.tag)))
	lhs*.id lhs*.tag)))

  #| end of module: PROCESSING-UTILITIES-FOR-LISTS-OF-BINDINGS |# )


;;;; module core-macro-transformer: IF

(define-core-transformer (if input-form.stx lexenv.run lexenv.expand)
  ;;Transformer function used to expand R6RS  IF syntaxes from the top-level built in
  ;;environment.  Expand the syntax object INPUT-FORM.STX in the context of the given
  ;;LEXENV; return a PSI struct.
  ;;
  (syntax-match input-form.stx ()
    ((_ ?test ?consequent ?alternate)
     (let ((test.psi       (chi-expr ?test       lexenv.run lexenv.expand))
	   (consequent.psi (chi-expr ?consequent lexenv.run lexenv.expand))
	   (alternate.psi  (chi-expr ?alternate  lexenv.run lexenv.expand)))
       (make-psi input-form.stx
		 (build-conditional no-source
		   (psi-core-expr test.psi)
		   (psi-core-expr consequent.psi)
		   (psi-core-expr alternate.psi))
		 (retvals-signature-common-ancestor (psi-retvals-signature consequent.psi)
						    (psi-retvals-signature alternate.psi)))))
    ((_ ?test ?consequent)
     (let ((test.psi       (chi-expr ?test       lexenv.run lexenv.expand))
	   (consequent.psi (chi-expr ?consequent lexenv.run lexenv.expand)))
       ;;We build  code to  make the  one-armed IF  return void  if the  alternate is
       ;;unspecified; according  to R6RS:
       ;;
       ;;* If  the test succeeds: the  return value must  be the return value  of the
       ;;  consequent.
       ;;
       ;;* If the  test fails and there  *is* an alternate: the return  value must be
       ;;  the return value of the alternate.
       ;;
       ;;* If the test fails and there is *no* alternate: this syntax has unspecified
       ;;  return values.
       ;;
       ;;Notice that one-armed IF  is also used in the expansion  of WHEN and UNLESS;
       ;;R6RS states that, for those syntaxes, when the body *is* executed the return
       ;;value must be the return value of the last expression in the body.
       (make-psi input-form.stx
		 (build-conditional no-source
		   (psi-core-expr test.psi)
		   (psi-core-expr consequent.psi)
		   (build-void))
		 (make-retvals-signature-single-top))))
    ))


;;;; module core-macro-transformer: QUOTE

(define-core-transformer (quote input-form.stx lexenv.run lexenv.expand)
  ;;Transformer function used to expand R6RS  QUOTE syntaxes from the top-level built
  ;;in environment.   Expand the syntax object  INPUT-FORM.STX in the context  of the
  ;;given LEXENV; return a PSI struct.
  ;;
  (syntax-match input-form.stx ()
    ((_ ?datum)
     (let ((datum (syntax->datum ?datum)))
       (make-psi input-form.stx
		 (build-data no-source
		   datum)
		 (retvals-signature-of-datum datum))))
    ))


;;;; module core-macro-transformer: LAMBDA and CASE-LAMBDA, INTERNAL-LAMBDA and INTERNAL-CASE-LAMBDA

(define-core-transformer (case-lambda input-form.stx lexenv.run lexenv.expand)
  ;;Transformer function used to expand  R6RS CASE-LAMBDA syntaxes from the top-level
  ;;built in environment.  Expand the syntax  object INPUT-FORM.STX in the context of
  ;;the given LEXENV; return an PSI struct.
  ;;
  (syntax-match input-form.stx ()
    ((_ (?formals* ?body* ?body** ...) ...)
     (chi-case-lambda input-form.stx lexenv.run lexenv.expand
		      '(safe) ?formals* (map cons ?body* ?body**)))
    ))

(define-core-transformer (lambda input-form.stx lexenv.run lexenv.expand)
  ;;Transformer function used to expand R6RS LAMBDA syntaxes from the top-level built
  ;;in environment.   Expand the syntax object  INPUT-FORM.STX in the context  of the
  ;;given LEXENV; return a PSI struct.
  ;;
  (syntax-match input-form.stx ()
    ((_ ?formals ?body ?body* ...)
     (chi-lambda input-form.stx lexenv.run lexenv.expand
		 '(safe) ?formals (cons ?body ?body*)))
    ))

(define-core-transformer (internal-case-lambda input-form.stx lexenv.run lexenv.expand)
  ;;Transformer function  used to expand Vicare's  INTERNAL-CASE-LAMBDA syntaxes from
  ;;the top-level built  in environment.  Expand the syntax  object INPUT-FORM.STX in
  ;;the context of the given LEXENV; return an PSI struct.
  ;;
  (syntax-match input-form.stx ()
    ((_ ?attributes (?formals* ?body* ?body** ...) ...)
     (chi-case-lambda input-form.stx lexenv.run lexenv.expand
		      ?attributes ?formals* (map cons ?body* ?body**)))
    ))

(define-core-transformer (internal-lambda input-form.stx lexenv.run lexenv.expand)
  ;;Transformer function  used to expand  Vicare's INTERNAL-LAMBDA syntaxes  from the
  ;;top-level built in  environment.  Expand the syntax object  INPUT-FORM.STX in the
  ;;context of the given LEXENV; return a PSI struct.
  ;;
  (syntax-match input-form.stx ()
    ((_ ?attributes ?formals ?body ?body* ...)
     (chi-lambda input-form.stx lexenv.run lexenv.expand
		 ?attributes ?formals (cons ?body ?body*)))
    ))


;;;; module core-macro-transformer: LET

(module (let-transformer)
  ;;Transformer function used  to expand R6RS LET macros with  Vicare extensions from
  ;;the top-level built  in environment.  Expand the syntax  object INPUT-FORM.STX in
  ;;the context of the given LEXENV; return an PSI struct.
  ;;
  ;;In practice, below we convert the UNnamed standard syntax:
  ;;
  ;;   (let ((?lhs ?rhs) ...) . ?body)
  ;;
  ;;into the core language syntax:
  ;;
  ;;   (let ((?lhs ?rhs) ...) . ?body)
  ;;
  ;;and the named standard syntax:
  ;;
  ;;   (let ?recur ((?lhs ?rhs) ...) . ?body)
  ;;
  ;;into the extended syntax:
  ;;
  ;;   (internal-body
  ;;     (define (?recur ?lhs ...) . ?body)
  ;;     (?recur ?rhs ...))
  ;;
  ;;for further expansion, notice that the latter allows ?RECUR to be tagged with the
  ;;return values of the LET form.
  ;;
  ;;When expanding UNnamed LET syntaxes:
  ;;
  ;;1. We parse the LHS tagged identifiers to acquire the declared tags.
  ;;
  ;;2. We expand the ?RHS expression to acquire their retvals signature.
  ;;
  ;;3. We  select the  more specific  LHS tag between  the declared  LHS one  and the
  ;;   inferred RHS one.
  ;;
  ;;3. We expand the body with the LHS identifiers correctly tagged.
  ;;
  ;;This way if we write:
  ;;
  ;;   (let ((a 1)) . ?body)
  ;;
  ;;this is what happens:
  ;;
  ;;1..The identifier A is first tagged with "<top>".
  ;;
  ;;2..The expander figures out that the RHS's signature is "(<fixnum>)".
  ;;
  ;;3..The expander overrides the tag of A to be "<fixnum>".
  ;;
  ;;4..In the ?BODY the identifier A is  tagged as "<fixnum>", so the extended syntax
  ;;   is available.
  ;;
  ;;On the other hand if we write:
  ;;
  ;;   (let (({a <exact-integer>} 1)) . ?body)
  ;;
  ;;we get an expansion that is equivalent to:
  ;;
  ;;   (let (({a <exact-integer>} (tag-assert-and-return (<exact-integer>) 1)))
  ;;     . ?body)
  ;;
  ;;so  the type  of the  RHS expression  is validated  either at  expand-time or  at
  ;;run-time.
  ;;
  ;;HISTORICAL NOTE In the original Ikarus code, the UNnamed LET syntax:
  ;;
  ;;   (let ((?lhs ?rhs) ...) . ?body)
  ;;
  ;;was transformed into:
  ;;
  ;;   ((lambda (?lhs ...) . ?body) ?rhs ...)
  ;;
  ;;and the named syntax:
  ;;
  ;;   (let ?recur ((?lhs ?rhs) ...) . ?body)
  ;;
  ;;into:
  ;;
  ;;   ((letrec ((?recur (lambda (?lhs ...) . ?body))) ?recur) ?rhs ...)
  ;;
  ;;such transformations are fine for an  UNtagged language.  In a tagged language we
  ;;want to use types  whenever possible, and this means to use  the DEFINE syntax to
  ;;define both a safe and an unsafe function.  (Marco Maggi; Sun Apr 27, 2014)
  ;;
  (define-syntax __who__
    (identifier-syntax 'let))

  (import PROCESSING-UTILITIES-FOR-LISTS-OF-BINDINGS)

  (define* (let-transformer input-form.stx lexenv.run lexenv.expand)
    (syntax-match input-form.stx ()
      ((_ ((?lhs* ?rhs*) ...) ?body ?body* ...)
       (receive (lhs*.id lhs*.declared-tag)
	   (parse-list-of-tagged-bindings ?lhs* input-form.stx)
	 (receive (rhs*.psi rhs*.inferred-tag)
	     (%expand-rhs* input-form.stx lexenv.run lexenv.expand lhs*.declared-tag ?rhs*)
	   (let ((lhs*.lex  (map generate-lexical-gensym lhs*.id))
		 (lhs*.lab  (map generate-label-gensym   lhs*.id)))
	     (let ((lhs*.inferred-tag (%select-lhs-declared-tag-or-rhs-inferred-tag lhs*.declared-tag rhs*.inferred-tag)))
	       (map set-label-tag! lhs*.id lhs*.lab lhs*.inferred-tag))
	     (let* ((body.stx   (cons ?body ?body*))
		    (body.psi   (%expand-unnamed-let-body body.stx lexenv.run lexenv.expand
							  lhs*.id lhs*.lab lhs*.lex))
		    (body.core  (psi-core-expr body.psi))
		    (rhs*.core  (map psi-core-expr rhs*.psi)))
	       (make-psi input-form.stx
			 (build-let (syntax-annotation input-form.stx)
				    lhs*.lex rhs*.core
				    body.core)
			 (psi-retvals-signature body.psi)))))))

      ((_ ?recur ((?lhs* ?rhs*) ...) ?body ?body* ...)
       ;;NOTE We want an implementation in which:  when BREAK is not used, the escape
       ;;function is  never referenced, so  the compiler can remove  CALL/CC.  Notice
       ;;that here binding  CONTINUE makes no sense, because calling  ?RECUR does the
       ;;job.
       (receive (recur.id recur.tag)
	   (parse-tagged-identifier-syntax ?recur)
	 (chi-expr (bless
		    `(internal-body
		       (define (,?recur . ,?lhs*)
			 ;;FIXME  We do  not want  "__who__" and  RETURN to  be bound
			 ;;here.  (Marco Maggi; Wed Jan 21, 2015)
			 ,?body . ,?body*)
		       (,recur.id . ,?rhs*)))
		   lexenv.run lexenv.expand)))

      (_
       (syntax-violation __who__ "invalid syntax" input-form.stx))))

  (define (%expand-unnamed-let-body body.stx lexenv.run lexenv.expand
				    lhs*.id lhs*.lab lhs*.lex)
    ;;Generate what  is needed  to create a  lexical contour: a  RIB and  an extended
    ;;lexical environment in which to evaluate  the body.  Expand the body and return
    ;;the corresponding PSI struct.
    (let ((body.stx^    (push-lexical-contour
			    (make-rib/from-identifiers-and-labels lhs*.id lhs*.lab)
			  body.stx))
	  (lexenv.run^  (lexenv-add-lexical-var-bindings lhs*.lab lhs*.lex lexenv.run)))
      (chi-internal-body body.stx^ lexenv.run^ lexenv.expand)))

  #| end of module: LET-TRANSFORMER |# )


;;;; module core-macro-transformer: LETREC and LETREC*

(module (letrec-transformer letrec*-transformer)
  ;;Transformer  functions  used to  expand  LETREC  and  LETREC* syntaxes  from  the
  ;;top-level built in  environment.  Expand the syntax object  INPUT-FORM.STX in the
  ;;context of the given LEXENV; return a PSI struct.
  ;;
  ;;In practice, below we convert the standard syntaxes:
  ;;
  ;;   (letrec  ((?lhs ?rhs) ...) . ?body)
  ;;   (letrec* ((?lhs ?rhs) ...) . ?body)
  ;;
  ;;into the core language syntaxes:
  ;;
  ;;   (letrec  ((?lhs ?rhs) ...) . ?body)
  ;;   (letrec* ((?lhs ?rhs) ...) . ?body)
  ;;
  ;;NOTE Unfortunately, with recursive bindings we cannot implement coherent RHS type
  ;;propagation.  Let's think of:
  ;;
  ;;   (letrec ((a (some-stuff ... a ...)))
  ;;     ?body)
  ;;
  ;;we could infer  the returned type of the  RHS and use it while  expand the ?BODY,
  ;;but what about the RHS?  While expanding the RHS the identifier A would be tagged
  ;;as "<top>" and while expanding the ?BODY it would be tagged as "<whatever>"; this
  ;;is incoherent.
  ;;
  (define-syntax __who__
    (identifier-syntax 'letrec-transformer))

  (define (letrec-transformer input-form.stx lexenv.run lexenv.expand)
    ;;Transformer function used to expand LETREC syntaxes from the top-level built in
    ;;environment.  Expand  the syntax  object INPUT-FORM.STX in  the context  of the
    ;;given LEXENV; return a PSI struct.
    ;;
    (%letrec-helper input-form.stx lexenv.run lexenv.expand build-letrec))

  (define (letrec*-transformer input-form.stx lexenv.run lexenv.expand)
    ;;Transformer function used  to expand LETREC* syntaxes from  the top-level built
    ;;in environment.  Expand the syntax object  INPUT-FORM.STX in the context of the
    ;;given LEXENV; return a PSI struct.
    ;;
    (%letrec-helper input-form.stx lexenv.run lexenv.expand build-letrec*))

  (define* (%letrec-helper input-form.stx lexenv.run lexenv.expand core-lang-builder)
    (import PROCESSING-UTILITIES-FOR-LISTS-OF-BINDINGS)
    (syntax-match input-form.stx ()
      ((_ ((?lhs* ?rhs*) ...) ?body ?body* ...)
       ;;Check that the binding names are identifiers and without duplicates.
       (receive (lhs*.id lhs*.tag)
	   (parse-list-of-tagged-bindings ?lhs* input-form.stx)
	 ;;Generate unique variable names and labels for the LETREC bindings.
	 (let ((lhs*.lex (map generate-lexical-gensym lhs*.id))
	       (lhs*.lab (map generate-label-gensym       lhs*.id)))
	   (map set-label-tag! lhs*.id lhs*.lab lhs*.tag)
	   ;;Generate what  is needed  to create  a lexical contour:  a <RIB>  and an
	   ;;extended lexical  environment in which  to evaluate both  the right-hand
	   ;;sides and the body.
	   ;;
	   ;;NOTE The region of all the  LETREC and LETREC* bindings includes all the
	   ;;right-hand sides.
	   (let* ((rib         (make-rib/from-identifiers-and-labels lhs*.id lhs*.lab))
		  (lexenv.run^ (lexenv-add-lexical-var-bindings lhs*.lab lhs*.lex lexenv.run))
		  (rhs*.psi    (%expand-rhs input-form.stx lexenv.run^ lexenv.expand
					    lhs*.lab lhs*.tag ?rhs* rib))
		  (body.psi    (chi-internal-body (push-lexical-contour rib
						    (cons ?body ?body*))
						  lexenv.run^ lexenv.expand)))
	     (let* ((rhs*.core (map psi-core-expr rhs*.psi))
		    (body.core (psi-core-expr body.psi))
		    ;;Build the LETREC or LETREC* expression in the core language.
		    (expr.core (core-lang-builder no-source
				 lhs*.lex
				 rhs*.core
				 body.core)))
	       (make-psi input-form.stx expr.core
			 (psi-retvals-signature body.psi)))))))
      ))

  (define (%expand-rhs input-form.stx lexenv.run lexenv.expand
		       lhs*.lab lhs*.tag rhs*.stx rib)
    ;;Expand  the  right  hand sides  in  RHS*.STX  and  return  a list  holding  the
    ;;corresponding PSI structures.
    ;;
    ($map-in-order
	(lambda (rhs.stx lhs.lab lhs.tag)
	  (receive-and-return (rhs.psi)
	      ;;The LHS*.ID and LHS*.LAB  have been added to the rib,  and the rib is
	      ;;pushed on  the RHS.STX.  So,  while the specific  identifiers LHS*.ID
	      ;;are unbound (because they do not  contain the rib), any occurrence of
	      ;;the binding identifiers in the RHS.STX  is captured by the binding in
	      ;;the rib.
	      ;;
	      ;;If LHS.TAG  is "<top>", we  still want to  use the assert  and return
	      ;;form to make sure that a  single value is returned.  If the signature
	      ;;validation succeeds at expand-time: the returned PSI has the original
	      ;;RHS signature,  not "(<top>)".  This  allows us to propagate  the tag
	      ;;from RHS to LHS.
	      (chi-expr (push-lexical-contour rib
			  (bless
			   `(tag-assert-and-return (,lhs.tag) ,rhs.stx)))
			lexenv.run lexenv.expand)
	    ;;If the  LHS is untagged:  perform tag propatation  from the RHS  to the
	    ;;LHS.
	    (when (and (option.typed-language.rhs-tag-propagation?)
		       (top-tag-id? lhs.tag))
	      (syntax-match (retvals-signature-tags (psi-retvals-signature rhs.psi)) ()
		((?tag)
		 ;;Single return value: good.
		 (override-label-tag! lhs.lab ?tag))
		(_
		 ;;If we are  here it means that the  TAG-ASSERT-AND-RETURN above has
		 ;;misbehaved.
		 (assertion-violation/internal-error __who__
		   "invalid retvals signature"
		   (syntax->datum input-form.stx)
		   (psi-retvals-signature rhs.psi)))))))
      rhs*.stx lhs*.lab lhs*.tag))

  #| end of module |# )


;;;; module core-macro-transformer: FLUID-LET-SYNTAX

(define-core-transformer (fluid-let-syntax input-form.stx lexenv.run lexenv.expand)
  ;;Transformer function used to expand  FLUID-LET-SYNTAX syntaxes from the top-level
  ;;built in environment.  Expand the syntax  object INPUT-FORM.STX in the context of
  ;;the given LEXENV; return a PSI struct.
  ;;
  ;;FLUID-LET-SYNTAX is similar,  but not equal, to LET-SYNTAX;  rather than defining
  ;;new ?LHS bindings, it temporarily rebinds  the keywords to new transformers while
  ;;expanding  the ?BODY  forms.   The given  ?LHS  must be  already  bound to  fluid
  ;;syntaxes defined by DEFINE-FLUID-SYNTAX.
  ;;
  ;;There   are   two   differences    between   FLUID-LET-SYNTAX   and   LET-SYNTAX:
  ;;FLUID-LET-SYNTAX must appear in expression context only; the internal ?BODY forms
  ;;are *not* spliced in the enclosing body.
  ;;
  ;;NOTE We would truly like to splice  the inner body forms in the surrounding body,
  ;;so that  this syntax could  act like LET-SYNTAX, which  is useful; but  we really
  ;;cannot do it with this implementation of the expander algorithm.  This is because
  ;;LET-SYNTAX both creates a new rib and adds new id/label entries to it, and pushes
  ;;label/descriptor  entries to  the  LEXENV; instead  FLUID-LET-SYNTAX only  pushes
  ;;entries to the LEXENV:  there is no way to keep the  fluid LEXENV entries visible
  ;;only to a subsequence of forms in a body.  (Marco Maggi; Tue Feb 18, 2014)
  ;;
  (define (transformer input-form.stx)
    (syntax-match input-form.stx ()
      ((_ ((?lhs* ?rhs*) ...) ?body ?body* ...)
       ;;Check that the ?LHS* are all identifiers with no duplicates.
       (unless (valid-bound-ids? ?lhs*)
	 (error-invalid-formals-syntax input-form.stx ?lhs*))
       (let* ((fluid-label* (map %lookup-binding-in-lexenv.run ?lhs*))
	      (binding*     (map (lambda (rhs.stx)
				   (with-exception-handler/input-form
				       rhs.stx
				     (eval-macro-transformer (expand-macro-transformer rhs.stx lexenv.expand)
							     lexenv.run)))
			      ?rhs*))
	      (entry*       (map cons fluid-label* binding*)))
	 (chi-internal-body (cons ?body ?body*)
			    (append entry* lexenv.run)
			    (append entry* lexenv.expand))))))

  (define (%lookup-binding-in-lexenv.run lhs)
    ;;Search the binding of the identifier LHS retrieving its label; if such label is
    ;;present and its  associated syntactic binding descriptor from  LEXENV.RUN is of
    ;;type "fluid  syntax": return  the associated  fluid label that  can be  used to
    ;;rebind the identifier.
    ;;
    (let* ((label    (or (id->label lhs)
			 (%synner "unbound identifier" lhs)))
	   (binding  (label->syntactic-binding-descriptor/no-indirection label lexenv.run)))
      (cond ((fluid-syntax-binding-descriptor? binding)
	     (fluid-syntax-binding-descriptor.fluid-label binding))
	    (else
	     (%synner "not a fluid identifier" lhs)))))

  (transformer input-form.stx))


;;;; module core-macro-transformer: FOREIGN-CALL

(define-core-transformer (foreign-call input-form.stx lexenv.run lexenv.expand)
  ;;Transformer  function used  to  expand Vicare's  FOREIGN-CALL  syntaxes from  the
  ;;top-level built in  environment.  Expand the syntax object  INPUT-FORM.STX in the
  ;;context of the given LEXENV; return a PSI struct.
  ;;
  (syntax-match input-form.stx ()
    ((_ ?name ?arg* ...)
     (let* ((name.psi  (chi-expr  ?name lexenv.run lexenv.expand))
	    (arg*.psi  (chi-expr* ?arg* lexenv.run lexenv.expand))
	    (expr.core (build-foreign-call no-source
			 (psi-core-expr name.psi)
			 (map psi-core-expr arg*.psi))))
       (make-psi input-form.stx expr.core)))
    ))


;;;; module core-macro-transformer: SYNTAX

(module (syntax-transformer)
  ;;Transformer function  used to  expand R6RS's SYNTAX  syntaxes from  the top-level
  ;;built in  environment.  Process  the contents  of USE-STX in  the context  of the
  ;;lexical environments LEXENV.RUN and LEXENV.EXPAND.  Return a PSI struct.
  ;;
  ;;According to R6RS, the use of the SYNTAX macro must have the format:
  ;;
  ;;  (syntax ?template)
  ;;
  ;;where ?TEMPLATE is one among:
  ;;
  ;;  ?datum
  ;;  ?pattern-variable
  ;;  ?id
  ;;  (?subtemplate ...)
  ;;  (?subtemplate ... . ?template)
  ;;  #(?subtemplate ...)
  ;;
  ;;in  which:  ?DATUM  is  a  literal  datum,  ?PATTERN-VARIABLE  is  an  identifier
  ;;referencing a pattern  variable created by SYNTAX-CASE, ?ID is  an identifier not
  ;;referencing a  pattern variable, ?SUBTEMPLATE is  a template followed by  zero or
  ;;more ellipsis identifiers.
  ;;
  ;;Return  a sexp  representing code  in the  core language  which, when  evaluated,
  ;;returns a wrapped or unwrapped syntax object containing an expression in which:
  ;;
  ;;*  All  the  template  identifiers  being references  to  pattern  variables  are
  ;;  substituted with the corresponding syntax objects.
  ;;
  ;;     (syntax-case #'123 (?obj (syntax ?obj)))
  ;;     => #<syntax expr=123>
  ;;
  ;;     (syntax-case #'(1 2) ((?a ?b) (syntax #(?a ?b))))
  ;;     => #(#<syntax expr=1> #<syntax expr=1>)
  ;;
  ;;* All the identifiers not being references to pattern variables are left alone to
  ;;  be  captured by  the lexical  context at the  level below  the current,  in the
  ;;  context of the SYNTAX macro use or the context of the output form.
  ;;
  ;;     (syntax-case #'(1) ((?a) (syntax (display ?b))))
  ;;     => (#<syntax expr=display>
  ;;         #<syntax expr=1> . #<syntax expr=()>)
  ;;
  ;;* All  the sub-templates followed by  ellipsis are replicated to  match the input
  ;;  pattern.
  ;;
  ;;     (syntax-case #'(1 2 3) ((?a ...) (syntax #(?a ...))))
  ;;     => #(1 2 3)
  ;;
  ;;About pattern  variables: they are  present in  a lexical environment  as entries
  ;;with format:
  ;;
  ;;   (?label . (pattern-variable . (?name . ?level)))
  ;;
  ;;where: ?LABEL is the label in the identifier's syntax object, ?NAME is the symbol
  ;;representing  the name  of  the  pattern variable,  ?LEVEL  is  an exact  integer
  ;;representing the  nesting ellipsis  level.  The  SYNTAX-CASE patterns  below will
  ;;generate the given entries:
  ;;
  ;;   ?a			->  (pattern-variable . (?a . 0))
  ;;   (?a)			->  (pattern-variable . (?a . 0))
  ;;   (((?a)))			->  (pattern-variable . (?a . 0))
  ;;   (?a ...)			->  (pattern-variable . (?a . 1))
  ;;   ((?a) ...)		->  (pattern-variable . (?a . 1))
  ;;   ((((?a))) ...)		->  (pattern-variable . (?a . 1))
  ;;   ((?a ...) ...)		->  (pattern-variable . (?a . 2))
  ;;   (((?a ...) ...) ...)	->  (pattern-variable . (?a . 3))
  ;;
  ;;The  input template  is first  visited  in post-order,  building an  intermediate
  ;;symbolic representation  of it;  then the symbolic  representation is  visited in
  ;;post-order, building  core language code  that evaluates to the  resulting syntax
  ;;object.   Examples  of  intermediate  representation (-->)  and  expansion  (==>)
  ;;follows, assuming identifiers starting with "?"  are pattern variables:
  #|
  (syntax display)
  --> (quote #<syntax expr=display>)
  ==> (quote #<syntax expr=display>)

  (syntax (display 123))
  --> (quote #<syntax expr=(display 123)>)
  ==> (quote #<syntax expr=(display 123)>)

  (syntax ?a)
  --> (ref ?a)
  ==> ?a

  (syntax (?a))
  --> (cons (ref ?a) (quote #<syntax expr=()>))
  ==> ((primitive cons) ?a (quote #<syntax expr=()>))

  (syntax (?a 1))
  --> (cons (ref ?a) (quote #<syntax expr=(1)>))
  ==> ((primitive cons) ?a (quote #<syntax expr=(1)>))

  (syntax (1 ?a 2))
  --> (cons (quote #<syntax expr=1>)
  (cons (ref ?a) (quote #<syntax expr=(2)>)))
  ==> ((primitive cons)
  (quote #<syntax expr=1>)
  ((primitive cons) ?a (quote #<syntax expr=(2)>)))

  (syntax (display ?a))
  ==> (cons
  (quote #<syntax expr=display>)
  (cons (ref ?a) (quote #<syntax expr=()>)))
  ==> ((primitive cons)
  (quote #<syntax expr=display>)
  ((primitive cons) ?a (quote #<syntax expr=()>)))

  (syntax #(?a))
  --> (vector (ref ?a))
  ==> ((primitive vector) ?a)

  (syntax (?a ...))
  --> (ref ?a)
  ==> ?a

  (syntax ((?a ...) ...))
  --> (ref ?a)
  ==> ?a

  (syntax ((?a ?b ...) ...))
  -- (map (primitive cons) (ref ?a) (ref ?b))
  ==> ((primitive ellipsis-map) (primitive cons) ?a ?b)

  (syntax (((?a ?b ...) ...) ...))
  --> (map (lambda (tmp2 tmp1)
  (map (primitive cons) tmp1 tmp2))
  (ref ?b) (ref ?a))
  ==> ((primitive ellipsis-map)
  (case-lambda
  ((tmp2 tmp1)
  ((primitive ellipsis-map) (primitive cons) tmp1 tmp2)))
  ?b ?a)

  (syntax ((?a (?a ...)) ...))
  --> (map (lambda (tmp)
  (cons (ref tmp)
  (cons (ref ?a)
  (quote #<syntax expr=()>))))
  (ref ?a))
  ==> ((primitive ellipsis-map)
  (case-lambda
  ((tmp)
  ((primitive cons) tmp
  ((primitive cons) ?a
  (quote #<syntax expr=()>)))))
  ?a)
  |#
  (define (syntax-transformer use-stx lexenv.run lexenv.expand)
    (syntax-match use-stx ()
      ((_ ?template)
       (receive (intermediate-sexp maps)
	   (%gen-syntax use-stx ?template lexenv.run '() ellipsis? #f)
	 (let ((code (%generate-output-code intermediate-sexp)))
	   #;(debug-print 'syntax (syntax->datum ?template) intermediate-sexp code)
	   (make-psi use-stx code))))
      ))

  (define-module-who syntax)

  (define (%gen-syntax use-stx template-stx lexenv maps ellipsis? vec?)
    ;;Recursive function.  Expand the contents of a SYNTAX use.
    ;;
    ;;USE-STX must be the syntax object  containing the original SYNTAX macro use; it
    ;;is used for descriptive error reporting.
    ;;
    ;;TEMPLATE-STX must be the template from the SYNTAX macro use.
    ;;
    ;;LEXENV is the  lexical environment in which the expansion  takes place; it must
    ;;contain the pattern variables visible by this SYNTAX use.
    ;;
    ;;MAPS is a  list of alists, one  alist for each ellipsis nesting  level.  If the
    ;;template has 3 nested ellipsis patterns:
    ;;
    ;;   (((?a ...) ...) ...)
    ;;
    ;;while we  are processing  the inner  "(?a ...)"  MAPS  contains 3  alists.  The
    ;;alists are used  when processing ellipsis templates  that recursively reference
    ;;the same pattern variable, for example:
    ;;
    ;;   ((?a (?a ...)) ...)
    ;;
    ;;the inner ?A is  mapped to a gensym which is used to  generate a binding in the
    ;;output code.
    ;;
    ;;ELLIPSIS?  must be  a predicate  function returning  true when  applied to  the
    ;;ellipsis identifier  from the built in  environment.  Such function is  made an
    ;;argument, so that it can be changed  to a predicate returning always false when
    ;;we are recursively processing a quoted template:
    ;;
    ;;   (... ?sub-template)
    ;;
    ;;in which the ellipses in ?SUB-TEMPLATE are to be handled as normal identifiers.
    ;;
    ;;VEC? is a boolean: true when this function is processing the items of a vector.
    ;;
    (syntax-match template-stx ()

      ;;Standalone ellipses are not allowed.
      ;;
      (?dots
       (ellipsis? ?dots)
       (syntax-violation __module_who__ "misplaced ellipsis in syntax form" use-stx))

      ;;Match a standalone  identifier.  ?ID can be: a reference  to pattern variable
      ;;created by SYNTAX-CASE; an identifier that  will be captured by some binding;
      ;;an  identifier  that will  result  to  be free,  in  which  case an  "unbound
      ;;identifier" error will be raised later.
      ;;
      (?id
       (identifier? ?id)
       (let ((binding (label->syntactic-binding-descriptor (id->label ?id) lexenv)))
	 (if (pattern-variable-binding-descriptor? binding)
	     ;;It is a reference to pattern variable.
	     (receive (var maps)
		 (let* ((name.level  (syntactic-binding-descriptor.value binding))
			(name        (car name.level))
			(level       (cdr name.level)))
		   (%gen-ref use-stx name level maps))
	       (values (list 'ref var) maps))
	   ;;It is some other identifier.
	   (values (list 'quote ?id) maps))))

      ;;Ellipses starting a vector template are not allowed:
      ;;
      ;;   #(... 1 2 3)   ==> ERROR
      ;;
      ;;but ellipses starting a list template  are allowed, they quote the subsequent
      ;;sub-template:
      ;;
      ;;   (... ...)		==> quoted ellipsis
      ;;   (... ?sub-template)	==> quoted ?SUB-TEMPLATE
      ;;
      ;;so that the ellipses in the  ?SUB-TEMPLATE are treated as normal identifiers.
      ;;We change  the ELLIPSIS? argument  for recursion  to a predicate  that always
      ;;returns false.
      ;;
      ((?dots ?sub-template)
       (ellipsis? ?dots)
       (if vec?
	   (syntax-violation __module_who__ "misplaced ellipsis in syntax form" use-stx)
	 (%gen-syntax use-stx ?sub-template lexenv maps (lambda (x) #f) #f)))

      ;;Match a template followed by ellipsis.
      ;;
      ((?template ?dots . ?rest)
       (ellipsis? ?dots)
       (let loop
	   ((rest.stx ?rest)
	    (kont     (lambda (maps)
			(receive (template^ maps)
			    (%gen-syntax use-stx ?template lexenv (cons '() maps) ellipsis? #f)
			  (if (null? (car maps))
			      (syntax-violation __module_who__ "extra ellipsis in syntax form" use-stx)
			    (values (%gen-map template^ (car maps))
				    (cdr maps)))))))
	 (syntax-match rest.stx ()
	   (()
	    (kont maps))

	   ((?dots . ?tail)
	    (ellipsis? ?dots)
	    (loop ?tail (lambda (maps)
			  (receive (template^ maps)
			      (kont (cons '() maps))
			    (if (null? (car maps))
				(syntax-violation __module_who__ "extra ellipsis in syntax form" use-stx)
			      (values (%gen-mappend template^ (car maps))
				      (cdr maps)))))))

	   (_
	    (receive (rest^ maps)
		(%gen-syntax use-stx rest.stx lexenv maps ellipsis? vec?)
	      (receive (template^ maps)
		  (kont maps)
		(values (%gen-append template^ rest^) maps))))
	   )))

      ;;Process pair templates.
      ;;
      ((?car . ?cdr)
       (receive (car.new maps)
	   (%gen-syntax use-stx ?car lexenv maps ellipsis? #f)
	 (receive (cdr.new maps)
	     (%gen-syntax use-stx ?cdr lexenv maps ellipsis? vec?)
	   (values (%gen-cons template-stx ?car ?cdr car.new cdr.new)
		   maps))))

      ;;Process a vector template.  We set to true the VEC? argument for recursion.
      ;;
      (#(?item* ...)
       (receive (item*.new maps)
	   (%gen-syntax use-stx ?item* lexenv maps ellipsis? #t)
	 (values (%gen-vector template-stx ?item* item*.new)
		 maps)))

      ;;Everything else is just quoted in  the output.  This includes all the literal
      ;;datums.
      ;;
      (_
       (values `(quote ,template-stx) maps))
      ))

  (define (%gen-ref use-stx var level maps)
    ;;Recursive function.
    ;;
    #;(debug-print 'gen-ref maps)
    (if (zero? level)
	(values var maps)
      (if (null? maps)
	  (syntax-violation __module_who__ "missing ellipsis in syntax form" use-stx)
	(receive (outer-var outer-maps)
	    (%gen-ref use-stx var (- level 1) (cdr maps))
	  (cond ((assq outer-var (car maps))
		 => (lambda (b)
		      (values (cdr b) maps)))
		(else
		 (let ((inner-var (generate-lexical-gensym 'tmp)))
		   (values inner-var
			   (cons (cons (cons outer-var inner-var)
				       (car maps))
				 outer-maps)))))))))

  (define (%gen-append x y)
    (if (equal? y '(quote ()))
	x
      `(append ,x ,y)))

  (define (%gen-mappend e map-env)
    `(apply (primitive append) ,(%gen-map e map-env)))

  (define (%gen-map e map-env)
    (let ((formals (map cdr map-env))
	  (actuals (map (lambda (x) `(ref ,(car x))) map-env)))
      (cond
       ;; identity map equivalence:
       ;; (map (lambda (x) x) y) == y
       ((eq? (car e) 'ref)
	(car actuals))
       ;; eta map equivalence:
       ;; (map (lambda (x ...) (f x ...)) y ...) == (map f y ...)
       ((for-all
	    (lambda (x) (and (eq? (car x) 'ref) (memq (cadr x) formals)))
	  (cdr e))
	(let ((args (map (let ((r (map cons formals actuals)))
			   (lambda (x) (cdr (assq (cadr x) r))))
		      (cdr e))))
	  `(map (primitive ,(car e)) . ,args)))
       (else
	(cons* 'map (list 'lambda formals e) actuals)))))

  (define (%gen-cons e x y x.new y.new)
    (case (car y.new)
      ((quote)
       (cond ((eq? (car x.new) 'quote)
	      (let ((x.new (cadr x.new))
		    (y.new (cadr y.new)))
		(if (and (eq? x.new x)
			 (eq? y.new y))
		    `(quote ,e)
		  `(quote ,(cons x.new y.new)))))
	     ((null? (cadr y.new))
	      `(list ,x.new))
	     (else
	      `(cons ,x.new ,y.new))))
      ((list)
       `(list ,x.new . ,(cdr y.new)))
      (else
       `(cons ,x.new ,y.new))))

  (define (%gen-vector e ls lsnew)
    (cond ((eq? (car lsnew) 'quote)
	   (if (eq? (cadr lsnew) ls)
	       `(quote ,e)
	     `(quote #(,@(cadr lsnew)))))

	  ((eq? (car lsnew) 'list)
	   `(vector . ,(cdr lsnew)))

	  (else
	   `(list->vector ,lsnew))))

  (define (%generate-output-code x)
    ;;Recursive function.
    ;;
    (case (car x)
      ((ref)
       (build-lexical-reference no-source (cadr x)))
      ((primitive)
       (build-primref no-source (cadr x)))
      ((quote)
       (build-data no-source (cadr x)))
      ((lambda)
       (build-lambda no-source (cadr x) (%generate-output-code (caddr x))))
      ((map)
       (let ((ls (map %generate-output-code (cdr x))))
	 (build-application no-source
	   (build-primref no-source 'ellipsis-map)
	   ls)))
      (else
       (build-application no-source
	 (build-primref no-source (car x))
	 (map %generate-output-code (cdr x))))))

  #| end of module: syntax-transformer |# )


;;;; module core-macro-transformer: SYNTAX-CASE

(module (syntax-case-transformer)
  ;;Transformer  function  used  to  expand  R6RS's  SYNTAX-CASE  syntaxes  from  the
  ;;top-level built  in environment.  Process  the contents of INPUT-FORM.STX  in the
  ;;context of the  lexical environments LEXENV.RUN and LEXENV.EXPAND.   Return a PSI
  ;;struct.
  ;;
  ;;Notice that the parsing of the patterns is performed by CONVERT-PATTERN at expand
  ;;time and the actual pattern matching is performed by SYNTAX-DISPATCH at run time.
  ;;
  (define-module-who syntax-case)

  (define-syntax stx-error
    (syntax-rules ()
      ((_ ?stx ?msg)
       (syntax-violation __module_who__ ?msg ?stx))
      ))

  (define (syntax-case-transformer input-form.stx lexenv.run lexenv.expand)
    (syntax-match input-form.stx ()
      ((_ ?expr (?literal* ...) ?clauses* ...)
       (%verify-literals ?literal* input-form.stx)
       (let* ( ;;The lexical variable to which  the result of evaluating the ?EXPR is
	      ;;bound.
	      (expr.sym   (generate-lexical-gensym 'tmp))
	      ;;The full SYNTAX-CASE pattern matching code, generated and transformed
	      ;;to core language.
	      (body.core  (%gen-syntax-case expr.sym ?literal* ?clauses*
					    lexenv.run lexenv.expand))
	      ;;The ?EXPR transformed to core language.
	      (expr.core  (%chi-expr.core ?expr lexenv.run lexenv.expand)))
	 ;;Return a form like:
	 ;;
	 ;;   ((lambda (expr.sym) body.core) expr.core)
	 ;;
	 ;;where BODY.CORE is the SYNTAX-CASE matching code.
	 (make-psi input-form.stx
		   (build-application no-source
		     (build-lambda no-source
		       (list expr.sym)
		       body.core)
		     (list expr.core)))))
      ))

  (define (%gen-syntax-case expr.sym literals clauses lexenv.run lexenv.expand)
    ;;Recursive function.  Generate and return the  full pattern matching code in the
    ;;core language to match the given CLAUSES.
    ;;
    (syntax-match clauses ()
      ;;No pattern matched the input expression: return code to raise a syntax error.
      ;;
      (()
       (build-application no-source
	 (build-primref no-source 'syntax-violation)
	 (list (build-data no-source 'syntax-case)
	       (build-data no-source "no pattern matched the input expression")
	       (build-lexical-reference no-source expr.sym))))

      ;;The pattern is  a standalone identifier, neither a literal  nor the ellipsis,
      ;;and  it has  no  fender.   A standalone  identifier  with  no fender  matches
      ;;everything, so it is  useless to generate the code for  the next clauses: the
      ;;code generated here is the last one.
      ;;
      (((?pattern ?output-expr) . ?unused-clauses)
       (and (identifier? ?pattern)
	    (not (bound-id-member? ?pattern literals))
	    (not (ellipsis? ?pattern)))
       (if (underscore-id? ?pattern)
	   ;;The clause is:
	   ;;
	   ;;   (_ ?output-expr)
	   ;;
	   ;;the  underscore  identifier  matches  everything and  binds  no  pattern
	   ;;variables.
	   (%chi-expr.core ?output-expr lexenv.run lexenv.expand)
	 ;;The clause is:
	 ;;
	 ;;   (?id ?output-expr)
	 ;;
	 ;;a  standalone identifier  matches everything  and  binds it  to a  pattern
	 ;;variable whose name is ?ID.
	 (let ((label (generate-label-gensym ?pattern))
	       (lex   (generate-lexical-gensym ?pattern)))
	   ;;The expression must be expanded  in a lexical environment augmented with
	   ;;the pattern variable.
	   (define output-expr^
	     (push-lexical-contour
		 (make-rib/from-identifiers-and-labels (list ?pattern) (list label))
	       ?output-expr))
	   (define lexenv.run^
	     ;;Push a  pattern variable  entry to the  lexenv.  The  ellipsis nesting
	     ;;level is 0.
	     (cons (cons label (make-syntactic-binding-descriptor/pattern-variable lex 0))
		   lexenv.run))
	   (define output-expr.core
	     (%chi-expr.core output-expr^ lexenv.run^ lexenv.expand))
	   (build-application no-source
	     (build-lambda no-source
	       (list lex)
	       output-expr.core)
	     (list (build-lexical-reference no-source expr.sym))))))

      ;;The  pattern  is neither  a  standalone  pattern  variable nor  a  standalone
      ;;underscore.   It has  no fender,  which  is equivalent  to having  a "#t"  as
      ;;fender.
      ;;
      (((?pattern ?output-expr) . ?next-clauses)
       (%gen-clause expr.sym literals
		    ?pattern #t #;fender
		    ?output-expr
		    lexenv.run lexenv.expand
		    ?next-clauses))

      ;;The pattern has a fender.
      ;;
      (((?pattern ?fender ?output-expr) . ?next-clauses)
       (%gen-clause expr.sym literals
		    ?pattern ?fender ?output-expr
		    lexenv.run lexenv.expand
		    ?next-clauses))
      ))

  (define (%gen-clause expr.sym literals
		       pattern.stx fender.stx output-expr.stx
		       lexenv.run lexenv.expand
		       next-clauses)
    ;;Generate  the code  needed  to  match the  clause  represented by  PATTERN.STX,
    ;;FENDER.STX  and OUTPUT-EXPR.STX;  recursively generate  the code  to match  the
    ;;other clauses in NEXT-CLAUSES.
    ;;
    ;;When there is a fender, we build the output form (pseudo-code):
    ;;
    ;;  ((lambda (y)
    ;;      (if (if y
    ;;              (fender-matches?)
    ;;            #f)
    ;;          (output-expr)
    ;;        (match-next-clauses))
    ;;   (syntax-dispatch expr.sym pattern))
    ;;
    ;;when there is no fender, build the output form (pseudo-code):
    ;;
    ;;  ((lambda (tmp)
    ;;      (if tmp
    ;;          (output-expr)
    ;;        (match-next-clauses))
    ;;   (syntax-dispatch expr.sym pattern))
    ;;
    ;;notice that  the return value of  SYNTAX-DISPATCH is: false if  the pattern did
    ;;not match, otherwise the list of values to be bound to the pattern variables.
    ;;
    (receive (pattern.dispatch pvars.levels)
	;;CONVERT-PATTERN  return 2  values: the  pattern in  the format  accepted by
	;;SYNTAX-DISPATCH, an alist representing the pattern variables:
	;;
	;;*  The keys  of the  alist are  identifiers representing  the names  of the
	;;  pattern variables.
	;;
	;;* The values of the alist  are non-negative exact integers representing the
	;;   ellipsis  nesting level  of  the  corresponding pattern  variable.   See
	;;  SYNTAX-TRANSFORMER for details.
	;;
	(convert-pattern pattern.stx literals)
      (let ((pvars (map car pvars.levels)))
	(unless (distinct-bound-ids? pvars)
	  (%invalid-ids-error pvars pattern.stx "pattern variable")))
      (unless (for-all (lambda (x)
			 (not (ellipsis? (car x))))
		pvars.levels)
	(stx-error pattern.stx "misplaced ellipsis in syntax-case pattern"))
      (let* ((tmp-sym      (generate-lexical-gensym 'tmp))
	     (fender-cond  (%build-fender-conditional expr.sym literals tmp-sym pvars.levels
						      fender.stx output-expr.stx
						      lexenv.run lexenv.expand
						      next-clauses)))
	(build-application no-source
	  (build-lambda no-source
	    (list tmp-sym)
	    fender-cond)
	  (list
	   (build-application no-source
	     (build-primref no-source 'syntax-dispatch)
	     (list (build-lexical-reference no-source expr.sym)
		   (build-data no-source pattern.dispatch))))))))

  (define (%build-fender-conditional expr.sym literals tmp-sym pvars.levels
				     fender.stx output-expr.stx
				     lexenv.run lexenv.expand
				     next-clauses)
    ;;Generate the code that tests the fender:  if the fender succeeds run the output
    ;;expression, else try to match the next clauses.
    ;;
    ;;When there is a fender, we build the output form (pseudo-code):
    ;;
    ;;   (if (if y
    ;;           (fender-matches?)
    ;;         #f)
    ;;       (output-expr)
    ;;     (match-next-clauses))
    ;;
    ;;when there is no fender, build the output form (pseudo-code):
    ;;
    ;;   (if tmp
    ;;       (output-expr)
    ;;     (match-next-clauses))
    ;;
    (define-inline (%build-call expr.stx)
      (%build-dispatch-call pvars.levels expr.stx tmp-sym lexenv.run lexenv.expand))
    (let ((test     (if (eq? fender.stx #t)
			;;There is no fender.
			tmp-sym
		      ;;There is a fender.
		      (build-conditional no-source
			(build-lexical-reference no-source tmp-sym)
			(%build-call fender.stx)
			(build-data no-source #f))))
	  (conseq    (%build-call output-expr.stx))
	  (altern    (%gen-syntax-case expr.sym literals next-clauses lexenv.run lexenv.expand)))
      (build-conditional no-source
	test conseq altern)))

  (define (%build-dispatch-call pvars.levels expr.stx tmp-sym lexenv.run lexenv.expand)
    ;;Generate code to evaluate EXPR.STX in an environment augmented with the pattern
    ;;variables  defined   by  PVARS.LEVELS.   Return  a   core  language  expression
    ;;representing the following pseudo-code:
    ;;
    ;;   (apply (lambda (pattern-var ...) expr) tmp)
    ;;
    (define ids
      ;;For each pattern variable: the identifier representing its name.
      (map car pvars.levels))
    (define labels
      ;;For each pattern variable: a gensym used as label in the lexical environment.
      (map generate-label-gensym ids))
    (define names
      ;;For  each pattern  variable: a  gensym used  as unique  variable name  in the
      ;;lexical environment.
      (map generate-lexical-gensym ids))
    (define levels
      ;;For each pattern variable: an exact integer representing the ellipsis nesting
      ;;level.  See SYNTAX-TRANSFORMER for details.
      (map cdr pvars.levels))
    (define bindings
      ;;For each pattern variable: a binding to be pushed on the lexical environment.
      (map (lambda (label name level)
	     (cons label (make-syntactic-binding-descriptor/pattern-variable name level)))
	labels names levels))
    (define expr.core
      ;;Expand the  expression in  a lexical environment  augmented with  the pattern
      ;;variables.
      ;;
      ;;NOTE We could have created a syntax object:
      ;;
      ;;  #`(lambda (pvar ...) #,expr.stx)
      ;;
      ;;and  then  expanded it:  EXPR.STX  would  have  been  expanded in  a  lexical
      ;;environment augmented with the PVAR bindings.
      ;;
      ;;Instead we have  chosen to push the PVAR bindings  on the lexical environment
      ;;"by hand", then  to expand EXPR.STX in the augmented  environment, finally to
      ;;put the resulting core language expression in a core language LAMBDA syntax.
      ;;
      ;;The two methods are fully equivalent; the one we have chosen is a bit faster.
      ;;
      (%chi-expr.core (push-lexical-contour
			  (make-rib/from-identifiers-and-labels ids labels)
			expr.stx)
		      (append bindings lexenv.run)
		      lexenv.expand))
    (build-application no-source
      (build-primref no-source 'apply)
      (list (build-lambda no-source names expr.core)
	    (build-lexical-reference no-source tmp-sym))))

  (define (%invalid-ids-error id* e description.str)
    (let find ((id* id*)
	       (ok* '()))
      (if (null? id*)
	  (stx-error e "syntax error") ; shouldn't happen
	(if (identifier? (car id*))
	    (if (bound-id-member? (car id*) ok*)
		(syntax-violation __module_who__
		  (string-append "duplicate " description.str) (car id*))
	      (find (cdr id*) (cons (car id*) ok*)))
	  (syntax-violation __module_who__
	    (string-append "invalid " description.str) (car id*))))))

  (define (%chi-expr.core expr.stx lexenv.run lexenv.expand)
    (psi-core-expr (chi-expr expr.stx lexenv.run lexenv.expand)))

  #| end of module: SYNTAX-CASE-TRANSFORMER |# )


;;;; module core-macro-transformer: SPLICE-FIRST-EXPAND

(define-core-transformer (splice-first-expand input-form.stx lexenv.run lexenv.expand)
  ;;Transformer function  used to  expand Vicare's SPLICE-FIRST-EXPAND  syntaxes from
  ;;the top-level built  in environment.  Expand the syntax  object INPUT-FORM.STX in
  ;;the context of  the given LEXENV; return  a PSI struct containing  an instance of
  ;;"splice-first-envelope".
  ;;
  (syntax-match input-form.stx ()
    ((_ ?form)
     (make-psi input-form.stx
	       (let ()
		 (import SPLICE-FIRST-ENVELOPE)
		 (make-splice-first-envelope ?form))))
    ))


;;;; module core-macro-transformer: INTERNAL-BODY

(define-core-transformer (internal-body input-form.stx lexenv.run lexenv.expand)
  ;;Transformer  function used  to expand  Vicare's INTERNAL-BODY  syntaxes from  the
  ;;top-level built in  environment.  Expand the syntax object  INPUT-FORM.STX in the
  ;;context  of the  given LEXENV;  return  a PSI  struct containing  an instance  of
  ;;"splice-first-envelope".
  ;;
  (syntax-match input-form.stx ()
    ((_ ?body ?body* ...)
     (chi-internal-body (cons ?body ?body*) lexenv.run lexenv.expand))
    ))


;;;; module core-macro-transformer: PREDICATE-PROCEDURE-ARGUMENT-VALIDATION, PREDICATE-RETURN-VALUE-VALIDATION

(define-core-transformer (predicate-procedure-argument-validation input-form.stx lexenv.run lexenv.expand)
  ;;Transformer        function         used        to         expand        Vicare's
  ;;PREDICATE-PROCEDURE-ARGUMENT-VALIDATION  macros  from   the  top-level  built  in
  ;;environment.  Expand the  contents of INPUT-FORM.STX in the context  of the given
  ;;LEXENV; return a PSI struct.
  ;;
  (syntax-match input-form.stx ()
    ((_ ?id)
     (identifier? ?id)
     (chi-expr (cond ((parametrise ((current-run-lexenv (lambda () lexenv.run)))
			(predicate-assertion-procedure-argument-validation ?id)))
		     (else
		      (%synner "undefined procedure argument validation")))
	       lexenv.run lexenv.expand))
    ))

(define-core-transformer (predicate-return-value-validation input-form.stx lexenv.run lexenv.expand)
  ;;Transformer  function used  to expand  Vicare's PREDICATE-RETURN-VALUE-VALIDATION
  ;;macros  from  the  top-level  built  in  environment.   Expand  the  contents  of
  ;;INPUT-FORM.STX in the context of the given LEXENV; return a PSI struct.
  ;;
  (syntax-match input-form.stx ()
    ((_ ?id)
     (identifier? ?id)
     (chi-expr (cond ((parametrise ((current-run-lexenv (lambda () lexenv.run)))
			(predicate-assertion-return-value-validation ?id)))
		     (else
		      (%synner "undefined return value validation")))
	       lexenv.run lexenv.expand))
    ))


;;;; module core-macro-transformer: STRUCT-TYPE-DESCRIPTOR, RECORD-{TYPE,CONSTRUCTOR}-DESCRIPTOR, TYPE-DESCRIPTOR

(module (struct-type-descriptor-transformer
	 record-type-descriptor-transformer
	 record-constructor-descriptor-transformer
	 type-descriptor-transformer)

  (define-core-transformer (struct-type-descriptor input-form.stx lexenv.run lexenv.expand)
    ;;Transformer function  used to  expand STRUCT-TYPE-DESCRIPTOR syntaxes  from the
    ;;top-level built in environment.  Expand the syntax object INPUT-FORM.STX in the
    ;;context of the given LEXENV; return a PSI struct.
    ;;
    (syntax-match input-form.stx ()
      ((_ ?type-id)
       (identifier? ?type-id)
       (%make-struct-type-descriptor __who__ ?type-id input-form.stx lexenv.run lexenv.expand))))


  (define-core-transformer (record-type-descriptor input-form.stx lexenv.run lexenv.expand)
    ;;Transformer function  used to  expand RECORD-TYPE-DESCRIPTOR syntaxes  from the
    ;;top-level built in environment.  Expand the syntax object INPUT-FORM.STX in the
    ;;context of the given LEXENV; return a PSI struct.
    ;;
    (syntax-match input-form.stx ()
      ((_ ?type-id)
       (identifier? ?type-id)
       (%make-record-type-descriptor __who__ ?type-id input-form.stx lexenv.run lexenv.expand))))

  (define-core-transformer (record-constructor-descriptor input-form.stx lexenv.run lexenv.expand)
    ;;Transformer function used to expand RECORD-CONSTRUCTOR-DESCRIPTOR syntaxes from
    ;;the top-level built in environment.  Expand the syntax object INPUT-FORM.STX in
    ;;the context of the given LEXENV; return a PSI struct.
    ;;
    (syntax-match input-form.stx ()
      ((_ ?type-id)
       (identifier? ?type-id)
       (let* ((descr     (id->record-type-name-binding-descriptor __who__ input-form.stx ?type-id lexenv.run))
	      (rts       (syntactic-binding-descriptor.value descr))
	      (expr.stx  (r6rs-record-type-spec.rcd-id rts))
	      (expr.psi  (chi-expr expr.stx lexenv.run lexenv.expand)))
	 (make-psi input-form.stx
		   (psi-core-expr expr.psi)
		   (make-retvals-signature-single-value (core-prim-id '<record-constructor-descriptor>)))))
      ))

  (define-core-transformer (type-descriptor input-form.stx lexenv.run lexenv.expand)
    ;;Transformer function used to expand TYPE-DESCRIPTOR syntaxes from the top-level
    ;;built in environment.   Expand the syntax object INPUT-FORM.STX  in the context
    ;;of the given LEXENV; return a PSI struct.
    ;;
    ;;The result must be an expression evaluating to:
    ;;
    ;;* A Vicare struct type descriptor if  the given identifier argument is a struct
    ;;  type name.
    ;;
    ;;* A R6RS  record type descriptor if  the given identifier argument  is a record
    ;;  type name.
    ;;
    ;;* An expand-time TAG-TYPE-SPEC instance.
    ;;
    (syntax-match input-form.stx ()
      ((_ ?type-id)
       (identifier? ?type-id)
       (case-object-type-binding (__who__ input-form.stx ?type-id lexenv.run binding)
	 ((object-type)
	  (%make-record-type-descriptor __who__ ?type-id input-form.stx lexenv.run lexenv.expand))
	 ((vicare-struct-type)
	  (%make-struct-type-descriptor __who__ ?type-id input-form.stx lexenv.run lexenv.expand))
	 ((tag-type-spec)
	  (make-psi input-form.stx
		    (build-data no-source
		      (identifier-tag-type-spec ?type-id))
		    (make-retvals-signature-single-top)))
	 ))
      ))

;;; --------------------------------------------------------------------

  (define (%make-struct-type-descriptor who type-id input-form.stx lexenv.run lexenv.expand)
    (make-psi input-form.stx
	      (build-data no-source
		(%struct-type-id->std who input-form.stx type-id lexenv.run))
	      (make-retvals-signature-single-value (core-prim-id '<struct-type-descriptor>))))

  (define (%make-record-type-descriptor who type-id input-form.stx lexenv.run lexenv.expand)
    (let* ((descr     (id->record-type-name-binding-descriptor who input-form.stx type-id lexenv.run))
	   (rts       (syntactic-binding-descriptor.value descr))
	   (expr.stx  (r6rs-record-type-spec.rtd-id rts))
	   (expr.psi  (chi-expr expr.stx lexenv.run lexenv.expand)))
      (make-psi input-form.stx
		(psi-core-expr expr.psi)
		(make-retvals-signature-single-value (core-prim-id '<record-type-descriptor>)))))

  #| end of module |# )


;;;; module core-macro-transformer: NEW, DELETE

(define-core-transformer (new input-form.stx lexenv.run lexenv.expand)
  ;;Transformer function  used to  expand NEW  syntaxes from  the top-level  built in
  ;;environment.  Expand the syntax object INPUT-FORM.STX in the context of the given
  ;;LEXENV; return a PSI struct.
  ;;
  (syntax-match input-form.stx ()
    ((_ ?type-id ?arg* ...)
     (identifier? ?type-id)
     (case-object-type-binding (__who__ input-form.stx ?type-id lexenv.run binding)
       ;;For records we  can access the record constructor  syntactic identifier.  We
       ;;just expand to an equivalent of:
       ;;
       ;;   (?maker ?arg ...)
       ;;
       ((object-type)
	(let* ((rts        (syntactic-binding-descriptor.value binding))
	       (maker.sexp (object-type-spec.constructor-sexp rts))
	       (maker.psi  (chi-expr maker.sexp lexenv.run lexenv.expand))
	       (args.psi*  (chi-expr* ?arg* lexenv.run lexenv.expand)))
	  (make-psi input-form.stx
		    (build-application no-source
		      (psi-core-expr maker.psi)
		      (map psi-core-expr args.psi*))
		    (make-retvals-signature-single-value ?type-id))))

       ;;For structs we want to expand to an equivalent of:
       ;;
       ;;   ((struct-constructor (struct-type-descriptor ?type-id)) ?arg* ...)
       ;;
       ((vicare-struct-type)
	(let ((args.psi* (chi-expr* ?arg* lexenv.run lexenv.expand)))
	  (make-psi input-form.stx
		    (build-application no-source
		      (build-application no-source
			(build-primref no-source 'struct-constructor)
			(list (build-data no-source
				(syntactic-binding-descriptor.value binding))))
		      (map psi-core-expr args.psi*))
		    (make-retvals-signature-single-value ?type-id))))

       ((tag-type-spec)
	(make-psi input-form.stx
		  (build-application no-source
		    (psi-core-expr (chi-expr (tag-identifier-constructor-maker ?type-id input-form.stx)
					     lexenv.run lexenv.expand))
		    (map psi-core-expr (chi-expr* ?arg* lexenv.run lexenv.expand)))
		  (make-retvals-signature-single-value ?type-id)))
       ))))

(module (delete-transformer)

  (define-core-transformer (delete input-form.stx lexenv.run lexenv.expand)
    ;;Transformer function used to expand DELETE syntaxes from the top-level built in
    ;;environment.  Expand  the syntax  object INPUT-FORM.STX in  the context  of the
    ;;given LEXENV; return a PSI struct.
    ;;
    (syntax-match input-form.stx ()
      ((_ ?expr)
       (let* ((expr.psi (chi-expr ?expr lexenv.run lexenv.expand))
	      (expr.sig (psi-retvals-signature expr.psi)))
	 (syntax-match (retvals-signature-tags expr.sig) ()
	   ((?type-id)
	    ;;We have determined at expand-time  that the expression returns a single
	    ;;value.
	    (%apply-appropriate-destructor __who__ input-form.stx lexenv.run lexenv.expand ?type-id expr.psi))
	   (?tag
	    (list-tag-id? ?tag)
	    ;;Damn  it!!!   The expression's  return  values  have fully  UNspecified
	    ;;signature; we need to insert a run-time dispatch.
	    (%run-time-destruction input-form.stx lexenv.run lexenv.expand expr.psi))
	   (_
	    ;;The horror!!!  We  have established at expand-time  that the expression
	    ;;returns multiple values; type violation.
	    (syntax-violation __who__
	      "the expression used as destructor operand returns multiple values"
	      input-form.stx ?expr))
	   )))
      ))

  (define (%apply-appropriate-destructor who input-form.stx lexenv.run lexenv.expand type-id expr.psi)
    (case-object-type-binding (who input-form.stx type-id lexenv.run binding)

      ((object-type)
       ;;For records, when  we have access to the record-type  specification, we want
       ;;to expand to an equivalent of:
       ;;
       ;;   (?deafult-record-destructor-id ?expr)
       ;;
       (cond ((object-type-spec.destructor-sexp (syntactic-binding-descriptor.value binding))
	      => (lambda (destructor-sexp)
		   ;;This record type has a default destructor.
		   (make-psi input-form.stx
			     (build-application no-source
			       (psi-core-expr (chi-expr destructor-sexp lexenv.run lexenv.expand))
			       (list (psi-core-expr expr.psi)))
			     (make-retvals-signature-single-top))))
	     (else
	      ;;This record  type has  *no* default  destructor; default  to run-time
	      ;;destruction.
	      ;;
	      ;;Example of usefulness  of defaulting to run-time  destruction: if the
	      ;;object is a  record with a destructor set at  run-time, this way that
	      ;;destructor will be called.
	      (%run-time-destruction input-form.stx lexenv.run lexenv.expand expr.psi))))

      ((vicare-struct-type)
       ;;For structs we want to expand to an equivalent of:
       ;;
       ;;   ((internal-applicable-struct-type-destructor (struct-type-descriptor ?type-id)) ?expr)
       ;;
       (make-psi input-form.stx
		 (build-application no-source
		   (build-application no-source
		     (build-primref no-source 'internal-applicable-struct-type-destructor)
		     (list (build-data no-source
			     (syntactic-binding-descriptor.value binding))))
		   (list (psi-core-expr expr.psi)))
		 (make-retvals-signature-single-top)))

      ((tag-type-spec)
       ;;FIXME  At   present,  expand-time   support  for  TAG-TYPE-SPEC   it  not
       ;;implemented; but it  is to be implemented later.  However,  notice that when
       ;;the type is  "<top>": falling back to run-time dispatching  is fine.  (Marco
       ;;Maggi; Sat Sep 5, 2015)
       (%run-time-destruction input-form.stx lexenv.run lexenv.expand expr.psi))
      ))

  (define* (%run-time-destruction input-form.stx lexenv.run lexenv.expand {expr.psi psi?})
    (make-psi input-form.stx
	      (build-application no-source
		(build-primref no-source 'internal-delete)
		(list (psi-core-expr expr.psi)))
	      (make-retvals-signature-single-top)))

  #| end of module: DELETE-TRANSFORMER |# )


;;;; module core-macro-transformer: IS-A?

(module (is-a?-transformer)

  (define-module-who is-a?)

  (define-core-transformer (is-a? input-form.stx lexenv.run lexenv.expand)
    ;;Transformer function used to expand Vicare's IS-A?  syntaxes from the top-level
    ;;built in environment.   Expand the syntax object INPUT-FORM.STX  in the context
    ;;of the given LEXENV; return a PSI struct.
    ;;
    (syntax-match input-form.stx ()
      ((_ ?jolly ?type-id)
       (and (identifier? ?type-id)
	    (underscore-id? ?jolly))
       (chi-expr (bless
		  (case-object-type-binding (__who__ input-form.stx ?type-id lexenv.run binding)
		    ((object-type)
		     (object-type-spec.type-predicate-sexp (syntactic-binding-descriptor.value binding)))

		    ((vicare-struct-type)
		     (let ((obj (gensym)))
		       `(lambda (,obj)
			  ($struct/rtd? ,obj (struct-type-descriptor ,?type-id)))))

		    ((tag-type-spec)
		     (let ((spec (identifier-tag-type-spec ?type-id)))
		       (tag-type-spec-pred-stx spec)))))
		 lexenv.run lexenv.expand))

      ((_ ?expr ?pred-type-id)
       (identifier? ?pred-type-id)
       (let* ((expr.psi  (chi-expr ?expr lexenv.run lexenv.expand))
	      (expr.sig  (psi-retvals-signature expr.psi)))
	 (define (%run-time-predicate)
	   (%expand-to-run-time-predicate-application input-form.stx lexenv.run lexenv.expand ?pred-type-id expr.psi))
	 (syntax-match (retvals-signature-tags expr.sig) ()
	   ((?expr-type-id)
	    (top-tag-id? ?expr-type-id)
	    (%run-time-predicate))

	   ((?expr-type-id)
	    (if (free-identifier=? ?expr-type-id ?pred-type-id)
		(%make-true-psi input-form.stx)
	      (case-object-type-binding (__who__ input-form.stx ?expr-type-id lexenv.run expr-descr)
		((object-type)
		 (case-object-type-binding (__who__ input-form.stx ?pred-type-id lexenv.run pred-descr)
		   ((object-type)
		    (if (object-type-spec.subtype-and-supertype? (syntactic-binding-descriptor.value expr-descr)
								 (syntactic-binding-descriptor.value pred-descr)
								 lexenv.run)
			(%make-true-psi input-form.stx)
		      (%make-false-psi input-form.stx)))
		   ((vicare-struct-type)
		    (%make-false-psi input-form.stx))
		   ((tag-type-spec)
		    (%make-false-psi input-form.stx))))
		((vicare-struct-type)
		 (%make-false-psi input-form.stx))
		((tag-type-spec)
		 (%expand-to-tag-predicate-application-post input-form.stx lexenv.run lexenv.expand ?pred-type-id expr.psi)))))

	   (?expr-type-id
	    (list-tag-id? ?expr-type-id)
	    (%run-time-predicate))

	   (_
	    ;;We have determined at expand-time  that the expression returns multiple
	    ;;values.
	    (raise
	     (condition (make-who-condition __who__)
			(make-message-condition "subject expression of type predicate returns multiple values")
			(make-syntax-violation input-form.stx ?expr)
			(make-irritants-condition expr.sig)))))))
      ))

;;; --------------------------------------------------------------------

  (define (%expand-to-tag-predicate-application-post input-form.stx lexenv.run lexenv.expand pred-type-id expr.psi)
    (define expr.core
      (psi-core-expr expr.psi))
    (let* ((spec       (identifier-tag-type-spec pred-type-id))
	   (pred.stx   (tag-type-spec-pred-stx spec))
	   (pred.psi   (chi-expr pred.stx lexenv.run lexenv.expand))
	   (pred.core  (psi-core-expr pred.psi)))
      (make-psi input-form.stx
		(build-application input-form.stx
		  pred.core
		  (list expr.core))
		(psi-application-retvals-signature pred.psi))))

;;; --------------------------------------------------------------------

  (define (%expand-to-run-time-predicate-application input-form.stx lexenv.run lexenv.expand pred-type-id expr.psi)
    (define expr.core
      (psi-core-expr expr.psi))
    (case-object-type-binding (__module_who__ input-form.stx pred-type-id lexenv.run descr)
      ((object-type)
       (let* ((rts        (syntactic-binding-descriptor.value descr))
	      (pred.stx   (bless
			   (object-type-spec.type-predicate-sexp (syntactic-binding-descriptor.value descr))))
	      (pred.psi   (chi-expr pred.stx lexenv.run lexenv.expand))
	      (pred.core  (psi-core-expr pred.psi)))
	 (make-psi input-form.stx
		   (build-application input-form.stx
		     pred.core
		     (list expr.core))
		   (psi-application-retvals-signature pred.psi))))

      ((vicare-struct-type)
       (let* ((obj.sym    (gensym))
	      (pred.stx   (bless
			   `(lambda (,obj.sym)
			      ($struct/rtd? ,obj.sym (struct-type-descriptor ,pred-type-id)))))
	      (pred.psi   (chi-expr pred.stx lexenv.run lexenv.expand))
	      (pred.core  (psi-core-expr pred.psi)))
	 (make-psi input-form.stx
		   (build-application input-form.stx
		     pred.core
		     (list expr.core))
		   (psi-application-retvals-signature pred.psi))))

      ((tag-type-spec)
       (%expand-to-tag-predicate-application-post input-form.stx lexenv.run lexenv.expand pred-type-id expr.psi))))

;;; --------------------------------------------------------------------

  (define (%make-true-psi input-form.stx)
    (%make-boolean-psi input-form.stx #t))

  (define (%make-false-psi input-form.stx)
    (%make-boolean-psi input-form.stx #f))

  (define (%make-boolean-psi input-form.stx bool)
    (make-psi input-form.stx
	      (build-data no-source bool)
	      (make-retvals-signature-single-boolean)))

  #| end of module: IS-A?-TRANSFORMER |# )


;;;; module core-macro-transformer: SLOT-REF

(module (slot-ref-transformer)

  (define-module-who slot-ref)

  (define-core-transformer (slot-ref input-form.stx lexenv.run lexenv.expand)
    ;;Transformer  function  used  to  expand Vicare's  SLOT-REF  syntaxes  from  the
    ;;top-level built in environment.  Expand the syntax object INPUT-FORM.STX in the
    ;;context of the given LEXENV; return a PSI struct.
    ;;
    (syntax-match input-form.stx ()
      ;;Everything included.  It must expand to an accessor application.
      ((_ ?expr ?field-name ?type-id)
       (and (not (underscore-id? ?expr))
	    (identifier? ?field-name)
	    (identifier? ?type-id))
       (case-object-type-binding (__who__ input-form.stx ?type-id lexenv.run descr)
	 ((object-type)
	  (%expand-to-object-accessor-application input-form.stx lexenv.run lexenv.expand descr ?expr ?field-name))
	 ((vicare-struct-type)
	  (%expand-to-struct-accessor-application input-form.stx lexenv.run lexenv.expand ?type-id ?expr ?field-name))
	 ((tag-type-spec)
	  (%expand-to-tag-accessor-application    input-form.stx lexenv.run lexenv.expand ?type-id ?expr ?field-name))))

      ;;Wildcard in place of the subject expression.  It must expand to an expression
      ;;that evaluates to an accessor.
      ((_ ?jolly ?field-name ?type-id)
       (and (identifier? ?type-id)
	    (identifier? ?field-name)
	    (underscore-id? ?jolly))
       (case-object-type-binding (__who__ input-form.stx ?type-id lexenv.run descr)
	 ((object-type)
	  (%expand-to-object-accessor input-form.stx lexenv.run lexenv.expand descr ?field-name))
	 ((vicare-struct-type)
	  (%expand-to-struct-accessor input-form.stx lexenv.run lexenv.expand ?type-id ?field-name))
	 ((tag-type-spec)
	  (%expand-to-tag-accessor    input-form.stx lexenv.run lexenv.expand ?type-id ?field-name))))

      ;;Missing type identifier.  Try to retrieve  the type from the signature of the
      ;;subject expression.
      ((_ ?expr ?field-name)
       (and (not (underscore-id? ?expr))
	    (identifier? ?field-name))
       (let* ((expr.psi  (chi-expr ?expr lexenv.run lexenv.expand))
	      (expr.sig  (psi-retvals-signature expr.psi)))
	 (define (%error-unknown-type)
	   (%synner "unable to determine type of expression at expand-time" ?expr))
	 (syntax-match (retvals-signature-tags expr.sig) ()
	   ((?type-id)
	    (top-tag-id? ?type-id)
	    (%error-unknown-type))

	   ((?type-id)
	    (case-object-type-binding (__who__ input-form.stx ?type-id lexenv.run descr)
	      ((object-type)
	       (%expand-to-object-accessor-application-post input-form.stx lexenv.run lexenv.expand descr    expr.psi ?field-name))
	      ((vicare-struct-type)
	       (%expand-to-struct-accessor-application-post input-form.stx lexenv.run lexenv.expand ?type-id expr.psi ?field-name))
	      ((tag-type-spec)
	       (%expand-to-tag-accessor-application-post    input-form.stx lexenv.run lexenv.expand ?type-id expr.psi ?field-name))))

	   (?type-id
	    (list-tag-id? ?type-id)
	    ;;Damn  it!!!   The  expression's  return  values  have  fully  UNspecified
	    ;;signature.
	    (%error-unknown-type))

	   (_
	    ;;We have  determined at expand-time  that the expression  returns multiple
	    ;;values.
	    (raise
	     (condition (make-who-condition __who__)
			(make-message-condition "subject expression of slot access returns multiple values")
			(make-syntax-violation input-form.stx ?expr)
			(make-irritants-condition expr.sig))))
	   )))
      ))

;;; --------------------------------------------------------------------

  (define* (%expand-to-object-accessor-application input-form.stx lexenv.run lexenv.expand
						   descr {expr.stx syntax-object?} field-name.id)
    (cond ((let ((rts (syntactic-binding-descriptor.value descr)))
	     (object-type-spec.safe-accessor-sexp rts (identifier->symbol field-name.id) lexenv.run))
	   => (lambda (accessor.sexp)
		(chi-expr (bless
			   `(,accessor.sexp ,expr.stx))
			  lexenv.run lexenv.expand)))
	  (else
	   (syntax-violation __module_who__ "unknown field name" input-form.stx field-name.id))))

  (define* (%expand-to-struct-accessor-application input-form.stx lexenv.run lexenv.expand
						   type-id {expr.stx syntax-object?} field-name.id)
    (let* ((std         (%struct-type-id->std __module_who__ input-form.stx type-id lexenv.run))
	   (field-names (struct-type-field-names std))
	   (field-idx   (%struct-field-name->struct-field-idx __module_who__ input-form.stx field-names field-name.id)))
      (chi-expr (bless
		 `(struct-and-std-ref ,expr.stx ,field-idx (struct-type-descriptor ,type-id)))
		lexenv.run lexenv.expand)))

  (define* (%expand-to-tag-accessor-application input-form.stx lexenv.run lexenv.expand
						type-id {expr.stx syntax-object?} field-name.id)
    (let ((accessor.stx (tag-identifier-accessor type-id field-name.id input-form.stx)))
      (chi-expr (bless
		 `(,accessor.stx ,expr.stx))
		lexenv.run lexenv.expand)))

;;; --------------------------------------------------------------------

  (define (%expand-to-object-accessor input-form.stx lexenv.run lexenv.expand
				      descr field-name.id)
    (cond ((let ((rts (syntactic-binding-descriptor.value descr)))
	     (object-type-spec.safe-accessor-sexp rts (identifier->symbol field-name.id) lexenv.run))
	   => (lambda (accessor.sexp)
		(chi-expr (bless accessor.sexp) lexenv.run lexenv.expand)))
	  (else
	   (syntax-violation __module_who__ "unknown field name" input-form.stx field-name.id))))

  (define (%expand-to-struct-accessor input-form.stx lexenv.run lexenv.expand
				      type-id field-name.id)
    (let* ((std         (%struct-type-id->std __module_who__ input-form.stx type-id lexenv.run))
	   (field-names (struct-type-field-names std))
	   (field-idx   (%struct-field-name->struct-field-idx __module_who__ input-form.stx field-names field-name.id))
	   (stru.sym    (gensym "stru")))
      (chi-expr (bless
		 `(lambda (,stru.sym)
		    (struct-and-std-ref ,stru.sym ,field-idx (struct-type-descriptor ,type-id))))
		lexenv.run lexenv.expand)))

  (define (%expand-to-tag-accessor input-form.stx lexenv.run lexenv.expand
				   type-id field-name.id)
    (let ((accessor.stx (tag-identifier-accessor type-id field-name.id input-form.stx)))
      (chi-expr (bless accessor.stx)
		lexenv.run lexenv.expand)))

;;; --------------------------------------------------------------------

  (define* (%expand-to-object-accessor-application-post input-form.stx lexenv.run lexenv.expand descr {expr.psi psi?} field-name.id)
    (let ((rts (syntactic-binding-descriptor.value descr)))
      (cond ((object-type-spec.safe-accessor-sexp rts (identifier->symbol field-name.id) lexenv.run)
	     => (lambda (accessor.sexp)
		  (let* ((accessor.psi  (chi-expr (bless accessor.sexp) lexenv.run lexenv.expand))
			 (accessor.core (psi-core-expr accessor.psi))
			 (expr.core     (psi-core-expr expr.psi)))
		    (make-psi input-form.stx
			      (build-application input-form.stx
				accessor.core
				(list expr.core))
			      (psi-application-retvals-signature accessor.psi)))))
	    (else
	     (syntax-violation __module_who__ "unknown field name" input-form.stx field-name.id)))))

  (define* (%expand-to-struct-accessor-application-post input-form.stx lexenv.run lexenv.expand type-id {expr.psi psi?} field-name.id)
    (let* ((std         (%struct-type-id->std __module_who__ input-form.stx type-id lexenv.run))
	   (field-names (struct-type-field-names std))
	   (field-idx   (%struct-field-name->struct-field-idx __module_who__ input-form.stx field-names field-name.id))
	   (expr.core   (psi-core-expr expr.psi)))
      (make-psi input-form.stx
		(build-application input-form.stx
		  (build-primref no-source 'struct-and-std-ref)
		  (list expr.core
			(build-data no-source field-idx)
			(build-data no-source std)))
		(make-retvals-signature-single-void))))

  (define* (%expand-to-tag-accessor-application-post input-form.stx lexenv.run lexenv.expand type-id {expr.psi psi?} field-name.id)
    (let* ((accessor.stx  (tag-identifier-accessor type-id field-name.id input-form.stx))
	   (accessor.psi  (chi-expr accessor.stx lexenv.run lexenv.expand))
	   (accessor.core (psi-core-expr accessor.psi))
	   (expr.core     (psi-core-expr expr.psi)))
      (make-psi input-form.stx
		(build-application input-form.stx
		  accessor.core
		  (list expr.core))
		(psi-application-retvals-signature accessor.psi))))

  #| end of module: SLOT-REF-TRANSFORMER |# )


;;;; module core-macro-transformer: SLOT-SET!

(module (slot-set!-transformer)

  (define-module-who slot-set!)

  (define-core-transformer (slot-set! input-form.stx lexenv.run lexenv.expand)
    ;;Transformer  function  used  to  expand Vicare's  SLOT-SET!  syntaxes  from  the
    ;;top-level built in environment.  Expand the syntax object INPUT-FORM.STX in the
    ;;context of the given LEXENV; return a PSI struct.
    ;;
    (syntax-match input-form.stx ()
      ;;Everything included.  It must expand to an mutator application.
      ((_ ?expr ?field-name ?type-id ?new-value)
       (and (not (underscore-id? ?expr))
	    (identifier? ?field-name)
	    (identifier? ?type-id))
       (case-object-type-binding (__who__ input-form.stx ?type-id lexenv.run descr)
	 ((object-type)
	  (%expand-to-record-mutator-application input-form.stx lexenv.run lexenv.expand descr ?expr ?field-name ?new-value))
	 ((vicare-struct-type)
	  (%expand-to-struct-mutator-application input-form.stx lexenv.run lexenv.expand ?type-id ?expr ?field-name ?new-value))
	 ((tag-type-spec)
	  (%expand-to-tag-mutator-application    input-form.stx lexenv.run lexenv.expand ?type-id ?expr ?field-name ?new-value))))

      ;;Wildcard in place of the subject expression.  It must expand to an expression
      ;;that evaluates to an mutator.
      ((_ ?jolly1 ?field-name ?type-id ?jolly2)
       (and (identifier? ?type-id)
	    (identifier? ?field-name)
	    (underscore-id? ?jolly1)
	    (underscore-id? ?jolly2))
       (case-object-type-binding (__who__ input-form.stx ?type-id lexenv.run descr)
	 ((object-type)
	  (%expand-to-record-mutator input-form.stx lexenv.run lexenv.expand descr ?field-name))
	 ((vicare-struct-type)
	  (%expand-to-struct-mutator input-form.stx lexenv.run lexenv.expand ?type-id ?field-name))
	 ((tag-type-spec)
	  (%expand-to-tag-mutator    input-form.stx lexenv.run lexenv.expand ?type-id ?field-name))))

      ;;Missing type identifier.  Try to retrieve  the type from the signature of the
      ;;subject expression.
      ((_ ?expr ?field-name ?new-value)
       (and (not (underscore-id? ?expr))
	    (identifier? ?field-name))
       (let* ((expr.psi  (chi-expr ?expr lexenv.run lexenv.expand))
	      (expr.sig  (psi-retvals-signature expr.psi)))
	 (define (%error-unknown-type)
	   (%synner "unable to determine type of expression at expand-time" ?expr))
	 (syntax-match (retvals-signature-tags expr.sig) ()
	   ((?type-id)
	    (top-tag-id? ?type-id)
	    (%error-unknown-type))

	   ((?type-id)
	    (case-object-type-binding (__who__ input-form.stx ?type-id lexenv.run descr)
	      ((object-type)
	       (%expand-to-record-mutator-application-post input-form.stx lexenv.run lexenv.expand descr    expr.psi ?field-name ?new-value))
	      ((vicare-struct-type)
	       (%expand-to-struct-mutator-application-post input-form.stx lexenv.run lexenv.expand ?type-id expr.psi ?field-name ?new-value))
	      ((tag-type-spec)
	       (%expand-to-tag-mutator-application-post    input-form.stx lexenv.run lexenv.expand ?type-id expr.psi ?field-name ?new-value))))

	   (?type-id
	    (list-tag-id? ?type-id)
	    ;;Damn  it!!!   The  expression's  return  values  have  fully  UNspecified
	    ;;signature.
	    (%error-unknown-type))

	   (_
	    ;;We have  determined at expand-time  that the expression  returns multiple
	    ;;values.
	    (raise
	     (condition (make-who-condition __who__)
			(make-message-condition "subject expression of slot access returns multiple values")
			(make-syntax-violation input-form.stx ?expr)
			(make-irritants-condition expr.sig))))
	   )))
      ))

;;; --------------------------------------------------------------------

  (define* (%expand-to-record-mutator-application input-form.stx lexenv.run lexenv.expand
						  descr {expr.stx syntax-object?} field-name.id new-value.stx)
    (cond ((let ((rts (syntactic-binding-descriptor.value descr)))
	     (object-type-spec.safe-mutator-sexp rts (identifier->symbol field-name.id) lexenv.run))
	   => (lambda (mutator.sexp)
		(chi-expr (bless
			   `(,mutator.sexp ,expr.stx ,new-value.stx))
			  lexenv.run lexenv.expand)))
	  (else
	   (syntax-violation __module_who__ "unknown field name" input-form.stx field-name.id))))

  (define* (%expand-to-struct-mutator-application input-form.stx lexenv.run lexenv.expand
						  type-id {expr.stx syntax-object?} field-name.id new-value.stx)
    (let* ((std         (%struct-type-id->std __module_who__ input-form.stx type-id lexenv.run))
	   (field-names (struct-type-field-names std))
	   (field-idx   (%struct-field-name->struct-field-idx __module_who__ input-form.stx field-names field-name.id)))
      (chi-expr (bless
		 `(struct-and-std-set! ,expr.stx ,field-idx (struct-type-descriptor ,type-id) ,new-value.stx))
		lexenv.run lexenv.expand)))

  (define* (%expand-to-tag-mutator-application input-form.stx lexenv.run lexenv.expand
					       type-id {expr.stx syntax-object?} field-name.id new-value.stx)
    (let ((mutator.stx (tag-identifier-mutator type-id field-name.id input-form.stx)))
      (chi-expr (bless
		 `(,mutator.stx ,expr.stx ,new-value.stx))
		lexenv.run lexenv.expand)))

;;; --------------------------------------------------------------------

  (define (%expand-to-record-mutator input-form.stx lexenv.run lexenv.expand
				     descr field-name.id)
    (cond ((let ((rts (syntactic-binding-descriptor.value descr)))
	     (object-type-spec.safe-mutator-sexp rts (identifier->symbol field-name.id) lexenv.run))
	   => (lambda (mutator.sexp)
		(chi-expr (bless mutator.sexp) lexenv.run lexenv.expand)))
	  (else
	   (syntax-violation __module_who__ "unknown field name" input-form.stx field-name.id))))

  (define (%expand-to-struct-mutator input-form.stx lexenv.run lexenv.expand
				     type-id field-name.id)
    (let* ((std         (%struct-type-id->std __module_who__ input-form.stx type-id lexenv.run))
	   (field-names (struct-type-field-names std))
	   (field-idx   (%struct-field-name->struct-field-idx __module_who__ input-form.stx field-names field-name.id))
	   (stru.sym    (gensym "stru"))
	   (new-val.sym (gensym "new-val")))
      (chi-expr (bless
		 `(lambda (,stru.sym ,new-val.sym)
		    (struct-and-std-set! ,stru.sym ,field-idx (struct-type-descriptor ,type-id) ,new-val.sym)))
		lexenv.run lexenv.expand)))

  (define (%expand-to-tag-mutator input-form.stx lexenv.run lexenv.expand
				  type-id field-name.id)
    (let ((mutator.stx (tag-identifier-mutator type-id field-name.id input-form.stx)))
      (chi-expr (bless mutator.stx)
		lexenv.run lexenv.expand)))

;;; --------------------------------------------------------------------

  (define* (%expand-to-record-mutator-application-post input-form.stx lexenv.run lexenv.expand
						       descr {expr.psi psi?} field-name.id new-value.stx)
    (let ((rts (syntactic-binding-descriptor.value descr)))
      (cond ((object-type-spec.safe-mutator-sexp rts (identifier->symbol field-name.id) lexenv.run)
	     => (lambda (mutator.sexp)
		  (let* ((mutator.psi    (chi-expr (bless mutator.sexp) lexenv.run lexenv.expand))
			 (mutator.core   (psi-core-expr mutator.psi))
			 (expr.core      (psi-core-expr expr.psi))
			 (new-value.psi  (chi-expr new-value.stx lexenv.run lexenv.expand))
			 (new-value.core (psi-core-expr new-value.psi)))
		    (make-psi input-form.stx
			      (build-application input-form.stx
				mutator.core
				(list expr.core new-value.core))
			      (psi-application-retvals-signature mutator.psi)))))
	    (else
	     (syntax-violation __module_who__ "unknown field name" input-form.stx field-name.id)))))

  (define* (%expand-to-struct-mutator-application-post input-form.stx lexenv.run lexenv.expand
						       type-id {expr.psi psi?} field-name.id new-value.stx)
    (let* ((std             (%struct-type-id->std __module_who__ input-form.stx type-id lexenv.run))
	   (field-names     (struct-type-field-names std))
	   (field-idx       (%struct-field-name->struct-field-idx __module_who__ input-form.stx field-names field-name.id))
	   (expr.core       (psi-core-expr expr.psi))
	   (new-value.psi   (chi-expr new-value.stx lexenv.run lexenv.expand))
	   (new-value.core  (psi-core-expr new-value.psi)))
      (make-psi input-form.stx
		(build-application input-form.stx
		  (build-primref no-source 'struct-and-std-set!)
		  (list expr.core
			(build-data no-source field-idx)
			(build-data no-source std)
			new-value.core))
		(make-retvals-signature-single-void))))

  (define* (%expand-to-tag-mutator-application-post input-form.stx lexenv.run lexenv.expand
						    type-id {expr.psi psi?} field-name.id new-value.stx)
    (let* ((mutator.stx     (tag-identifier-mutator type-id field-name.id input-form.stx))
	   (mutator.psi     (chi-expr mutator.stx lexenv.run lexenv.expand))
	   (mutator.core    (psi-core-expr mutator.psi))
	   (expr.core       (psi-core-expr expr.psi))
	   (new-value.psi   (chi-expr new-value.stx lexenv.run lexenv.expand))
	   (new-value.core  (psi-core-expr new-value.psi)))
      (make-psi input-form.stx
		(build-application input-form.stx
		  mutator.core
		  (list expr.core new-value.core))
		(psi-application-retvals-signature mutator.psi))))

  #| end of module: SLOT-SET!-TRANSFORMER |# )


;;;; module core-macro-transformer: METHOD-CALL

(module (method-call-transformer)

  (define-module-who method-call)

  (define-core-transformer (method-call input-form.stx lexenv.run lexenv.expand)
    ;;Transformer  function used  to expand  Vicare's METHOD-CALL  syntaxes from  the
    ;;top-level built in environment.  Expand the syntax object INPUT-FORM.STX in the
    ;;context of the given LEXENV; return a PSI struct.
    ;;
    (syntax-match input-form.stx ()
      ((_ ?method-name ?subject-expr ?arg* ...)
       (identifier? ?method-name)
       (let* ((method-name.sym	(identifier->symbol ?method-name))
	      (subject-expr.psi	(chi-expr ?subject-expr lexenv.run lexenv.expand))
	      (subject-expr.sig	(psi-retvals-signature subject-expr.psi)))
	 (define-syntax-rule (%late-binding)
	   (%expand-to-late-binding-method-call input-form.stx lexenv.run lexenv.expand
						method-name.sym subject-expr.psi ?arg*))
	 (syntax-match (retvals-signature-tags subject-expr.sig) ()
	   ((?type-id)
	    (top-tag-id? ?type-id)
	    (%late-binding))

	   ((?type-id)
	    (%expand-to-early-binding-method-call input-form.stx lexenv.run lexenv.expand
						  ?method-name method-name.sym
						  ?type-id
						  ?subject-expr subject-expr.psi ?arg*))

	   (?type-id
	    (list-tag-id? ?type-id)
	    ;;Damn  it!!!   The expression's  return  values  have fully  UNspecified
	    ;;signature; we need to insert a run-time dispatch.
	    (%late-binding))

	   (_
	    ;;We have determined at expand-time  that the expression returns multiple
	    ;;values.
	    (raise
	     (condition (make-who-condition __module_who__)
			(make-message-condition "subject expression of method call returns multiple values")
			(make-syntax-violation input-form.stx ?subject-expr)
			(make-irritants-condition subject-expr.sig))))
	   )))
      ))

;;; --------------------------------------------------------------------

  (module (%expand-to-early-binding-method-call)

    (define (%expand-to-early-binding-method-call input-form.stx lexenv.run lexenv.expand
						  method-name.id method-name.sym
						  type-id
						  subject-expr.stx subject-expr.psi arg*.stx)
      (case-object-type-binding (__module_who__ input-form.stx type-id lexenv.run type-id-descr)
	((object-type)
	 (%r6rs-record-method-call input-form.stx lexenv.run lexenv.expand
				   method-name.id method-name.sym
				   type-id type-id-descr
				   subject-expr.stx subject-expr.psi arg*.stx))

	((vicare-struct-type)
	 (%vicare-struct-method-call input-form.stx lexenv.run lexenv.expand
				     method-name.id method-name.sym
				     type-id
				     subject-expr.stx subject-expr.psi arg*.stx))

	((tag-type-spec)
	 (raise
	  (condition (make-who-condition __module_who__)
		     (make-message-condition "unsupported method call operation on type of subject expression")
		     (make-syntax-violation input-form.stx subject-expr.stx)
		     (make-type-syntactic-identifier-condition type-id))))
	))

    ;;;

    (define (%r6rs-record-method-call input-form.stx lexenv.run lexenv.expand
				      method-name.id method-name.sym
				      type-id type-id-descr
				      subject-expr.stx subject-expr.psi arg*.stx)
      (let* ((expr.core  (psi-core-expr subject-expr.psi))
	     (rts        (syntactic-binding-descriptor.value type-id-descr)))
	(cond
	 ;;Look for a matching method name.
	 ((object-type-spec.applicable-method-sexp rts method-name.sym lexenv.run)
	  => (lambda (method.sexp)
	       ;;A matching method name exists.
	       (let* ((method.psi  (chi-expr (bless method.sexp) lexenv.run lexenv.expand))
		      (method.core (psi-core-expr method.psi))
		      (arg*.psi    (chi-expr* arg*.stx lexenv.run lexenv.expand))
		      (arg*.core   (map psi-core-expr arg*.psi)))
		 (make-psi input-form.stx
			   (build-application input-form.stx
			     method.core
			     (cons expr.core arg*.core))
			   (psi-application-retvals-signature method.psi)))))
	 ;;If the input form has the right syntax: look for a matching field name for
	 ;;accessor application.
	 ((and (null? arg*.stx)
	       (object-type-spec.safe-accessor-sexp rts method-name.sym lexenv.run))
	  => (lambda (accessor.sexp)
	       ;;A matching field name exists.
	       (let* ((accessor.psi  (chi-expr (bless accessor.sexp) lexenv.run lexenv.expand))
		      (accessor.core (psi-core-expr accessor.psi)))
		 (make-psi input-form.stx
			   (build-application input-form.stx
			     accessor.core
			     (list expr.core))
			   (psi-application-retvals-signature accessor.psi)))))
	 ;;If the input form has the right syntax: look for a matching field name for
	 ;;mutator application.
	 ((and (pair? arg*.stx)
	       (null? (cdr arg*.stx))
	       (object-type-spec.safe-mutator-sexp rts method-name.sym lexenv.run))
	  => (lambda (mutator.sexp)
	       ;;A matching field name exists.
	       (let* ((mutator.psi  (chi-expr (bless mutator.sexp) lexenv.run lexenv.expand))
		      (mutator.core (psi-core-expr mutator.psi))
		      (arg.psi      (chi-expr (car arg*.stx) lexenv.run lexenv.expand))
		      (arg.core     (psi-core-expr arg.psi)))
		 (make-psi input-form.stx
			   (build-application input-form.stx
			     mutator.core
			     (list expr.core arg.core))
			   (psi-application-retvals-signature mutator.psi)))))
	 (else
	  (raise
	   (condition (make-who-condition __module_who__)
		      (make-message-condition "unknown method name for type of subject expression")
		      (make-syntax-violation input-form.stx subject-expr.stx)
		      (make-type-syntactic-identifier-condition type-id)
		      (make-type-method-name-condition method-name.sym)))))))

    ;;;

    (define (%vicare-struct-method-call input-form.stx lexenv.run lexenv.expand
					method-name.id method-name.sym
					type-id
					subject-expr.stx subject-expr.psi arg*.stx)
      (define expr.core
	(psi-core-expr subject-expr.psi))
      (cond ((null? arg*.stx)
	     ;;No arguments, let's go for an accessor application.
	     (let* ((std         (%struct-type-id->std __module_who__ input-form.stx type-id lexenv.run))
		    (field-names (struct-type-field-names std))
		    (field-idx   (%struct-field-name->struct-field-idx __module_who__ input-form.stx field-names method-name.id)))
	       (make-psi input-form.stx
			 (build-application input-form.stx
			   (build-primref no-source 'struct-and-std-ref)
			   (list expr.core
				 (build-data no-source field-idx)
				 (build-data no-source std)))
			 (make-retvals-signature-single-top))))
	    ((and (pair? arg*.stx)
		  (null? (cdr arg*.stx)))
	     ;;Only one argument, let's go for a mutator application.
	     (let* ((std         (%struct-type-id->std __module_who__ input-form.stx type-id lexenv.run))
		    (field-names (struct-type-field-names std))
		    (field-idx   (%struct-field-name->struct-field-idx __module_who__ input-form.stx field-names method-name.id))
		    (arg.psi     (chi-expr (car arg*.stx) lexenv.run lexenv.expand))
		    (arg.core    (psi-core-expr arg.psi)))
	       (make-psi input-form.stx
			 (build-application input-form.stx
			   (build-primref no-source 'struct-and-std-set!)
			   (list expr.core
				 (build-data no-source field-idx)
				 (build-data no-source std)
				 arg.core))
			 (make-retvals-signature-single-void))))
	    (else
	     (raise
	      (condition (make-who-condition __module_who__)
			 (make-message-condition "unsupported method call operation on struct-type of subject expression")
			 (make-syntax-violation input-form.stx subject-expr.stx)
			 (make-type-syntactic-identifier-condition type-id))))))

    #| end of module: %EXPAND-TO-EARLY-BINDING-METHOD-CALL |# )

;;; --------------------------------------------------------------------

  (define (%expand-to-late-binding-method-call input-form.stx lexenv.run lexenv.expand
					       method-name.sym subject-expr.psi arg*.stx)
    ;;The  type of  the  values returned  by  the subject  expression  is unknown  at
    ;;expand-time; so we  expand to an expression that searches  at run-time a method
    ;;matching the  given name.  In other  words: we default to  "late binding" (also
    ;;known as "run-time dispatching").
    ;;
    (let* ((expr.core	(psi-core-expr subject-expr.psi))
	   (arg*.psi	(chi-expr* arg*.stx lexenv.run lexenv.expand))
	   (arg*.core	(map psi-core-expr arg*.psi)))
      (make-psi input-form.stx
		(build-application input-form.stx
		  (build-primref no-source 'method-call-late-binding)
		  (cons* (build-data no-source method-name.sym)
			 expr.core
			 arg*.core))
		(make-retvals-signature-fully-unspecified))))

  #| end of module |# )


;;;; module core-macro-transformer: TAG-PREDICATE

(define-core-transformer (tag-predicate input-form.stx lexenv.run lexenv.expand)
  ;;Transformer  function used  to expand  Vicare's TAG-PREDICATE  syntaxes from  the
  ;;top-level built in  environment.  Expand the syntax object  INPUT-FORM.STX in the
  ;;context of the given LEXENV; return a PSI struct.
  ;;
  (syntax-match input-form.stx ()
    ((_ ?tag)
     (tag-identifier? ?tag)
     (chi-expr (tag-identifier-predicate ?tag input-form.stx) lexenv.run lexenv.expand))
    ))


;;;; module core-macro-transformer: TAG-PROCEDURE-ARGUMENT-VALIDATOR, TAG-RETURN-VALUE-VALIDATOR

(define-core-transformer (tag-procedure-argument-validator input-form.stx lexenv.run lexenv.expand)
  ;;Transformer  function used  to  expand Vicare's  TAG-PROCEDURE-ARGUMENT-VALIDATOR
  ;;syntaxes  from the  top-level built  in  environment.  Expand  the syntax  object
  ;;INPUT-FORM.STX in the context of the given LEXENV; return a PSI struct.
  ;;
  (syntax-match input-form.stx (<>)
    ((_ ?tag <>)
     (tag-identifier? ?tag)
     (let* ((obj.sym		(gensym))
	    (output-form.sexp	`(lambda (,obj.sym)
				   (if ((tag-predicate ,?tag) ,obj.sym)
				       ,obj.sym
				     (procedure-argument-violation (quote ,?tag) "invalid object type" ,obj.sym)))))
       (chi-expr (bless output-form.sexp) lexenv.run lexenv.expand)))
    ((_ ?tag ?expr)
     (tag-identifier? ?tag)
     (let* ((obj.sym		(gensym))
	    (output-form.sexp	`(let ((,obj.sym ,?expr))
				   (if ((tag-predicate ,?tag) ,obj.sym)
				       ,obj.sym
				     (procedure-argument-violation (quote ,?tag) "invalid object type" ,obj.sym)))))
       (chi-expr (bless output-form.sexp) lexenv.run lexenv.expand)))
    ))

(define-core-transformer (tag-return-value-validator input-form.stx lexenv.run lexenv.expand)
  ;;Transformer function used to  expand Vicare's TAG-RETURN-VALUE-VALIDATOR syntaxes
  ;;from the top-level built in environment.  Expand the syntax object INPUT-FORM.STX
  ;;in the context of the given LEXENV; return a PSI struct.
  ;;
  (syntax-match input-form.stx (<>)
    ((_ ?tag <>)
     (tag-identifier? ?tag)
     (let* ((obj.sym		(gensym))
	    (output-form.sexp	`(lambda (,obj.sym)
				   (if ((tag-predicate ,?tag) ,obj.sym)
				       ,obj.sym
				     (expression-return-value-violation (quote ,?tag) "invalid object type" ,obj.sym)))))
       (chi-expr (bless output-form.sexp) lexenv.run lexenv.expand)))
    ((_ ?tag ?expr)
     (tag-identifier? ?tag)
     (let* ((obj.sym		(gensym))
	    (output-form.sexp	`(let ((,obj.sym ,?expr))
				   (if ((tag-predicate ,?tag) ,obj.sym)
				       ,obj.sym
				     (expression-return-value-violation (quote ,?tag) "invalid object type" ,obj.sym)))))
       (chi-expr (bless output-form.sexp) lexenv.run lexenv.expand)))
    ))


;;;; module core-macro-transformer: TAG-ASSERT

(module (tag-assert-transformer)
  ;;Transformer  function  used  to  expand Vicare's  TAG-ASSERT  syntaxes  from  the
  ;;top-level built in  environment.  Expand the syntax object  INPUT-FORM.STX in the
  ;;context of the given LEXENV; return a PSI struct.
  ;;
  (define-core-transformer (tag-assert input-form.stx lexenv.run lexenv.expand)
    (syntax-match input-form.stx ()
      ((_ ?retvals-signature ?expr)
       (retvals-signature-syntax? ?retvals-signature)
       (let* ((asserted.sig (make-retvals-signature ?retvals-signature))
	      (expr.psi     (chi-expr ?expr lexenv.run lexenv.expand))
	      (expr.sig     (psi-retvals-signature expr.psi)))
	 (cond ((list-tag-id? ?retvals-signature)
		;;If we are here the input form is:
		;;
		;;   (tag-assert <list> ?expr)
		;;
		;;and  any tuple  of returned  values returned  by ?EXPR  is of  type
		;;"<list>".
		(%just-evaluate-the-expression expr.psi))

	       ((retvals-signature-single-top-tag? asserted.sig)
		;;If we are here the input form is:
		;;
		;;   (tag-assert (<top>) ?expr)
		;;
		;;so it is  enough to make sure that the  expression returns a single
		;;value, whatever its type.
		(syntax-match (retvals-signature-tags expr.sig) ()
		  ((?tag)
		   ;;Success!!!   We   have  determined   at  expand-time   that  the
		   ;;expression returns a single value.
		   (%just-evaluate-the-expression expr.psi))
		  (?tag
		   (list-tag-id? ?tag)
		   ;;Damn   it!!!   The   expression's  return   values  have   fully
		   ;;unspecified signature; we need to insert a run-time check.
		   (%run-time-validation input-form.stx lexenv.run lexenv.expand
					 asserted.sig expr.psi))
		  (_
		   ;;The  horror!!!   We have  established  at  expand-time that  the
		   ;;expression returns multiple values; assertion failed.
		   (expand-time-retvals-signature-violation __who__ input-form.stx ?expr asserted.sig expr.sig))
		  ))

	       ((retvals-signature-partially-unspecified? expr.sig)
		;;Damn it!!!  The expression has  no type specification or  a partial
		;;type specification; we have to insert a run-time check.
		;;
		;;FIXME We can  do better here by inserting the  run-time checks only
		;;for  the "<top>"  return values,  rather than  for all  the values.
		;;(Marco Maggi; Fri Apr 4, 2014)
		(%run-time-validation input-form.stx lexenv.run lexenv.expand
				      asserted.sig expr.psi))

	       ((retvals-signature-super-and-sub? asserted.sig expr.sig)
		;;Success!!!  We  have established  at expand-time that  the returned
		;;values are valid; assertion succeeded.
		(%just-evaluate-the-expression expr.psi))

	       (else
		;;The horror!!!  We  have established at expand-time  that the returned
		;;values are of the wrong type; assertion failed.
		(expand-time-retvals-signature-violation __who__ input-form.stx ?expr asserted.sig expr.sig)))))

       ((_ ?retvals-signature ?expr)
	;;Let's use a descriptive error message here.
	(%synner "invalid return values signature" ?retvals-signature))
       ))

  (define* (%run-time-validation input-form.stx lexenv.run lexenv.expand
				 {asserted.sig retvals-signature?} {expr.psi psi?})
    (define expr.core (psi-core-expr         expr.psi))
    (define expr.sig  (psi-retvals-signature expr.psi))
    ;;Here we know that ASSERTED.SIG is a  valid retvals signature, so we can be less
    ;;strict in the patterns.
    (syntax-match (retvals-signature-tags asserted.sig) ()
      ((?rv-tag* ...)
       (let* ((TMP*         (generate-temporaries ?rv-tag*))
	      (checker.psi  (chi-expr (bless
				       `(lambda ,TMP*
					  ,@(map (lambda (tmp tag)
						   `(tag-return-value-validator ,tag ,tmp))
					      TMP* ?rv-tag*)
					  (void)))
				      lexenv.run lexenv.expand)))
	 (%run-time-check-output-form input-form.stx lexenv.run lexenv.expand
				      expr.core checker.psi)))

      ((?rv-tag* ... . ?rv-rest-tag)
       (let* ((TMP*         (generate-temporaries ?rv-tag*))
	      (checker.psi  (chi-expr (bless
				       `(lambda (,@TMP* . rest-tmp)
					  ,@(map (lambda (tmp tag)
						   `(tag-return-value-validator ,tag ,tmp))
					      TMP* ?rv-tag*)
					  (tag-return-value-validator ,?rv-rest-tag rest-tmp)
					  (void)))
				      lexenv.run lexenv.expand)))
	 (%run-time-check-output-form  input-form.stx lexenv.run lexenv.expand
				       expr.core checker.psi)))

      (?rv-args-tag
       (let ((checker.psi  (chi-expr (bless
				      `(lambda args
					 (tag-return-value-validator ,?rv-args-tag args)
					 (void)))
				     lexenv.run lexenv.expand)))
	 (%run-time-check-output-form  input-form.stx lexenv.run lexenv.expand
				       expr.core checker.psi)))
      ))

  (define (%just-evaluate-the-expression expr.psi)
    (make-psi (psi-stx expr.psi)
	      (build-sequence no-source
		(list (psi-core-expr expr.psi)
		      (build-void)))
	      ;;We know that we are returning a single void argument.
	      (make-retvals-signature-single-top)))

  (define (%run-time-check-output-form input-form.stx lexenv.run lexenv.expand
				       expr.core checker.psi)
    ;;We build a core language expression as follows:
    ;;
    ;;   (call-with-values
    ;;        (lambda () ?expr)
    ;;     (lambda ?formals
    ;;       ?check-form ...
    ;;       (void)))
    ;;
    (let* ((cwv.core     (build-primref no-source 'call-with-values))
	   (checker.core (psi-core-expr checker.psi)))
      (make-psi input-form.stx
		(build-application no-source
		  cwv.core
		  (list (build-lambda no-source '() expr.core)
			checker.core))
		;;We know that we are returning a single void argument.
		(make-retvals-signature-single-top))))

  #| end of module: TAG-ASSERT-TRANSFORMER |# )


;;;; module core-macro-transformer: TAG-ASSERT-AND-RETURN

(module (tag-assert-and-return-transformer)
  ;;Transformer function used to  expand Vicare's TAG-ASSERT-AND-RETURN syntaxes from
  ;;the top-level built  in environment.  Expand the syntax  object INPUT-FORM.STX in
  ;;the context of the given LEXENV; return a PSI struct.
  ;;
  (define-core-transformer (tag-assert-and-return input-form.stx lexenv.run lexenv.expand)
    (syntax-match input-form.stx ()
      ((_ ?retvals-signature ?expr)
       (retvals-signature-syntax? ?retvals-signature)
       (let* ((asserted.sig (make-retvals-signature ?retvals-signature))
	      (expr.psi     (chi-expr ?expr lexenv.run lexenv.expand))
	      (expr.sig     (psi-retvals-signature expr.psi)))
	 (cond ((list-tag-id? ?retvals-signature)
		;;If we are here the input form is:
		;;
		;;   (tag-assert-and-return <list> ?expr)
		;;
		;;and  any tuple  of returned  values returned  by ?EXPR  is of  type
		;;"<list>".  Just evaluate the expression.
		;;
		;;NOTE  The signature  validation has  succeeded at  expand-time: the
		;;returned PSI has the original  ?EXPR signature, not "<list>".  This
		;;just looks nicer.
		expr.psi)

	       ((retvals-signature-single-top-tag? asserted.sig)
		;;If we are here the input form is:
		;;
		;;   (tag-assert-and-return (<top>) ?expr)
		;;
		;;so it is  enough to make sure that the  expression returns a single
		;;value, whatever its type.
		(syntax-match (retvals-signature-tags expr.sig) ()
		  ((?tag)
		   ;;Success!!!   We   have  determined   at  expand-time   that  the
		   ;;expression returns a single  value.
		   ;;
		   ;;IMPORTANT  NOTE  The  signature   validation  has  succeeded  at
		   ;;expand-time:  the returned  PSI *must*  have the  original ?EXPR
		   ;;signature,  not ASSERTED.SIG;  this  even  when ASSERTED.SIG  is
		   ;;"(<top>)".   This  property is  used  in  binding syntaxes  when
		   ;;propagating a tag from the RHS to the LHS.
		   expr.psi)
		  (?tag
		   (list-tag-id? ?tag)
		   ;;Damn   it!!!   The   expression's  return   values  have   fully
		   ;;unspecified signature;  we rely on the  low-level built-in check
		   ;;for single return value.
		   (make-psi input-form.stx (psi-core-expr expr.psi) asserted.sig))
		  (_
		   ;;The  horror!!!   We have  established  at  expand-time that  the
		   ;;expression returns multiple values; assertion failed.
		   (expand-time-retvals-signature-violation __who__ input-form.stx ?expr asserted.sig expr.sig))
		  ))

	       ((retvals-signature-partially-unspecified? expr.sig)
		;;The  expression has  no type  specification;  we have  to insert  a
		;;run-time check.
		;;
		;;FIXME We can  do better here by inserting the  run-time checks only
		;;for  the "<top>"  return values,  rather than  for all  the values.
		;;(Marco Maggi; Fri Apr 4, 2014)
		(%run-time-validation input-form.stx lexenv.run lexenv.expand
				      asserted.sig expr.psi))

	       ((retvals-signature-super-and-sub? asserted.sig expr.sig)
		;;Fine, we have  established at expand-time that  the returned values
		;;are valid; assertion succeeded.  Just evaluate the expression.
		expr.psi)

	       (else
		;;The horror!!!  We have established at expand-time that the returned
		;;values are of the wrong type; assertion failed.
		(expand-time-retvals-signature-violation __who__ input-form.stx ?expr asserted.sig expr.sig)))))

      ((_ ?retvals-signature ?expr)
       ;;Let's use a descriptive error message here.
       (%synner "invalid return values signature" ?retvals-signature))
      ))

  (define* (%run-time-validation input-form.stx lexenv.run lexenv.expand
				 {asserted.sig retvals-signature?} {expr.psi psi?})
    (define expr.core (psi-core-expr         expr.psi))
    (define expr.sig  (psi-retvals-signature expr.psi))
    ;;Here we know that ASSERTED.SIG is a  valid formals signature, so we can be less
    ;;strict in the patterns.
    (syntax-match (retvals-signature-tags asserted.sig) ()
      ;;Special handling for single value.
      ((?rv-tag)
       (let* ((checker.psi (chi-expr (bless
				      `(lambda (t)
					 (tag-return-value-validator ,?rv-tag t)
					 t))
				     lexenv.run lexenv.expand))
	      (checker.core (psi-core-expr checker.psi))
	      (expr.core    (psi-core-expr expr.psi)))
	 (make-psi input-form.stx
		   (build-application no-source
		     checker.core
		     (list expr.core))
		   ;;The type  of the  value returned by  ?EXPR was  unspecified, but
		   ;;after asserting the  type at run-time: we know that  the type is
		   ;;the asserted one.
		   asserted.sig)))

      ((?rv-tag* ...)
       (let* ((TMP*         (generate-temporaries ?rv-tag*))
	      (checker.psi  (chi-expr (bless
				       `(lambda ,TMP*
					  ,@(map (lambda (tmp tag)
						   `(tag-return-value-validator ,tag ,tmp))
					      TMP* ?rv-tag*)
					  (values . ,TMP*)))
				      lexenv.run lexenv.expand)))
	 (%run-time-check-multiple-values-output-form input-form.stx lexenv.run lexenv.expand
						      expr.psi checker.psi asserted.sig)))

      ((?rv-tag* ... . ?rv-rest-tag)
       (let* ((TMP*         (generate-temporaries ?rv-tag*))
	      (checker.psi  (chi-expr (bless
				       `(lambda (,@TMP* . rest-tmp)
					  ,@(map (lambda (tmp tag)
						   `(tag-return-value-validator ,tag ,tmp))
					      TMP* ?rv-tag*)
					  (tag-return-value-validator ,?rv-rest-tag rest-tmp)
					  (apply values ,@TMP* rest-tmp)))
				      lexenv.run lexenv.expand)))
	 (%run-time-check-multiple-values-output-form input-form.stx lexenv.run lexenv.expand
						      expr.psi checker.psi asserted.sig)))

      (?rv-args-tag
       (let ((checker.psi  (chi-expr (bless
				      `(lambda args
					 (tag-return-value-validator ,?rv-args-tag args)
					 (apply values args)))
				     lexenv.run lexenv.expand)))
	 (%run-time-check-multiple-values-output-form input-form.stx lexenv.run lexenv.expand
						      expr.psi checker.psi asserted.sig)))
      ))

  (define* (%run-time-check-multiple-values-output-form input-form.stx lexenv.run lexenv.expand
							{expr.psi psi?} {checker.psi psi?} {asserted.sig retvals-signature?})
    ;;We build a core language expression as follows:
    ;;
    ;;   (call-with-values
    ;;        (lambda () ?expr)
    ;;     (lambda ?formals
    ;;       ?check-form ...
    ;;       (apply values ?formals)))
    ;;
    ;;The returned PSI struct has the given retvals signature.
    ;;
    (let* ((cwv.core     (build-primref no-source 'call-with-values))
	   (expr.core    (psi-core-expr expr.psi))
	   (checker.core (psi-core-expr checker.psi)))
      (make-psi input-form.stx
		(build-application no-source
		  cwv.core
		  (list (build-lambda no-source
			  '()
			  expr.core)
			checker.core))
		;;The type  of values  returned by ?EXPR  was unspecified,  but after
		;;asserting  the type  at  run-time: we  know that  the  type is  the
		;;asserted one.
		asserted.sig)))

  #| end of module: TAG-ASSERT-AND-RETURN-TRANSFORMER |# )


;;;; module core-macro-transformer: TAG-ACCESSOR, TAG-MUTATOR

(define-core-transformer (tag-accessor input-form.stx lexenv.run lexenv.expand)
  ;;Transformer  function used  to  expand Vicare's  TAG-ACCESSOR  syntaxes from  the
  ;;top-level built in  environment.  Expand the syntax object  INPUT-FORM.STX in the
  ;;context of the given LEXENV; return a PSI struct.
  ;;
  (syntax-match input-form.stx ()
    ((_ ?expr ?field-name-id)
     (identifier? ?field-name-id)
     (let* ((expr.psi  (chi-expr ?expr lexenv.run lexenv.expand))
	    (expr.sign (psi-retvals-signature expr.psi)))
       (if (retvals-signature-fully-unspecified? expr.sign)
	   (%synner "unable to determine tag of expression")
	 (syntax-match (retvals-signature-tags expr.sign) ()
	   ((?tag)
	    (let ((accessor.stx (tag-identifier-accessor ?tag ?field-name-id input-form.stx)))
	      (chi-application/psi-first-operand input-form.stx lexenv.run lexenv.expand
						 accessor.stx expr.psi '())))
	   (_
	    (%synner "invalid expression retvals signature" expr.sign))
	   ))))
    ))

(define-core-transformer (tag-mutator input-form.stx lexenv.run lexenv.expand)
  ;;Transformer  function  used to  expand  Vicare's  TAG-MUTATOR syntaxes  from  the
  ;;top-level built in  environment.  Expand the syntax object  INPUT-FORM.STX in the
  ;;context of the given LEXENV; return a PSI struct.
  ;;
  (syntax-match input-form.stx ()
    ((_ ?expr ?field-name-id ?new-value)
     (identifier? ?field-name-id)
     (let* ((expr.psi  (chi-expr ?expr lexenv.run lexenv.expand))
	    (expr.sign (psi-retvals-signature expr.psi)))
       (if (retvals-signature-fully-unspecified? expr.sign)
	   (%synner "unable to determine tag of expression")
	 (syntax-match (retvals-signature-tags expr.sign) ()
	   ((?tag)
	    (let ((mutator.stx (tag-identifier-mutator ?tag ?field-name-id input-form.stx)))
	      (chi-application/psi-first-operand input-form.stx lexenv.run lexenv.expand
						 mutator.stx expr.psi (list ?new-value))))
	   (_
	    (%synner "invalid expression retvals signature" expr.sign))
	   ))))
    ))


;;;; module core-macro-transformer: TAG-GETTER, TAG-SETTER

(define-core-transformer (tag-getter input-form.stx lexenv.run lexenv.expand)
  ;;Transformer  function  used  to  expand Vicare's  TAG-GETTER  syntaxes  from  the
  ;;top-level built in  environment.  Expand the syntax object  INPUT-FORM.STX in the
  ;;context of the given LEXENV; return a PSI struct.
  ;;
  (define (%generate-output-form expr.stx keys.stx)
    (let* ((expr.psi  (chi-expr expr.stx lexenv.run lexenv.expand))
	   (expr.sign (psi-retvals-signature expr.psi)))
      (if (retvals-signature-fully-unspecified? expr.sign)
	  (%synner "unable to determine tag of expression")
	(syntax-match (retvals-signature-tags expr.sign) ()
	  ((?tag)
	   (let ((getter.stx (tag-identifier-getter ?tag keys.stx input-form.stx)))
	     (chi-application/psi-first-operand input-form.stx lexenv.run lexenv.expand
						getter.stx expr.psi '())))
	  (_
	   (%synner "invalid expression retvals signature" expr.sign))
	  ))))
  (syntax-match input-form.stx ()
    ((_ ?expr ((?key00 ?key0* ...) (?key11* ?key1** ...) ...))
     (%generate-output-form ?expr (cons (cons ?key00 ?key0*) (map cons ?key11* ?key1**))))
    ((_ ?expr (?key00 ?key0* ...) (?key11* ?key1** ...) ...)
     (%generate-output-form ?expr (cons (cons ?key00 ?key0*) (map cons ?key11* ?key1**))))
    ))

(define-core-transformer (tag-setter input-form.stx lexenv.run lexenv.expand)
  ;;Transformer  function  used  to  expand Vicare's  TAG-SETTER  syntaxes  from  the
  ;;top-level built in  environment.  Expand the syntax object  INPUT-FORM.STX in the
  ;;context of the given LEXENV; return a PSI struct.
  ;;
  (define (%generate-output-form expr.stx keys.stx new-value.stx)
    (let* ((expr.psi  (chi-expr expr.stx lexenv.run lexenv.expand))
	   (expr.sign (psi-retvals-signature expr.psi)))
      (if (retvals-signature-fully-unspecified? expr.sign)
	  (%synner "unable to determine tag of expression")
	(syntax-match (retvals-signature-tags expr.sign) ()
	  ((?tag)
	   (let ((setter.stx  (tag-identifier-setter ?tag keys.stx input-form.stx)))
	     (chi-application/psi-first-operand input-form.stx lexenv.run lexenv.expand
						setter.stx expr.psi (list new-value.stx))))
	  (_
	   (%synner "invalid expression retvals signature" expr.sign))
	  ))))
  (syntax-match input-form.stx ()
    ((_ ?expr ((?key00 ?key0* ...) (?key11* ?key1** ...) ...) ?new-value)
     (%generate-output-form ?expr (cons (cons ?key00 ?key0*) (map cons ?key11* ?key1**)) ?new-value))
    ((_ ?expr (?key00 ?key0* ...) (?key11* ?key1** ...) ... ?new-value)
     (%generate-output-form ?expr (cons (cons ?key00 ?key0*) (map cons ?key11* ?key1**)) ?new-value))
    ))


;;;; module core-macro-transformer: TAG-DISPATCH

(define-core-transformer (tag-dispatch input-form.stx lexenv.run lexenv.expand)
  ;;Transformer  function used  to  expand Vicare's  TAG-DISPATCH  syntaxes from  the
  ;;top-level built in  environment.  Expand the syntax object  INPUT-FORM.STX in the
  ;;context of the given LEXENV; return a PSI struct.
  ;;
  (syntax-match input-form.stx ()
    ((_ ?expr ?member ?arg* ...)
     (identifier? ?member)
     (let* ((expr.psi  (chi-expr ?expr lexenv.run lexenv.expand))
	    (expr.sign (psi-retvals-signature expr.psi)))
      (if (retvals-signature-fully-unspecified? expr.sign)
	  (%synner "unable to determine tag of expression")
	(syntax-match (retvals-signature-tags expr.sign) ()
	  ((?tag)
	   (let ((method.stx (tag-identifier-dispatch ?tag ?member input-form.stx)))
	     (chi-application/psi-first-operand input-form.stx lexenv.run lexenv.expand
						method.stx expr.psi ?arg*)))
	  (_
	   (%synner "invalid expression retvals signature" expr.sign))
	  ))))
    ))


;;;; module core-macro-transformer: TAG-CAST

(define-core-transformer (tag-cast input-form.stx lexenv.run lexenv.expand)
  ;;Transformer function used to expand Vicare's TAG-CAST syntaxes from the top-level
  ;;built in environment.  Expand the syntax  object INPUT-FORM.STX in the context of
  ;;the given LEXENV; return a PSI struct.
  ;;

  (define (%retrieve-caster-maker target-tag)
    (cond ((identifier-tag-type-spec target-tag)
	   => tag-type-spec-caster-maker)
	  (else
	   (syntax-violation/internal-error __who__ "tag identifier without object type spec" input-form.stx))))

  (define (%cast-at-run-time-with-generic-transformer target-tag expr.psi)
    ;;When the  type of the expression  is unknown at expand-time:  insert a run-time
    ;;expression that will  try to convert whatever source value  into a target value
    ;;of the requested type.
    ;;
    (cond ((%retrieve-caster-maker target-tag)
	   => (lambda (target-caster-maker)
		(let* ((caster.stx   (target-caster-maker #f input-form.stx))
		       (caster.psi   (chi-expr caster.stx lexenv.run lexenv.expand))
		       (caster.core  (psi-core-expr caster.psi))
		       (expr.core    (psi-core-expr expr.psi)))
		  ;;This form  will either succeed or  raise an exception, so  we can
		  ;;tag this PSI with the target tag.
		  (make-psi (psi-stx expr.psi)
			    (build-application no-source
			      caster.core
			      (list expr.core))
			    (make-retvals-signature (list target-tag))))))
	  (else
	   (%validate-and-return target-tag expr.psi))))

  (define (%validate-and-return target-tag expr.psi)
    ;;When the  source tag  is unknown  or incompatible  with the  target tag  and no
    ;;transformer  function was  found  for  the target  tag:  we  insert a  run-time
    ;;expression that validates and returns the value.
    ;;
    (let* ((expr.core       (psi-core-expr expr.psi))
  	   (type-name.core  (build-data no-source
			      (syntax->datum target-tag)))
  	   (predicate.psi   (chi-expr (tag-identifier-predicate target-tag input-form.stx)
				      lexenv.run lexenv.expand))
  	   (predicate.core  (psi-core-expr predicate.psi))
	   (validator.sexp  (let ((obj.sym		(gensym))
				  (type-name.sym	(gensym))
				  (pred.sym		(gensym)))
			      `(lambda (,type-name.sym ,pred.sym ,obj.sym)
				 (if (,pred.sym ,obj.sym)
				     ,obj.sym
				   (expression-return-value-violation ,type-name.sym "invalid object type" ,obj.sym)))))
	   (validator.psi   (chi-expr (bless validator.sexp) lexenv.run lexenv.expand))
	   (validator.core  (psi-core-expr validator.psi)))
      ;;This form will either  succeed or raise an exception, so we  can tag this PSI
      ;;with the target tag.
      (make-psi (psi-stx expr.psi)
		(build-application no-source
		  validator.core
  		  (list type-name.core predicate.core expr.core))
  		(make-retvals-signature (list target-tag)))))

  (syntax-match input-form.stx ()
    ((_ ?target-tag ?expr)
     (tag-identifier? ?target-tag)
     (let* ((expr.psi  (chi-expr ?expr lexenv.run lexenv.expand))
	    (expr.core (psi-core-expr expr.psi))
	    (expr.sign (psi-retvals-signature expr.psi)))
       (if (retvals-signature-fully-unspecified? expr.sign)
	   (%cast-at-run-time-with-generic-transformer ?target-tag expr.psi)
	 (syntax-match (retvals-signature-tags expr.sign) ()
	   ((?source-tag)
	    (cond ((top-tag-id? ?target-tag)
		   ;;The expression  already has the  right type: nothing to  do, just
		   ;;return it.
		   expr.psi)
		  ((top-tag-id? ?source-tag)
		   (%cast-at-run-time-with-generic-transformer ?target-tag expr.psi))
		  ((tag-super-and-sub? ?target-tag ?source-tag)
		   ;;The expression  already has the  right type: nothing to  do, just
		   ;;return it.
		   expr.psi)
		  (else
		   ;;The tag  of expression  is incompatible  with the  requested tag.
		   ;;Try to select an appropriate caster operator.
		   (cond ((%retrieve-caster-maker ?target-tag)
			  => (lambda (target-caster-maker)
			       (let* ((caster.stx   (target-caster-maker ?source-tag input-form.stx))
				      (caster.psi   (chi-expr caster.stx lexenv.run lexenv.expand))
				      (caster.core  (psi-core-expr caster.psi)))
				 (make-psi input-form.stx
					   (build-application (syntax-annotation input-form.stx)
					     caster.core
					     (list expr.core))
					   (make-retvals-signature (list ?target-tag))))))
			 (else
			  (%validate-and-return ?target-tag expr.psi))))))

	   (_
	    (%synner "invalid expression retvals signature" expr.sign))
	   ))))
    ))


;;;; module core-macro-transformer: TAG-UNSAFE-CAST

(define-core-transformer (tag-unsafe-cast input-form.stx lexenv.run lexenv.expand)
  ;;Transformer function  used to expand  Vicare's TAG-UNSAFE-CAST syntaxes  from the
  ;;top-level built in  environment.  Expand the syntax object  INPUT-FORM.STX in the
  ;;context of the given LEXENV; return a PSI struct.
  ;;
  (syntax-match input-form.stx ()
    ((_ ?target-tag ?expr)
     (tag-identifier? ?target-tag)
     (let* ((expr.psi  (chi-expr ?expr lexenv.run lexenv.expand))
	    (expr.core (psi-core-expr expr.psi))
	    (expr.sign (psi-retvals-signature expr.psi)))
       (if (retvals-signature-fully-unspecified? expr.sign)
	   ;;The  expression has  non-specified values  type:  cast the  type to  the
	   ;;target one.  Hey!  It is UNSAFE cast!
	   (make-psi input-form.stx
		     expr.core
		     (make-retvals-signature-single-value ?target-tag))
	 (syntax-match (retvals-signature-tags expr.sign) ()
	   ((?source-tag)
	    (cond ((top-tag-id? ?target-tag)
		   ;;The expression already  has the right type: nothing  to do, just
		   ;;return it.
		   expr.psi)
		  ((top-tag-id? ?source-tag)
		   ;;The  expression has  non-specified single-value  type: cast  the
		   ;;type to the target one.
		   (make-psi input-form.stx
			     expr.core
			     (make-retvals-signature-single-value ?target-tag)))
		  ((tag-super-and-sub? ?target-tag ?source-tag)
		   ;;The expression already  has the right type: nothing  to do, just
		   ;;return it.
		   expr.psi)
		  (else
		   (%synner "the tag of expression is incompatible with the requested tag" expr.sign))))
	   (_
	    (%synner "invalid expression retvals signature" expr.sign))
	   ))))
    ))


;;;; module core-macro-transformer: TYPE-OF

(define-core-transformer (type-of input-form.stx lexenv.run lexenv.expand)
  ;;Transformer function used to expand  Vicare's TYPE-OF syntaxes from the top-level
  ;;built in environment.  Expand the syntax  object INPUT-FORM.STX in the context of
  ;;the given LEXENV; return a PSI struct.
  ;;
  (syntax-match input-form.stx ()
    ((_ ?expr)
     (let* ((expr.psi (chi-expr ?expr lexenv.run lexenv.expand))
	    (expr.sig (psi-retvals-signature expr.psi)))
       (make-psi input-form.stx
		 (build-data no-source
		   expr.sig)
		 (make-retvals-signature-single-top))))
    ))


;;;; module core-macro-transformer: EXPANSION-OF

(define-core-transformer (expansion-of input-form.stx lexenv.run lexenv.expand)
  ;;Transformer  function used  to  expand Vicare's  EXPANSION-OF  syntaxes from  the
  ;;top-level built in  environment.  Expand the syntax object  INPUT-FORM.STX in the
  ;;context of the given LEXENV; return a PSI struct.
  ;;
  (syntax-match input-form.stx ()
    ;;Special case to allow easy inspection of definitions.  We transform:
    ;;
    ;;   (define . ?stuff)
    ;;
    ;;into:
    ;;
    ;;   (internal-body (define . ?stuff) (void))
    ;;
    ((_ (?define . ?stuff))
     (and (identifier? ?define)
	  (or (~free-identifier=? ?define (core-prim-id 'define))
	      (~free-identifier=? ?define (core-prim-id 'define*))))
     (let* ((expr.stx `(,(core-prim-id 'internal-body)
			(,?define . ,?stuff)
			(,(core-prim-id 'void))))
	    (expr.psi  (chi-expr expr.stx lexenv.run lexenv.expand))
	    (expr.core (psi-core-expr expr.psi))
	    (expr.sexp (core-language->sexp expr.core)))
       (let* ((out.sexp (map (lambda (bind*)
			       (list 'define (car bind*) (cadr bind*)))
			  (cadr expr.sexp)))
	      (out.sexp (if (= 1 (length out.sexp))
			    (car out.sexp)
			  (cons 'begin out.sexp))))
	 (make-psi input-form.stx
		   (build-data no-source
		     out.sexp)
		   (make-retvals-signature-single-top)))))

    ((_ ?expr)
     (let* ((expr.psi  (chi-expr ?expr lexenv.run lexenv.expand))
	    (expr.core (psi-core-expr expr.psi))
	    (expr.sexp (core-language->sexp expr.core)))
       (make-psi input-form.stx
		 (build-data no-source
		   expr.sexp)
		 (make-retvals-signature-single-top))))
    ))

(define-core-transformer (expansion-of* input-form.stx lexenv.run lexenv.expand)
  ;;Transformer  function used  to expand  Vicare's EXPANSION-OF*  syntaxes from  the
  ;;top-level built in  environment.  Expand the syntax object  INPUT-FORM.STX in the
  ;;context of the given LEXENV; return a PSI struct.
  ;;
  (syntax-match input-form.stx ()
    ((_ ?expr0 ?expr* ...)
     (chi-expr (bless `(expansion-of (internal-body ,?expr0 ,@?expr* (void))))
	       lexenv.run lexenv.expand))
    ))


;;;; module core-macro-transformer: VISIT-CODE-OF

(define-core-transformer (visit-code-of input-form.stx lexenv.run lexenv.expand)
  ;;Transformer  function used  to expand  Vicare's VISIT-CODE-OF  syntaxes from  the
  ;;top-level built in  environment.  Expand the syntax object  INPUT-FORM.STX in the
  ;;context of the given LEXENV; return a PSI struct.
  ;;
  (syntax-match input-form.stx ()
    ((_ ?id)
     (identifier? ?id)
     (let* ((label               (id->label/or-error __who__ input-form.stx ?id))
	    (binding-descriptor  (label->syntactic-binding-descriptor label lexenv.run))
	    (binding-value       (case (syntactic-binding-descriptor.type binding-descriptor)
				   ((local-macro local-macro!)
				    (syntactic-binding-descriptor.value binding-descriptor))
				   (else
				    (%synner "expected identifier of local macro" ?id)))))
       (make-psi input-form.stx
		 (build-data no-source
		   (core-language->sexp (cdr binding-value)))
		 (make-retvals-signature-single-top))))
    ))


;;;; module core-macro-transformer: OPTIMISATION-OF, OPTIMISATION-OF*, FURTHER-OPTIMISATION-OF, FURTHER-OPTIMISATION-OF*

(define-core-transformer (optimisation-of input-form.stx lexenv.run lexenv.expand)
  ;;Transformer function  used to expand  Vicare's OPTIMISATION-OF syntaxes  from the
  ;;top-level built in  environment.  Expand the syntax object  INPUT-FORM.STX in the
  ;;context of the given LEXENV; return a PSI struct.
  ;;
  (syntax-match input-form.stx ()
    ((_ ?expr)
     (let* ((expr.psi  (chi-expr ?expr lexenv.run lexenv.expand))
	    (expr.core (psi-core-expr expr.psi))
	    (expr.sexp (compiler.core-expr->optimized-code expr.core)))
       (make-psi input-form.stx
		 (build-data no-source
		   expr.sexp)
		 (make-retvals-signature-single-top))))
    ))

(define-core-transformer (optimisation-of* input-form.stx lexenv.run lexenv.expand)
  ;;Transformer function used  to expand Vicare's OPTIMISATION-OF*  syntaxes from the
  ;;top-level built in  environment.  Expand the syntax object  INPUT-FORM.STX in the
  ;;context of the given LEXENV; return a PSI struct.
  ;;
  (syntax-match input-form.stx ()
    ((_ ?expr0 ?expr* ...)
     (let* ((expr.psi  (chi-expr (bless `(internal-body ,?expr0 ,@?expr* (void)))
				 lexenv.run lexenv.expand))
	    (expr.core (psi-core-expr expr.psi))
	    (expr.sexp (compiler.core-expr->optimized-code expr.core)))
       (make-psi input-form.stx
		 (build-data no-source
		   expr.sexp)
		 (make-retvals-signature-single-top))))
    ))

(define-core-transformer (further-optimisation-of input-form.stx lexenv.run lexenv.expand)
  ;;Transformer  function used  to expand  Vicare's FURTHER-OPTIMISATION-OF  syntaxes
  ;;from the top-level built in environment.  Expand the syntax object INPUT-FORM.STX
  ;;in the context of the given LEXENV; return a PSI struct.
  ;;
  (syntax-match input-form.stx ()
    ((_ ?expr)
     (let* ((expr.psi  (chi-expr ?expr lexenv.run lexenv.expand))
	    (expr.core (psi-core-expr expr.psi))
	    (expr.sexp (compiler.core-expr->optimisation-and-core-type-inference-code expr.core)))
       (make-psi input-form.stx
		 (build-data no-source
		   expr.sexp)
		 (make-retvals-signature-single-top))))
    ))

(define-core-transformer (further-optimisation-of* input-form.stx lexenv.run lexenv.expand)
  ;;Transformer function  used to  expand Vicare's  FURTHER-OPTIMISATION-OF* syntaxes
  ;;from the top-level built in environment.  Expand the syntax object INPUT-FORM.STX
  ;;in the context of the given LEXENV; return a PSI struct.
  ;;
  (syntax-match input-form.stx ()
    ((_ ?expr0 ?expr* ...)
     (let* ((expr.psi  (chi-expr (bless `(internal-body ,?expr0 ,@?expr* (void)))
				 lexenv.run lexenv.expand))
	    (expr.core (psi-core-expr expr.psi))
	    (expr.sexp (compiler.core-expr->optimisation-and-core-type-inference-code expr.core)))
       (make-psi input-form.stx
		 (build-data no-source
		   expr.sexp)
		 (make-retvals-signature-single-top))))
    ))


;;;; module core-macro-transformer: ASSEMBLY-OF

(define-core-transformer (assembly-of input-form.stx lexenv.run lexenv.expand)
  ;;Transformer  function  used to  expand  Vicare's  ASSEMBLY-OF syntaxes  from  the
  ;;top-level built in  environment.  Expand the syntax object  INPUT-FORM.STX in the
  ;;context of the given LEXENV; return a PSI struct.
  ;;
  (syntax-match input-form.stx ()
    ((_ ?expr)
     (let* ((expr.psi  (chi-expr ?expr lexenv.run lexenv.expand))
	    (expr.core (psi-core-expr expr.psi))
	    (expr.sexp (compiler.core-expr->assembly-code expr.core)))
       (make-psi input-form.stx
		 (build-data no-source
		   expr.sexp)
		 (make-retvals-signature-single-top))))
    ))


;;;; done

;;; end of file
;;Local Variables:
;;mode: vicare
;;fill-column: 85
;;eval: (put 'build-library-letrec*		'scheme-indent-function 1)
;;eval: (put 'build-application			'scheme-indent-function 1)
;;eval: (put 'build-conditional			'scheme-indent-function 1)
;;eval: (put 'build-case-lambda			'scheme-indent-function 1)
;;eval: (put 'build-lambda			'scheme-indent-function 1)
;;eval: (put 'build-foreign-call		'scheme-indent-function 1)
;;eval: (put 'build-sequence			'scheme-indent-function 1)
;;eval: (put 'build-global-assignment		'scheme-indent-function 1)
;;eval: (put 'build-lexical-assignment		'scheme-indent-function 1)
;;eval: (put 'build-letrec*			'scheme-indent-function 1)
;;eval: (put 'build-data			'scheme-indent-function 1)
;;eval: (put 'core-lang-builder			'scheme-indent-function 1)
;;eval: (put 'case-object-type-binding		'scheme-indent-function 1)
;;eval: (put 'push-lexical-contour		'scheme-indent-function 1)
;;eval: (put 'syntactic-binding-getprop		'scheme-indent-function 1)
;;eval: (put 'sys.syntax-case			'scheme-indent-function 2)
;;eval: (put 'with-exception-handler/input-form	'scheme-indent-function 1)
;;eval: (put '$map-in-order			'scheme-indent-function 1)
;;End:
