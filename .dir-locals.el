;;; Directory Local Variables
;;; See Info node `(emacs) Directory Variables' for more information.

((vicare-mode
  . ((indent-tabs-mode . t)
     (show-trailing-whitespace . t)
     (fill-column . 85)
     ;;Mostly psyntax indentation configuration.
     (eval . (put '$fold-left/stx							'scheme-indent-function 1))
     (eval . (put '$map-in-order							'scheme-indent-function 1))
     (eval . (put '%drop-splice-first-envelope-maybe					'scheme-indent-function 0))
     (eval . (put '%error-mismatch-between-argvals-signature-and-operands-signature	'scheme-indent-function 1))
     (eval . (put '%error-number-of-operands-deceeds-minimum-arguments-count		'scheme-indent-function 1))
     (eval . (put '%error-number-of-operands-exceeds-maximum-arguments-count		'scheme-indent-function 1))
     (eval . (put '%maybe-push-annotated-expr-on-case-lambda-input-form			'scheme-indent-function 1))
     (eval . (put '%maybe-push-annotated-expr-on-lambda-input-form			'scheme-indent-function 1))
     (eval . (put '%warning-mismatch-between-argvals-signature-and-operands-signature	'scheme-indent-function 1))
     (eval . (put 'assertion-violation/internal-error					'scheme-indent-function 1))
     (eval . (put 'build-application							'scheme-indent-function 2))
     (eval . (put 'build-case-lambda							'scheme-indent-function 2))
     (eval . (put 'build-conditional							'scheme-indent-function 2))
     (eval . (put 'build-data								'scheme-indent-function 1))
     (eval . (put 'build-foreign-call							'scheme-indent-function 2))
     (eval . (put 'build-global-assignment						'scheme-indent-function 1))
     (eval . (put 'build-lambda								'scheme-indent-function 2))
     (eval . (put 'build-let								'scheme-indent-function 3))
     (eval . (put 'build-letrec*							'scheme-indent-function 3))
     (eval . (put 'build-lexical-assignment						'scheme-indent-function 2))
     (eval . (put 'build-library-letrec*						'scheme-indent-function 1))
     (eval . (put 'build-sequence							'scheme-indent-function 1))
     (eval . (put 'build-with-compilation-options					'scheme-indent-function 1))
     (eval . (put 'case-expander-language						'scheme-indent-function 0))
     (eval . (put 'case-identifier-syntactic-binding-descriptor				'scheme-indent-function 1))
     (eval . (put 'case-identifier-syntactic-binding-descriptor/no-indirection		'scheme-indent-function 1))
     (eval . (put 'case-object-type-binding						'scheme-indent-function 1))
     (eval . (put 'case-signature-specs							'scheme-indent-function 1))
     (eval . (put 'core-lang-builder							'scheme-indent-function 1))
     (eval . (put 'declare-core-primitive						'scheme-indent-function 2))
     (eval . (put 'define-built-in-condition-type					'scheme-indent-function 2))
     (eval . (put 'define-built-in-record-type					 	'scheme-indent-function 2))
     (eval . (put 'define-macro-transformer						'scheme-indent-function 1))
     (eval . (put 'define-scheme-type							'scheme-indent-function 2))
     (eval . (put 'expand-time-retvals-signature-violation				'scheme-indent-function 1))
     (eval . (put 'if-wants-case-lambda							'scheme-indent-function 1))
     (eval . (put 'if-wants-global-defines						'scheme-indent-function 1))
     (eval . (put 'if-wants-letrec*							'scheme-indent-function 1))
     (eval . (put 'if-wants-library-letrec*						'scheme-indent-function 1))
     (eval . (put 'let-syntax-rules							'scheme-indent-function 1))
     (eval . (put 'make-psi								'scheme-indent-function 1))
     (eval . (put 'map-for-two-retvals							'scheme-indent-function 1))
     (eval . (put 'push-lexical-contour							'scheme-indent-function 1))
     (eval . (put 'raise-compound-condition-object					'scheme-indent-function 1))
     (eval . (put 'raise-compound-condition-object/continuable				'scheme-indent-function 1))
     (eval . (put 'syntactic-binding-getprop						'scheme-indent-function 1))
     (eval . (put 'sys::syntax-case							'scheme-indent-function 2))
     (eval . (put 'sys::with-syntax							'scheme-indent-function 1))
     (eval . (put 'with-object-type-syntactic-binding					'scheme-indent-function 1))
     (eval . (put 'with-pending-library-request						'scheme-indent-function 1))
     (eval . (put 'with-who								'scheme-indent-function 1))
     ))
 )

;;; end of file
