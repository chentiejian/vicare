;;;Copyright (c) 2010-2016 Marco Maggi <marco.maggi-ipsu@poste.it>
;;;Copyright (c) 2006, 2007 Abdulaziz Ghuloum and Kent Dybvig
;;;
;;;Permission is hereby  granted, free of charge,  to any person obtaining  a copy of
;;;this software and associated documentation files  (the "Software"), to deal in the
;;;Software  without restriction,  including without  limitation the  rights to  use,
;;;copy, modify,  merge, publish, distribute,  sublicense, and/or sell copies  of the
;;;Software,  and to  permit persons  to whom  the Software  is furnished  to do  so,
;;;subject to the following conditions:
;;;
;;;The above  copyright notice and  this permission notice  shall be included  in all
;;;copies or substantial portions of the Software.
;;;
;;;THE  SOFTWARE IS  PROVIDED  "AS IS",  WITHOUT  WARRANTY OF  ANY  KIND, EXPRESS  OR
;;;IMPLIED, INCLUDING BUT  NOT LIMITED TO THE WARRANTIES  OF MERCHANTABILITY, FITNESS
;;;FOR A  PARTICULAR PURPOSE AND NONINFRINGEMENT.   IN NO EVENT SHALL  THE AUTHORS OR
;;;COPYRIGHT HOLDERS BE LIABLE FOR ANY  CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN
;;;AN ACTION OF  CONTRACT, TORT OR OTHERWISE,  ARISING FROM, OUT OF  OR IN CONNECTION
;;;WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


;;;; expansion of internal bodies
;;
;;The recursive function CHI-BODY* expands the forms of a body.  Here we expand:
;;
;;* User-defined the macro definitions and uses.
;;
;;* Non-core macro uses.
;;
;;* Basic language syntaxes: LIBRARY, MODULE, BEGIN, STALE-WHEN, IMPORT, EXPORT.
;;
;;but expand neither  the core macros nor the lexical  variable definitions (DEFINE
;;forms) and trailing expressions: the  variable definitions are accumulated in the
;;argument and return value QRHS* for later expansion; the trailing expressions are
;;accumulated in the argument and return value BODY-FORM*.STX for later expansion.
;;
;;Here is a description of the arguments.
;;
;;BODY-FORM*.STX must be null or a list of syntax objects representing the forms.
;;
;;LEXENV.RUN  and LEXENV.EXPAND  must  be lists  representing  the current  lexical
;;environment for run and expand times.
;;
;;LEX* must be a  list of gensyms and QRHS* must be a  list of qualified right-hand
;;sides representing right-hand  side expressions for DEFINE syntax  uses; they are
;;meant to  be processed together  item by item;  they are accumulated  in reversed
;;order.  Whenever the QRHS expressions are  expanded: a core language binding will
;;be created with a LEX gensym associated to a QRHS expression.
;;
;;About the MOD** argument.  We know that module definitions have the syntax:
;;
;;   (module (?export-id ...) ?definition ... ?expression ...)
;;
;;and the trailing  ?EXPRESSION forms must be evaluated after  the right-hand sides
;;of the DEFINE syntaxes  of the module but also of  the enclosing lexical context.
;;So, when expanding a MODULE, we  accumulate such expression syntax objects in the
;;MOD** argument as:
;;
;;   MOD** == ((?expression ...) ...)
;;
;;KWD* is  a list of  identifiers representing  the syntaxes and  lexical variables
;;defined in this body.  It is used to test for duplicate definitions.
;;
;;EXPORT-SPEC*  is  null or  a  list  of  syntax  objects representing  the  export
;;specifications from this body.  It is to be processed later.
;;
;;RIB is the current lexical environment's rib.
;;
;;MIX? is interpreted as boolean.  When false: the expansion process visits all the
;;definition forms and stops at the first expression form; the expression forms are
;;returned  to  the caller.   When  true:  the  expansion  process visits  all  the
;;definition  and  expression  forms,  accepting  a  mixed  sequence  of  them;  an
;;expression form is handled as a dummy definition form.
;;
;;When the argument SHADOW/REDEFINE-BINDINGS? is set to false:
;;
;;* Syntactic binding definitions in this body must *not* shadow syntactic bindings
;;established by the top-level environment.  For example, in the program:
;;
;;   (import (vicare))
;;   (define display 1)
;;   (debug-print display)
;;
;;the DEFINE use is a syntax violation  because the use of DEFINE cannot shadow the
;;binding imported from "(vicare)".
;;
;;*  Syntactic bindings  established  in the  body must  *not*  be redefined.   For
;;example, in the program:
;;
;;   (import (vicare))
;;   (define a 1)
;;   (define a 2)
;;   (debug-print a)
;;
;;the second  DEFINE use  is a syntax  violation because the  use of  DEFINE cannot
;;redefine the binding for "a".
;;
;;When the argument SHADOW/REDEFINE-BINDINGS? is set to true:
;;
;;* Syntactic  binding definitions  in this  body are  allowed to  shadow syntactic
;;bindings established by the top-level environment.  For example, at the REPL:
;;
;;   vicare> (import (vicare))
;;   vicare> (define display 1)
;;   vicare> (debug-print display)
;;
;;the  DEFINE use  is fine:  it  is allowed  to  shadow the  binding imported  from
;;"(vicare)".
;;
;;** Syntactic binding  definitions in the body can be  redefined.  For example, at
;;the REPL:
;;
;;  vicare> (begin
;;            (define a 1)
;;            (define a 2)
;;            (debug-print a))
;;
;;the second DEFINE use is fine: it can redefine the binding for "a".


