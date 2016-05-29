;;; CAVIART-VCGEN - A verification condition generator for the CAVI-ART project
;;; developed originally at GPD UCM.
;;; Copyright (C) 2016 Santiago Saavedra López, Grupo de Programación Declarativa -
;;; Universidad Complutense de Madrid
;;;
;;; This file is part of CAVIART-VCGEN.
;;;
;;; CAVIART-VCGEN is free software: you can redistribute it and/or modify
;;; it under the terms of the GNU Affero General Public License as
;;; published by the Free Software Foundation, either version 3 of the
;;; License, or (at your option) any later version.
;;;
;;; CAVIART-VCGEN is distributed in the hope that it will be useful,
;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU Affero General Public License for more details.
;;;
;;; You should have received a copy of the GNU Affero General Public License
;;; along with CAVIART-VCGEN.  If not, see <http://www.gnu.org/licenses/>.

;;; This package does not need to be in packages.lisp: it is only used
;;; here, and it should not leak symbols. Thus, if encapsulation is
;;; not broken, this package does not need to be accessed from the
;;; outside.
(defpackage :ir.vc.core.impl
  (:documentation "Internal package to avoid leaking symbols. This
  contains the functionality for generating Verification Conditions
  for later use in a proof assistant.")
  (:use :cl :ir.utils)
  (:import-from :ir.vc.core :assertion :precd :postcd :default :*external-functions* :true :false)
  (:export :verifier-output :verifier-output-comment
	   :remove-decls))

(in-package :ir.vc.core.impl)

;;; TODO: Handle lettype and the like.

(defun get-precondition (function-definition)
  (let* ((body (function-body function-definition))
	 (declarations (cdr (assoc 'declare body)))
	 (assertions (cdr (assoc 'assertion declarations)))
	 (precd (assoc 'precd assertions)))
    (when precd
      (cadr precd))))

(defun get-postcondition (function-definition)
  (let* ((body (function-body function-definition))
	 (declarations (cdr (assoc 'declare body)))
	 (assertions (cdr (assoc 'assertion declarations)))
	 (postcd (assoc 'postcd assertions)))
    (when postcd
      (cadr postcd))))

(defvar *external-functions* nil)


;;;; Grammar follows 
(defmacro ir.vc.core:verification-unit (package-id &key sources uses documentation verify-only assume-verified)
  (declare (ignorable sources))
  (let ((pkg (get-package-symbol package-id)))
      `(progn (when (find-package ,pkg)
		(unuse-package ',@uses ,pkg)
		(delete-package ,pkg))
	      (defpackage ,pkg
		 (:use ,@uses)
		 (:documentation ,documentation))
	    (in-package ,pkg)
	    (cl:mapcar (cl:lambda (f) (cl:push f ir.vc.core:*assume-verified*)) ,assume-verified)
	    (cl:mapcar (cl:lambda (f) (cl:push f ir.vc.core:*verify-only*)) ,verify-only)
	    ;; (verifier-output-comment "Parsing units in package ~a~%" ,package-id)
	    )))

(defmacro ir.vc.core:predicate (name typed-lambda-list &body expressions)
  (assert (not (cdr expressions)))
  (let ((expression (first expressions)))
    (let ((symbol (intern (symbol-name '#:*predicates*)
			   *package*)))
      `(push (list ',name ',typed-lambda-list ',expression)
	     ,symbol))))

(defmacro ir.vc.core:lettype (type-symbol param-list type-boolean-expression optional-data)
  (declare (ignorable type-boolean-expression))
  (error "This item of the grammar is not yet implemented. Please,
  define your custom types in a compaion why3 file for the moment.")
  `(prog1
       (verifier-output 'type ,type-symbol ,param-list)
     (verifier-output-comment-to-string ,optional-data)))


(defvar *premise-list* nil)
(defvar *goal-set* nil)
(defvar *variable-list* nil)
(defvar *function-list* nil)
(defvar *current-function* nil)

(defun remove-decls (body &optional declarations)
  "Gets the `declare'-d and docstring forms (if there are any) of a
defun-ish body and the resulting body as values."
  (declare (type list body declarations))
  (let ((form (car body)))
    (typecase form
      ((or symbol nil) (values body (reverse declarations)))
      (cons (if (eq (car form) 'declare)
		(remove-decls (cdr body) (append (cdr form) declarations))
		(values body (reverse declarations)))))))

;; TODO at some point, replace function "list" with a proper struct
(defun function-body (function-definition)
  (cdddr function-definition))

(defun typed-lambda-list (function-definition)
  "Gets the lambda list of a function definition. E.g., simple
   accessor"
  (second function-definition))

(defun typed-result-list (function-definition)
  "Gets the result list of a function definition. E.g., simple
   accessor"
  (third function-definition))

(defun get-current-typed-result-list ()
  (typed-result-list (assoc *current-function* *function-list*)))


(defmacro with-empty-premise-list (&body body)
  `(let ((*premise-list* nil))
     ,@body))

(defmacro with-premise ((content &key name) &body body)
  (if (or name (macroexpand-1 content))
      `(let ((*premise-list* (cons (list ,name ,content) *premise-list*)))
	 ,@body)
      `(progn ,@body)))

(defmacro terminal-expression (expression &key type norename)
  "We have to do postcd/{result=expression}"
  (declare (ignore type))
  (if norename
      `(output-goal (@postcd *current-function*) :name "postcondition")
      `(output-goal (rename-symbols (@postcd *current-function*)
				    (drop-types (get-current-typed-result-list))
				    ',expression)
		     :name "postcondition")))


(defmacro with-variables (typed-variable-list &body body)
  "Introduces variables in the `premise-list' and `symbol-macrolet's
  those variables so that when they are `macroexpand-1'-ed they will
  be known as variables and the postcondition will be well formed."
  (if typed-variable-list
      (labels ((symbol-macroletize (typed-var)
		 (destructuring-bind (var-name var-type) typed-var
		   `(,var-name (terminal-expression (,var-name) :type ,var-type)))))
	`(with-premise ((list :forall ',typed-variable-list))
	   (symbol-macrolet ,(mapcar #'symbol-macroletize typed-variable-list)
	     ,@body)))
      `(progn ,@body)))

(defmacro with-function-definitions (new-definitions &body body)
  `(let ((*function-list* (append ,new-definitions *function-list*)))
     ,@body))

(defmacro with-function-definition (new-definition &body body)
  `(let ((*function-list* (cons ,new-definition *function-list*)))
     ,@body))

(defmacro with-current-function (function-name &body body)
  `(let ((*current-function* ,function-name))
     ,@body))


(defun @precd (function-name &optional function-args)
  (let* ((f (assoc function-name (append *function-list* *external-functions*)))
	 (precd (get-precondition f))
	 (parameter-list (drop-types (typed-lambda-list f))))
    (if precd
	;; Rename parameters
	(rename-symbols precd parameter-list function-args)
	;; Else
	(progn
	  (format t "Precondition for ~A not found." function-name)
	  (list :precd_placeholder
		function-name
		(list parameter-list function-args)))
	)))

(defun @postcd (function-name &optional function-args result-args)
  (let* ((f (assoc function-name (append *function-list* *external-functions*)))
	 (postcd (get-postcondition f))
	 (parameter-list (drop-types (typed-lambda-list f)))
	 (result-list (drop-types (typed-result-list f))))
    (if postcd
	;; Rename lambda parameters and result parameters
	(rename-symbols
	 (rename-symbols postcd parameter-list function-args)
	 result-list result-args)
	;; Else
	(list :postcd_placeholder function-name
	      (list parameter-list function-args)
	      (list result-list result-args))
	)))

(defun rename-symbols (formula original-symbols new-symbols)
  (if (eq nil new-symbols)
      formula
      ;; Simple s-exp tree walker
      (typecase formula
	(nil nil)
	(symbol (let ((p (position formula original-symbols)))
		  (if p
		      (nth p new-symbols)
		      formula)))
	(cons (cons (rename-symbols (car formula) original-symbols new-symbols)
		    (rename-symbols (cdr formula) original-symbols new-symbols)))
	(t formula))))

(defparameter ir.vc.core:*goal-set-hook* nil
  "The last operation to be perfomed with a goal set before returning
  it. Here, you can specify to generate the goals from protogoals,
  generate the theory file, or even launching the prover! Please,
  dynamically-bind this variable, but do not set it globally for
  hygiene.")

(defvar ir.vc.core:*default-goal-set-hook* #'identity
  "The last operation to be perfomed by default (when *goal-set-hook*
  has not been defined) with a goal set before returning it. This is
  the default operation of the VCGEN when generating code. Please,
  refer to `ir.vc.core:*goal-set-hook*' for more information.")

(defmacro with-goal-set (&body body)
  `(let ((*goal-set* nil))
     ,@body
     (funcall (or ir.vc.core:*goal-set-hook* ,ir.vc.core:*default-goal-set-hook*) (reverse *goal-set*))))

(defun @-p (form)
  "Returns whether the form is a funcall."
  (and (consp form)
       (eq 'ir.vc.core:@
	   (car form))))

(defun expr-postcondition (form &optional results)
  "Gets the postcondition of an expression, if that expression is a
  funcall. If it is not, it returns NIL (which is a suitable return
  value for `with-premise')."
  (if (@-p form)
      (@postcd (cadr form) (cddr form) results)
      (list 'ir.vc.core:@ '= results form)))

(defmacro assume-binding (lhs form &body body)
  (if lhs
      `(with-premise ((expr-postcondition ',form ',lhs))
	,@body)))


(defmacro ir.vc.core:define (&whole definition
			       function-name typed-lambda-list result-arg
			     &body full-body)
  "`DEFINE' introduces a set of goals. There should be pre/post
  conditions in this body, and from the expression (likely a letfun)
  we should increase our goal-set until we finally prove the latest
  expression implies the postcondition. For the moment, a define is
  self-contained, meaning definitions inside cannot call another
  define."
  (declare (ignorable result-arg full-body))
  (let ((body (remove-decls (function-body (cdr definition)))))
    `(defun ,function-name ()
       (with-goal-set
	 (with-empty-premise-list
	   (with-variables ,typed-lambda-list
	     (with-function-definition ',(cdr definition)
	       (with-current-function ',function-name
		 (with-premise ((@precd ',function-name ',(drop-types typed-lambda-list))
				:name ,(symbol-name function-name))
		   ,@body)))))))))

(defmacro ir.vc.core:letfun (definitions
			     &body full-body)
  `(with-function-definitions ',definitions
     ;; We need to verify each function in the letfun.  Inner
     ;; non-pre/post functions will be verified as if the
     ;; current-function was the toplevel one. Functions with
     ;; pre/post conditions will be verified only up to their
     ;; postcondition.

     ,@(mapcar
	(lambda (e)
	  (destructuring-bind
		(function-name typed-lambda-list result-lambda-list &body inner-body) e
	    (declare (ignore result-lambda-list))
	    `(with-empty-premise-list
		 (with-current-function ',function-name
		   (with-variables ,typed-lambda-list
		     (with-premise ((@precd ',function-name)
				    :name ,(format nil "~A_" function-name))
		       ,@(remove-decls inner-body)))))))
	definitions)

     ;; We also need to verify the main toplevel function
     ,@full-body))


(defun drop-types (typed-var-list)
  (mapcar #'car typed-var-list))

(defun drop-types-from-case-pattern (pattern)
  (typecase pattern
    (symbol pattern)
    (cons (case (car pattern)
	    (ir.vc.core:the (third pattern)
			    )
	    (ir.vc.core:@ pattern)
	    ;; Unmatched case TUPLE
	    ))))

(defun case-alternative (case-condition)
  (lambda (alt idx)
    (destructuring-bind (pattern form) alt
      `(with-premise ('true
		      :name (format nil "case_~D" ,idx))
	 (assume-binding ,(drop-types-from-case-pattern pattern) ',case-condition
	   ,form)))))

(defun case-default-p (alt)
  (eq (car alt)
      'default))

(defun case-alternative-default (condition default-alternative alternative-list)
  (if alternative-list
      (let ((pattern (caar alternative-list)))
	`(with-premise ((list 'ir.vc.core:@ '<> ,(drop-types-from-case-pattern pattern) ',condition))
	   ,(case-alternative-default condition default-alternative (cdr alternative-list))))
      (let ((default-body (second default-alternative)))
	default-body)))

(defmacro ir.vc.core:case (condition &body alternative-list)
  "A `ir.vc.core:CASE' with n alternatives will generate n goals, one
  per alternative, sequentially."
  (let ((non-default-alternative-list (remove-if #'case-default-p alternative-list))
	(default-alternative-list (remove-if-not #'case-default-p alternative-list)))
    (let ((default-alternative (car default-alternative-list)))
      (assert (eq nil (cdr default-alternative-list)))
      `(let ((case-condition ',condition))
	 (declare (ignore case-condition))
	 ,@(loop for elt in non-default-alternative-list and idx from 0
	      collect (funcall (case-alternative condition) elt idx))
	 ,(when default-alternative
		`(with-premise ('true
				:name "case_def")
		   ,(case-alternative-default condition default-alternative non-default-alternative-list)))))))

(defmacro ir.vc.core:the (expr-type value)
  `(terminal-expression (,value) :type ,expr-type))

(defmacro maybe-output-precd-goal (val &key name)
  (when (@-p val)
    `(output-goal (@precd ',(cadr val) ',(cddr val)) :name ,name)))

(defmacro ir.vc.core:let (typed-var-list val &body body)
  "Lexically binds a var, syntax is: (let var val body-form). It can
   destructure tuples as (let (a b) (list a b) a)"
  (assert (not (cdr body))) ;; Only one expression
  `(progn
     (maybe-output-precd-goal ,val :name "let rhs precondition")
     (with-variables ,typed-var-list
       (with-premise ((@precd ',(cadr val) ',(cddr val))
		      :name "let rhs precondition")
	 (assume-binding ,(drop-types typed-var-list) ,val
	   ,@body)))))

(defmacro ir.vc.core:@ (function-name &rest rest)
  "We will use this macro to call all further functions. Depending
  on whether they already have pre/post conditions on them, we will
  terminate the goal or pursue further by interpreting the next
  function."
  (let ((precd `(@precd ',function-name ',rest))
	(postcd `(@postcd ',function-name ',rest (drop-types (get-current-typed-result-list)))))
    `(progn
       (output-goal ,precd :name ,(format nil "~(~A~) precondition" function-name))

       (with-premise (,precd)
	 (macrolet ((ir.vc.core:the (type value) (declare (ignore type)) value))
	   (with-premise ((list :forall (get-current-typed-result-list)))
	     (if ,postcd
		 (with-premise (,postcd
				:name ,(format nil "~(~A~) postcondition" function-name))
		   (terminal-expression ((ir.vc.core:@ ,function-name ,@(mapcar #'macroexpand-1 rest))) :norename t))
		 (terminal-expression ((ir.vc.core:@ ,function-name ,@(mapcar #'macroexpand-1 rest))) :norename t))))))))


(defun output-goal (target &key name)
  (when (not (eq target 'true))
    (push (reverse (cons (list name target) *premise-list*)) *goal-set*)))