(module (chi-body*)


(define* (chi-body* body-form*.stx lexenv.run lexenv.expand lex* qrhs* mod** kwd* export-spec* rib
		    mix? shadow/redefine-bindings?)
  (import CHI-DEFINE)
  (if (pair? body-form*.stx)
      (let*-values
	  (((body-form.stx)	(car body-form*.stx))
	   ((type descr kwd)	(syntactic-form-type __who__ body-form.stx lexenv.run)))

	(define keyword*
	  (if (identifier? kwd)
	      (cons kwd kwd*)
	    kwd*))

	(define-syntax-rule (%expand-internal-definition ?expander-who)
	  ;;Used  to  process an  internal  definition  core macro:  DEFINE/STANDARD,
	  ;;DEFINE/TYPED, CASE-DEFINE/STANDARD, CASE-DEFINE/TYPED.  We parse the body
	  ;;form and generate a qualified right-hand  side (QRHS) object that will be
	  ;;expanded later.
	  ;;
	  (receive (lex qrhs lexenv.run)
	      (?expander-who body-form.stx rib lexenv.run keyword* shadow/redefine-bindings?)
	    (chi-body* (cdr body-form*.stx)
		       lexenv.run lexenv.expand
		       (cons lex lex*) (cons qrhs qrhs*)
		       mod** keyword* export-spec* rib mix? shadow/redefine-bindings?)))

	(parametrise ((current-run-lexenv (lambda () lexenv.run)))
	  (case type

	    ((define/standard)
	     ;;The body form is a DEFINE/STANDARD core macro use, one among:
	     ;;
	     ;;   (define/standard ?lhs ?rhs)
	     ;;   (define/standard (?lhs . ?formals) . ?body)
	     ;;
	     ;;it is meant to be the implementation of R6RS's DEFINE syntax.
	     (%expand-internal-definition chi-define/standard))

	    ((case-define/standard)
	     ;;The body form is a CASE-DEFINE/STANDARD core macro use:
	     ;;
	     ;;   (case-define/standard ?lhs ?case-lambda-clause ...)
	     ;;
	     ;;it is meant to be equivalent to:
	     ;;
	     ;;   (define/standard ?lhs (case-lambda/standard ?case-lambda-clause ...))
	     ;;
	     (%expand-internal-definition chi-case-define/standard))

	    ((define/typed)
	     ;;The body form is a DEFINE/TYPED core macro use, one among:
	     ;;
	     ;;   (define/typed ?lhs ?rhs)
	     ;;   (define/typed (?lhs . ?formals) . ?body)
	     ;;
	     ;;it is meant to be an extension to R6RS's DEFINE syntax supporting type
	     ;;specifications.
	     (%expand-internal-definition chi-define/typed))

	    ((case-define/typed)
	     ;;The body form is a CASE-DEFINE/TYPED core macro use:
	     ;;
	     ;;   (case-define/typed ?lhs ?case-lambda-clause ...)
	     ;;
	     ;;it  is meant  to be  an extension  to the  CASE-DEFINE/STANDARD syntax
	     ;;supporting type specifications.
	     (%expand-internal-definition chi-case-define/typed))

	    ((define-syntax)
	     ;;The body  form is a  built-in DEFINE-SYNTAX  macro use.  This  is what
	     ;;happens:
	     ;;
	     ;;1. Parse the syntactic form.
	     ;;
	     ;;2. Expand the right-hand side expression.  This expansion happens in a
	     ;;lexical context in which the syntactic binding of the macro itself has
	     ;;*not* yet been established.
	     ;;
	     ;;3. Add  to the rib  the syntactic binding's association  between the
	     ;;macro keyword and the label.
	     ;;
	     ;;4.   Evaluate the  right-hand  side expression,  which  is meant  to
	     ;;return:  a  macro  transformer  function, a  compile-time  value,  a
	     ;;synonym transformer or whatever.
	     ;;
	     ;;5. Add to the lexenv the syntactic binding's association between the
	     ;;label and the binding's descriptor.
	     ;;
	     ;;6. Finally recurse to expand the rest of the body.
	     ;;
	     (receive (id rhs.stx)
		 (%parse-define-syntax body-form.stx)
	       (when (bound-id-member? id keyword*)
		 (stx-error body-form.stx "cannot redefine keyword"))
	       (let ((rhs.core (expand-macro-transformer rhs.stx lexenv.expand))
		     (lab      (generate-label-gensym id)))
		 ;;This call will raise an exception if it represents an attempt to
		 ;;illegally redefine a binding.
		 (extend-rib! rib id lab shadow/redefine-bindings?)
		 (let ((entry (cons lab (eval-macro-transformer rhs.core lexenv.run))))
		   (chi-body* (cdr body-form*.stx)
			      (cons entry lexenv.run)
			      (cons entry lexenv.expand)
			      lex* qrhs* mod** keyword* export-spec* rib
			      mix? shadow/redefine-bindings?)))))

	    ((define-fluid-syntax)
	     ;;The body  form is a  built-in DEFINE-FLUID-SYNTAX macro use.   This is
	     ;;what happens:
	     ;;
	     ;;1. Parse the syntactic form.
	     ;;
	     ;;2. Expand the right-hand side expression.  This expansion happens in a
	     ;;lexical context in which the syntactic binding of the macro itself has
	     ;;*not* yet been established.
	     ;;
	     ;;3.  Add to  the rib  the syntactic  binding's association  between the
	     ;;macro keyword and the label.
	     ;;
	     ;;4.  Evaluate the  right-hand side expression (which  usually returns a
	     ;;macro transformer function).
	     ;;
	     ;;5. Add to  the lexenv the syntactic binding's  association between the
	     ;;label and the binding's descriptor.
	     ;;
	     ;;6. Finally recurse to expand the rest of the body.
	     ;;
	     (receive (lhs.id rhs.stx)
		 (%parse-define-syntax body-form.stx)
	       (when (bound-id-member? lhs.id keyword*)
		 (stx-error body-form.stx "cannot redefine keyword"))
	       (let ((rhs.core (expand-macro-transformer rhs.stx lexenv.expand))
		     (lhs.lab  (generate-label-gensym lhs.id)))
		 ;;This call will  raise an exception if it represents  an attempt to
		 ;;illegally redefine a binding.
		 (extend-rib! rib lhs.id lhs.lab shadow/redefine-bindings?)
		 ;;The LEXENV  entry KEYWORD-ENTRY  represents the definition  of the
		 ;;fluid  syntax's  keyword  syntactic  binding.   The  LEXENV  entry
		 ;;FLUID-ENTRY represents the definition of  the current value of the
		 ;;fluid syntax,  the one  that later can  be shadowed  with internal
		 ;;definitions by FLUID-LET-SYNTAX.
		 (let* ((descriptor	(eval-macro-transformer rhs.core lexenv.run))
			(fluid-label	(generate-label-gensym lhs.id))
			(fluid-entry	(cons fluid-label descriptor))
			(keyword-entry	(cons lhs.lab (make-syntactic-binding-descriptor/local-global-macro/fluid-syntax fluid-label))))
		   (chi-body* (cdr body-form*.stx)
			      (cons* keyword-entry fluid-entry lexenv.run)
			      (cons* keyword-entry fluid-entry lexenv.expand)
			      lex* qrhs* mod** keyword* export-spec* rib
			      mix? shadow/redefine-bindings?)))))

	    ((define-alias)
	     ;;The body form  is a core language DEFINE-ALIAS macro  use.  We add a
	     ;;new  association identifier/label  to the  current rib.   Finally we
	     ;;recurse on the rest of the body.
	     ;;
	     (receive (alias-id old-id)
		 (%parse-define-alias body-form.stx)
	       (when (bound-id-member? old-id keyword*)
		 (stx-error body-form.stx "cannot redefine keyword"))
	       (cond ((id->label old-id)
		      => (lambda (label)
			   ;;This call will raise an  exception if it represents an
			   ;;attempt to illegally redefine a binding.
			   (extend-rib! rib alias-id label shadow/redefine-bindings?)
			   (chi-body* (cdr body-form*.stx)
				      lexenv.run lexenv.expand
				      lex* qrhs* mod** keyword* export-spec* rib
				      mix? shadow/redefine-bindings?)))
		     (else
		      (stx-error body-form.stx "unbound source identifier")))))

	    ((let-syntax letrec-syntax)
	     ;;The body form is a  core language LET-SYNTAX or LETREC-SYNTAX macro
	     ;;use.   We expand  and evaluate  the transformer  expressions, build
	     ;;syntactic bindings  for them,  register their labels  in a  new rib
	     ;;because they are  visible only in the internal  body.  The internal
	     ;;forms are  spliced in the external  body but with the  rib added to
	     ;;them.
	     ;;
	     (syntax-match body-form.stx ()
	       ((_ ((?xlhs* ?xrhs*) ...) ?xbody* ...)
		(unless (valid-bound-ids? ?xlhs*)
		  (stx-error body-form.stx "invalid identifiers"))
		(let* ((xlab*  (map generate-label-gensym ?xlhs*))
		       (xrib   (make-rib/from-identifiers-and-labels ?xlhs* xlab*))
		       ;;We  evaluate  the  transformers  for  LET-SYNTAX  without
		       ;;pushing the XRIB: the syntax bindings do not exist in the
		       ;;environment in which the transformer is evaluated.
		       ;;
		       ;;We  evaluate  the  transformers for  LETREC-SYNTAX  after
		       ;;pushing the  XRIB: the  syntax bindings  do exist  in the
		       ;;environment in which the transformer is evaluated.
		       (xbind* (map (lambda (x)
				      (let ((in-form (if (eq? type 'let-syntax)
							 x
						       (push-lexical-contour xrib x))))
					(eval-macro-transformer (expand-macro-transformer in-form lexenv.expand)
								lexenv.run)))
				 ?xrhs*)))
		  (chi-body*
		   ;;Splice the internal  body forms but add a  lexical contour to
		   ;;them.
		   (append (map (lambda (internal-body-form)
				  (push-lexical-contour xrib
				    internal-body-form))
			     ?xbody*)
			   (cdr body-form*.stx))
		   ;;Push on the lexical  environment entries corresponding to the
		   ;;defined syntaxes.  Such entries will stay there even after we
		   ;;have processed the internal body forms; this is not a problem
		   ;;because the labels cannot be seen by the rest of the body.
		   (append (map cons xlab* xbind*) lexenv.run)
		   (append (map cons xlab* xbind*) lexenv.expand)
		   lex* qrhs* mod** keyword* export-spec* rib
		   mix? shadow/redefine-bindings?)))))

	    ((begin-for-syntax)
	     (let ()
	       (import CHI-BEGIN-FOR-SYNTAX)
	       (chi-begin-for-syntax body-form.stx body-form*.stx lexenv.run lexenv.expand
				     lex* qrhs* mod** keyword* export-spec* rib mix? shadow/redefine-bindings?)))

	    ((begin)
	     ;;The body form  is a BEGIN syntax use.  Just  splice the expressions
	     ;;and recurse on them.
	     ;;
	     (syntax-match body-form.stx ()
	       ((_ ?expr* ...)
		(chi-body* (append ?expr* (cdr body-form*.stx))
			   lexenv.run lexenv.expand
			   lex* qrhs* mod** keyword* export-spec* rib mix? shadow/redefine-bindings?))))

	    ((stale-when)
	     ;;The  body form  is a  STALE-WHEN syntax  use.  Process  the stale-when
	     ;;guard expression, then  just splice the internal expressions  as we do
	     ;;for BEGIN and recurse.
	     ;;
	     (syntax-match body-form.stx ()
	       ((_ ?guard ?expr* ...)
		(begin
		  (handle-stale-when ?guard lexenv.expand)
		  (chi-body* (append ?expr* (cdr body-form*.stx))
			     lexenv.run lexenv.expand
			     lex* qrhs* mod** keyword* export-spec* rib mix? shadow/redefine-bindings?)))))

	    ((global-macro global-macro!)
	     ;;The body  form is  a macro  use, where  the macro  is imported  from a
	     ;;library.   We  perform  the  macro  expansion,  then  recurse  on  the
	     ;;resulting syntax object.  The syntactic binding's descriptor DESCR has
	     ;;format:
	     ;;
	     ;;   (global-macro  . (#<library> . ?loc))
	     ;;   (global-macro! . (#<library> . ?loc))
	     ;;
	     (let ((body-form.stx^ (chi-global-macro (syntactic-binding-descriptor.value descr)
						     body-form.stx lexenv.run rib)))
	       (chi-body* (cons body-form.stx^ (cdr body-form*.stx))
			  lexenv.run lexenv.expand
			  lex* qrhs* mod** keyword* export-spec* rib mix? shadow/redefine-bindings?)))

	    ((local-macro local-macro!)
	     ;;The body form is a macro use,  where the macro is locally defined.  We
	     ;;perform  the macro  expansion, then  recurse on  the resulting  syntax
	     ;;object.  The syntactic binding's descriptor DESCR has format:
	     ;;
	     ;;   (local-macro  . (?transformer . ?expanded-expr))
	     ;;   (local-macro! . (?transformer . ?expanded-expr))
	     ;;
	     (let ((body-form.stx^ (chi-local-macro (syntactic-binding-descriptor.value descr)
						    body-form.stx lexenv.run rib)))
	       (chi-body* (cons body-form.stx^ (cdr body-form*.stx))
			  lexenv.run lexenv.expand
			  lex* qrhs* mod** keyword* export-spec* rib mix? shadow/redefine-bindings?)))

	    ((macro macro!)
	     ;;The body  form is  a macro use,  where the macro  is a  non-core macro
	     ;;integrated  in the  expander.  We  perform the  macro expansion,  then
	     ;;recurse  on  the resulting  syntax  object.   The syntactic  binding's
	     ;;descriptor DESCR has format:
	     ;;
	     ;;   (macro  . ?macro-name)
	     ;;   (macro! . ?macro-name)
	     ;;
	     (let ((body-form.stx^ (chi-non-core-macro (syntactic-binding-descriptor.value descr)
						       body-form.stx lexenv.run rib)))
	       (chi-body* (cons body-form.stx^ (cdr body-form*.stx))
			  lexenv.run lexenv.expand
			  lex* qrhs* mod** keyword* export-spec* rib mix? shadow/redefine-bindings?)))

	    ((module)
	     ;;The body  form is  an internal module  definition.  We  process the
	     ;;module, then recurse on the rest of the body.
	     ;;
	     (receive (lex* qrhs* m-exp-id* m-exp-lab* lexenv.run lexenv.expand mod** keyword*)
		 (chi-internal-module body-form.stx lexenv.run lexenv.expand lex* qrhs* mod** keyword*)
	       ;;Extend the rib with the syntactic bindings exported by the module.
	       (vector-for-each (lambda (id lab)
				  ;;This  call  will  raise   an  exception  if  it
				  ;;represents an  attempt to illegally  redefine a
				  ;;binding.
				  (extend-rib! rib id lab shadow/redefine-bindings?))
		 m-exp-id* m-exp-lab*)
	       (chi-body* (cdr body-form*.stx) lexenv.run lexenv.expand
			  lex* qrhs* mod** keyword* export-spec*
			  rib mix? shadow/redefine-bindings?)))

	    ((library)
	     ;;The body  form is  a library definition.   We process  the library,
	     ;;then recurse on the rest of the body.
	     ;;
	     (expand-library (syntax->datum body-form.stx))
	     (chi-body* (cdr body-form*.stx)
			lexenv.run lexenv.expand
			lex* qrhs* mod** keyword* export-spec*
			rib mix? shadow/redefine-bindings?))

	    ((export)
	     ;;The body  form is an  EXPORT form.   We just accumulate  the export
	     ;;specifications, to be  processed later, and we recurse  on the rest
	     ;;of the body.
	     ;;
	     (syntax-match body-form.stx ()
	       ((_ ?export-spec* ...)
		(chi-body* (cdr body-form*.stx)
			   lexenv.run lexenv.expand
			   lex* qrhs* mod** keyword*
			   (append ?export-spec* export-spec*)
			   rib mix? shadow/redefine-bindings?))))

	    ((import)
	     ;;The body  form is an  IMPORT form.  We  just process the  form which
	     ;;results  in   extending  the   RIB  with   more  identifier-to-label
	     ;;associations.  Finally we recurse on the rest of the body.
	     ;;
	     (%chi-import body-form.stx lexenv.run rib shadow/redefine-bindings?)
	     (chi-body* (cdr body-form*.stx) lexenv.run lexenv.expand
			lex* qrhs* mod** keyword* export-spec* rib mix? shadow/redefine-bindings?))

	    ((standalone-unbound-identifier)
	     (raise-unbound-error __who__ body-form.stx body-form.stx))

	    ((displaced-lexical)
	     (syntax-violation __who__ "identifier out of context" body-form.stx
			       (syntax-match body-form.stx ()
				 ((?car . ?cdr)
				  ?car)
				 (?id
				  (identifier? ?id)
				  ?id)
				 (_ #f))))

	    (else
	     ;;Any other expression.
	     ;;
	     ;;If  mixed definitions  and  expressions are  allowed,  we handle  this
	     ;;expression as an implicit definition:
	     ;;
	     ;;   (define/standard dummy ?body-form)
	     ;;
	     ;;which is not really part of  the lexical environment: we only generate
	     ;;a lex and a qrhs for it, without adding entries to LEXENV.RUN; then we
	     ;;move on to the next body form.
	     ;;
	     ;;If mixed  definitions and expressions  are forbidden: we  have reached
	     ;;the end  of definitions  and expect  this and all  the other  forms in
	     ;;BODY-FORM*.STX  to  be  expressions.  So  BODY-FORM*.STX  becomes  the
	     ;;"trailing expressions" return value.
	     ;;
	     (if mix?
		 ;;There must be a LEX for every QRHS, really.
		 (let* ((lex  (generate-lexical-gensym 'dummy))
			(qrhs (make-qualified-rhs/top-expr body-form.stx (make-syntactic-identifier-for-temporary-variable lex))))
		   (chi-body* (cdr body-form*.stx)
			      lexenv.run lexenv.expand
			      (cons lex  lex*)
			      (cons qrhs qrhs*)
			      mod** keyword* export-spec* rib mix? shadow/redefine-bindings?))
	       (values body-form*.stx lexenv.run lexenv.expand lex* qrhs* mod** keyword* export-spec*))))))
    (values body-form*.stx lexenv.run lexenv.expand lex* qrhs* mod** kwd* export-spec*)))


(define (%parse-define-syntax stx)
  ;;Syntax parser  for R6RS's DEFINE-SYNTAX,  extended with Vicare's  syntax.  Accept
  ;;both:
  ;;
  ;;  (define-syntax ?name ?transformer-expr)
  ;;  (define-syntax (?name ?arg) ?body0 ?body ...)
  ;;
  (syntax-match stx ()
    ((_ (?id ?arg) ?body0 ?body* ...)
     (and (identifier? ?id)
	  (identifier? ?arg))
     (values ?id (bless `(lambda (,?arg) ,?body0 ,@?body*))))
    ((_ ?id)
     (identifier? ?id)
     (values ?id (bless '(syntax-rules ()))))
    ((_ ?id ?transformer-expr)
     (identifier? ?id)
     (values ?id ?transformer-expr))
    ))


(define (%parse-define-alias body-form.stx)
  ;;Syntax parser for Vicares's DEFINE-ALIAS.
  ;;
  (syntax-match body-form.stx ()
    ((_ ?alias-id ?old-id)
     (and (identifier? ?alias-id)
	  (identifier? ?old-id))
     (values ?alias-id ?old-id))
    ))


(module (%chi-import)
  ;;Process  an  IMPORT  form.  The  purpose  of  such  forms  is to  push  some  new
  ;;identifier-to-label association on the current RIB.
  ;;
  (define-module-who import)

  (define (%chi-import body-form.stx lexenv.run rib shadow/redefine-bindings?)
    (receive (id.vec lab.vec)
	(%any-import*-checked body-form.stx lexenv.run)
      (vector-for-each (lambda (id lab)
			 ;;This  call will  raise an  exception if  it represents  an
			 ;;attempt to illegally redefine a binding.
			 (extend-rib! rib id lab shadow/redefine-bindings?))
	id.vec lab.vec)))

  (define (%any-import*-checked import-form lexenv.run)
    (syntax-match import-form ()
      ((?ctxt ?import-spec* ...)
       (%any-import* ?ctxt ?import-spec* lexenv.run))
      (_
       (stx-error import-form "invalid import form"))))

  (define (%any-import* ctxt import-spec* lexenv.run)
    (if (null? import-spec*)
	(values '#() '#())
      (let-values
	  (((t1 t2) (%any-import  ctxt (car import-spec*) lexenv.run))
	   ((t3 t4) (%any-import* ctxt (cdr import-spec*) lexenv.run)))
	(values (vector-append t1 t3)
		(vector-append t2 t4)))))

  (define (%any-import ctxt import-spec lexenv.run)
    (if (identifier? import-spec)
	(%module-import (list ctxt import-spec) lexenv.run)
      (%library-import (list ctxt import-spec))))

  (define (%module-import import-form lexenv.run)
    (syntax-match import-form ()
      ((_ ?id)
       (identifier? ?id)
       (receive (type descr kwd)
	   (syntactic-form-type __module_who__ ?id lexenv.run)
	 (case type
	   (($module)
	    (let ((iface (syntactic-binding-descriptor.value descr)))
	      (values (module-interface-exp-id*     iface ?id)
		      (module-interface-exp-lab-vec iface))))
	   ((standalone-unbound-identifier)
	    (raise-unbound-error __module_who__ import-form ?id))
	   (else
	    (stx-error import-form "invalid import")))))))

  (define (%library-import import-form)
    (syntax-match import-form ()
      ((?ctxt ?imp* ...)
       ;;NAME-VEC is  a vector of  symbols representing  the external names  of the
       ;;imported  bindings.   LABEL-VEC is  a  vector  of label  gensyms  uniquely
       ;;associated to the imported bindings.
       (receive (name-vec label-vec)
	   (parse-import-spec* (syntax->datum ?imp*))
	 (values (vector-map (lambda (name)
			       (~datum->syntax ?ctxt name))
		   name-vec)
		 label-vec)))
      (_
       (stx-error import-form "invalid import form"))))

  #| end of module: %CHI-IMPORT |# )


;;;; parsing DEFINE forms

(module CHI-DEFINE
  (chi-define/standard
   chi-define/typed
   chi-case-define/standard
   chi-case-define/typed)
  ;;The facilities of this module are used when the BODY-FORM.STX parsed by CHI-BODY*
  ;;is a  syntax object  representing the  macro use of  a DEFINE  variant; something
  ;;like:
  ;;
  ;;   (define ?lhs)
  ;;   (define ?lhs ?rhs)
  ;;   (define (?lhs . ?formals) . ?body)
  ;;
  ;;The functions  parse the body form  and build a qualified  right-hand side (QRHS)
  ;;object that will be expanded later.
  ;;
  ;;Here we  establish a new syntactic  binding representing lexical variable  in the
  ;;lexical context represented by the arguments RIB and LEXENV.RUN:
  ;;
  ;;* We generate a  label gensym uniquely associated to the  syntactic binding and a
  ;;lex gensym as name of the syntactic binding in the expanded code.
  ;;
  ;;* We register the association identifier/label in the rib.
  ;;
  ;;* We push an entry on LEXENV.RUN to represent the association label/lex.
  ;;
  ;;Finally we return the lex, the QRHS  and the updated LEXENV.RUN to recurse on the
  ;;rest of the body.
  ;;
  ;;
  ;;About the lex gensym
  ;;--------------------
  ;;
  ;;Notice that:
  ;;
  ;;* If the syntactic  binding is at the top-level of a program  or library body: we
  ;;need a  loc gensym to store  the result of evaluating  the RHS in QRHS;  this loc
  ;;will be generated later.
  ;;
  ;;* If the  syntactic binding is at  the top-level of an expression  expanded in an
  ;;interaction environment: we  need a loc gensym to store  the result of evaluating
  ;;the RHS  in QRHS; in  this case the  lex gensym generated  here also acts  as loc
  ;;gensym.
  ;;
  ;;
  ;;About redefining an existing syntactic binding
  ;;----------------------------------------------
  ;;
  ;;Special case:  if this  definition is  at the top-level  and a  syntactic binding
  ;;capturing the  syntactic identifier  ?LHS already  exists in the  top rib  of the
  ;;interaction environment: we  allow the binding to be redefined;  this is a Vicare
  ;;extension.   Normally,  in  a  non-interaction environment,  we  would  raise  an
  ;;exception as mandated by R6RS.
  ;;


;;;; core macros: DEFINE/STANDARD

(module (chi-define/standard)
  ;;The  BODY-FORM.STX  parsed  by  CHI-BODY*  is  a  syntax  object  representing  a
  ;;DEFINE/STANDARD core macro use; for example, one among:
  ;;
  ;;   (define/standard ?lhs)
  ;;   (define/standard ?lhs ?rhs)
  ;;   (define/standard (?lhs . ?formals) . ?body)
  ;;
  ;;we parse  the form and  generate a qualified  right-hand side (QRHS)  object that
  ;;will be expanded later.  Here we establish a new syntactic binding representing a
  ;;fully R6RS compliant  lexical variable in the lexical context  represented by the
  ;;arguments RIB and LEXENV.RUN.
  ;;
  (define-module-who define/standard)

  (define (chi-define/standard input-form.stx rib lexenv.run kwd* shadow/redefine-bindings?)
    (case-define %synner
      ((message)
       (syntax-violation __module_who__ message input-form.stx))
      ((message subform)
       (syntax-violation __module_who__ message input-form.stx subform)))
    (receive (lhs.id lhs.type qrhs lexenv.run)
	;;From parsing the  syntactic form, we receive the  following values: LHS.ID,
	;;the  lexical   variable's  syntactic  binding's  identifier;   LHS.TYPE,  a
	;;syntactic  identifier representing  the  type of  this  binding; QRHS,  the
	;;qualified RHS object to be expanded later.
	(%parse-macro-use input-form.stx rib lexenv.run shadow/redefine-bindings? %synner)
      (if (bound-id-member? lhs.id kwd*)
	  (%synner "cannot redefine keyword")
	(let* ((lhs.lab		(generate-label-gensym   lhs.id))
	       (lhs.lex		(generate-lexical-gensym lhs.id))
	       (descr		(make-syntactic-binding-descriptor/lexical-typed-var/from-data lhs.type lhs.lex))
	       ;;An untyped syntactic binding's descriptor is created as follows.
	       #;(descr		(make-syntactic-binding-descriptor/lexical-var lhs.lex))
	       (lexenv.run	(push-entry-on-lexenv lhs.lab descr lexenv.run)))
	  ;;This rib extension will raise an exception if it represents an attempt to
	  ;;illegally redefine a binding.
	  (extend-rib! rib lhs.id lhs.lab shadow/redefine-bindings?)
	  (values lhs.lex qrhs lexenv.run)))))

  (module (%parse-macro-use)

    (define* (%parse-macro-use input-form.stx rib lexenv.run shadow/redefine-bindings? synner)
      ;;Syntax  parser for  Vicare's DEFINE/STANDARD  syntax uses;  this is  like the
      ;;standard DEFINE described by R6RS.  Return the following values:
      ;;
      ;;1. The syntactic identifier of the lexical syntactic binding.
      ;;
      ;;2.  A syntactic  identifier representing the lexical variable's  type.  It is
      ;;false when no  type is specified.  It  is a sub-type of  "<procedure>" when a
      ;;procedure is defined.
      ;;
      ;;3.   An object  representing a  qualified right-hand  side expression  (QRHS)
      ;;fully representing the syntactic binding to create.
      ;;
      ;;4. A possibly updated LEXENV.RUN.
      ;;
      (syntax-match input-form.stx ()
	((_ (?lhs . ?formals) ?body0 ?body* ...)
	 (%process-standard-function-definition input-form.stx rib lexenv.run shadow/redefine-bindings?
						?lhs ?formals `(,?body0 . ,?body*) synner))

	((_ ?lhs ?rhs)
	 (%process-standard-variable-definition-with-init-expr	input-form.stx lexenv.run ?lhs ?rhs synner))

	((_ ?lhs)
	 (%process-standard-variable-definition-with-init-expr	input-form.stx lexenv.run ?lhs (bless '(void)) synner))

	(_
	 (synner "invalid syntax"))))

    (define (%process-standard-function-definition input-form.stx rib lexenv.run shadow/redefine-bindings?
						   lhs.id input-formals.stx body*.stx synner)
      (unless (identifier? lhs.id)
	(synner "expected identifier as function name" lhs.id))
      ;;From parsing the standard formals we get  2 values: a proper or improper list
      ;;of   identifiers  representing   the   standard  formals;   an  instance   of
      ;;"<clambda-clause-signature>".   An exception  is  raised if  an error  occurs
      ;;while parsing.
      (receive (standard-formals.stx clause-signature)
	  (syntax-object.parse-standard-clambda-clause-formals input-formals.stx input-form.stx)
	;;This is a standard variable syntactic  binding, so the arguments and return
	;;values are untyped.   However, we still want to generate  a typed syntactic
	;;binding so that  we can validate the number of  operands and return values.
	;;So we fabricate a type identifier and put it on the lexenv to represent the
	;;type of this function.
	(let* ((lhs.type	(datum->syntax lhs.id (make-fabricated-closure-type-name (identifier->symbol lhs.id))))
	       (signature	(make-clambda-signature (list clause-signature)))
	       (lexenv.run	(make-syntactic-binding/closure-type-name lhs.type signature rib lexenv.run shadow/redefine-bindings?))
	       (qrhs		(make-qualified-rhs/standard-defun input-form.stx lhs.id standard-formals.stx body*.stx
								   lhs.type signature)))
	  (values lhs.id lhs.type qrhs lexenv.run))))

    (define (%process-standard-variable-definition-with-init-expr input-form.stx lexenv.run lhs.id rhs.stx synner)
      (unless (identifier? lhs.id)
	(synner "expected identifier as variable name" lhs.id))
      (let ((qrhs (make-qualified-rhs/standard-defvar input-form.stx lhs.id rhs.stx)))
	(values lhs.id (untyped-tag-id) qrhs lexenv.run)))

    #| end of module: %PARSE-MACRO-USE |# )

  #| end of module: CHI-DEFINE/STANDARD |# )


;;;; core macros: CASE-DEFINE/STANDARD

(define* (chi-case-define/standard input-form.stx rib lexenv.run kwd* shadow/redefine-bindings?)
  (define-constant __who__ 'case-define/standard)
  (syntax-match input-form.stx ()
    ((_ ?who ?cl-clause ?cl-clause* ...)
     ;;FIXME Temporary implementation.  (Marco Maggi; Tue Feb 2, 2016)
     (chi-define/standard (bless
			   `(define/standard ,?who
			      (case-lambda/standard ,?cl-clause . ,?cl-clause*)))
			  rib lexenv.run kwd* shadow/redefine-bindings?))
    ))


;;;; core macros: DEFINE/TYPED

(module (chi-define/typed)
  ;;The  BODY-FORM.STX  parsed  by  CHI-BODY*  is  a  syntax  object  representing  a
  ;;DEFINE/TYPED core macro use; for example, one among:
  ;;
  ;;   (define/typed ?lhs)
  ;;   (define/typed ?lhs ?rhs)
  ;;   (define/typed (?lhs . ?formals) . ?body)
  ;;   (define/typed (brace ?lhs ?lhs.type)
  ;;   (define/typed (brace ?lhs ?lhs.type) ?rhs)
  ;;   (define/typed ((brace ?lhs ?lhs.type) . ?formals) . ?body)
  ;;
  ;;we parse  the form and  generate a qualified  right-hand side (QRHS)  object that
  ;;will be expanded later.  Here we establish a new syntactic binding representing a
  ;;typed lexical  variable in the lexical  context represented by the  arguments RIB
  ;;and LEXENV.RUN.
  ;;
  (define-module-who define/typed)

  (define (chi-define/typed input-form.stx rib lexenv.run kwd* shadow/redefine-bindings?)
    (case-define %synner
      ((message)
       (syntax-violation __module_who__ message input-form.stx))
      ((message subform)
       (syntax-violation __module_who__ message input-form.stx subform)))
    (receive (lhs.id lhs.type qrhs lexenv.run)
	;;From parsing the  syntactic form, we receive the  following values: LHS.ID,
	;;the  lexical   variable's  syntactic  binding's  identifier;   LHS.TYPE,  a
	;;syntactic  identifier representing  the  type of  this  binding; QRHS,  the
	;;qualified RHS object to be expanded later.
	(%parse-macro-use input-form.stx rib lexenv.run shadow/redefine-bindings? %synner)
      (if (bound-id-member? lhs.id kwd*)
	  (%synner "cannot redefine keyword")
	(let* ((lhs.lab		(generate-label-gensym   lhs.id))
	       (lhs.lex		(generate-lexical-gensym lhs.id))
	       (descr		(make-syntactic-binding-descriptor/lexical-typed-var/from-data lhs.type lhs.lex))
	       (lexenv.run	(push-entry-on-lexenv lhs.lab descr lexenv.run)))
	  ;;This rib extension will raise an exception if it represents an attempt to
	  ;;illegally redefine a binding.
	  (extend-rib! rib lhs.id lhs.lab shadow/redefine-bindings?)
	  (values lhs.lex qrhs lexenv.run)))))

  (module (%parse-macro-use)

    (define* (%parse-macro-use input-form.stx rib lexenv.run shadow/redefine-bindings? synner)
      ;;Syntax  parser for  Vicare's DEFINE/TYPED  syntax uses;  this is  a like  the
      ;;standard DEFINE described  by R6RS but extended to  support type annotations.
      ;;Return the following values:
      ;;
      ;;1. The syntactic identifier of the lexical syntactic binding.
      ;;
      ;;2.  A syntactic  identifier representing the lexical variable's  type.  It is
      ;;false when no  type is specified.  It  is a sub-type of  "<procedure>" when a
      ;;procedure is defined.
      ;;
      ;;3.   An object  representing a  qualified right-hand  side expression  (QRHS)
      ;;fully representing the syntactic binding to create.
      ;;
      ;;4. A possibly updated LEXENV.RUN.
      ;;
      (syntax-match input-form.stx (brace)
	((_ ((brace ?lhs ?rv-type* ... . ?rv-rest-type) . ?formals) ?body0 ?body* ...)
	 (%process-typed-function-definition input-form.stx rib lexenv.run shadow/redefine-bindings?
					     ?lhs (bless `((brace _ ,@?rv-type* . ,?rv-rest-type) . ,?formals))
					     `(,?body0 . ,?body*) synner))

	((_ (brace ?lhs ?type) ?rhs)
	 (%process-typed-variable-definition-with-init-expr	input-form.stx lexenv.run ?lhs ?rhs ?type synner))

	((_ (brace ?lhs ?type))
	 (%process-typed-variable-definition-with-init-expr	input-form.stx lexenv.run ?lhs (bless '(void)) ?type synner))

	((_ (?lhs . ?formals) ?body0 ?body* ...)
	 (%process-typed-function-definition input-form.stx rib lexenv.run shadow/redefine-bindings?
					     ?lhs ?formals `(,?body0 . ,?body*) synner))

	((_ ?lhs ?rhs)
	 (%process-standard-variable-definition-with-init-expr	input-form.stx lexenv.run ?lhs ?rhs synner))

	((_ ?lhs)
	 (%process-standard-variable-definition-with-init-expr	input-form.stx lexenv.run ?lhs (bless '(void)) synner))

	(_
	 (synner "invalid DEFINE/TYPED syntax use"))))

    (define (%process-typed-function-definition input-form.stx rib lexenv.run shadow/redefine-bindings?
						lhs.id input-formals.stx body*.stx synner)
      (unless (identifier? lhs.id)
	(synner "expected identifier as variable name" lhs.id))
      ;;From parsing the typed formals we get  2 values: a proper or improper list of
      ;;identifiers   representing    the   standard   formals;   an    instance   of
      ;;"<clambda-clause-signature>".   An exception  is  raised if  an error  occurs
      ;;while parsing.
      (receive (standard-formals.stx clause-signature)
	  (syntax-object.parse-typed-clambda-clause-formals input-formals.stx input-form.stx)
	(let* ((lhs.type	(datum->syntax lhs.id (make-fabricated-closure-type-name (identifier->symbol lhs.id))))
	       (signature	(make-clambda-signature (list clause-signature)))
	       (lexenv.run	(make-syntactic-binding/closure-type-name lhs.type signature rib lexenv.run shadow/redefine-bindings?))
	       (qrhs		(make-qualified-rhs/typed-defun input-form.stx lhs.id standard-formals.stx body*.stx
								lhs.type signature)))
	  (values lhs.id lhs.type qrhs lexenv.run))))

    (define (%process-typed-variable-definition-with-init-expr input-form.stx lexenv.run
							       lhs.id rhs.stx lhs.type synner)
      (unless (identifier? lhs.id)
	(synner "expected identifier as variable name" lhs.id))
      (unless (type-identifier? lhs.type)
	(synner "expected type identifier as type annotation for variable name" lhs.type))
      (let ((qrhs (make-qualified-rhs/typed-defvar input-form.stx lhs.id rhs.stx lhs.type)))
	(values lhs.id lhs.type qrhs lexenv.run)))

    (define (%process-standard-variable-definition-with-init-expr input-form.stx lexenv.run
								  lhs.id rhs.stx synner)
      (unless (identifier? lhs.id)
	(synner "expected identifier as variable name" lhs.id))
      (let ((qrhs (make-qualified-rhs/standard-defvar input-form.stx lhs.id rhs.stx)))
	(values lhs.id (untyped-tag-id) qrhs lexenv.run)))

    #| end of module: %PARSE-MACRO-USE |# )

  #| end of module: CHI-DEFINE/TYPED |# )


;;;; core macros: CASE-DEFINE/TYPED

(define* (chi-case-define/typed input-form.stx rib lexenv.run kwd* shadow/redefine-bindings?)
  (define-constant __who__ 'case-define/typed)
  (syntax-match input-form.stx ()
    ((_ ?who ?cl-clause ?cl-clause* ...)
     ;;FIXME Temporary implementation.  (Marco Maggi; Tue Feb 2, 2016)
     (chi-define/typed (bless
			`(define/typed ,?who
			   (case-lambda/typed ,?cl-clause . ,?cl-clause*)))
		       rib lexenv.run kwd* shadow/redefine-bindings?))
    ))


;;;; parsing DEFINE forms: end of module

#| end of module: CHI-DEFINE |# )


;;;; done

#| end of module: CHI-BODY* |# )

;;; end of file
;;Local Variables:
;;mode: vicare
;;fill-column: 85
;;eval: (put 'assertion-violation/internal-error	'scheme-indent-function 1)
;;eval: (put 'with-who					'scheme-indent-function 1)
;;End:
