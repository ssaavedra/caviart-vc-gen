CAVI-ART CLIR-VCGEN
===================

CLIR-VCGEN is a Verification Condition Generator for verification
purposes on CLIR files.


Description
===========

This VCGEN is a lisp verification condition generator for languages.
It is tailored for CAVI-ART's CLIR, because of its Symbolic Expression
syntax, which gets compiled to executable expressions.

We have a backend system for supporting several backends, both
interactively and non-interactively. Currently, we only support Why3
as an interactive backend. In the future, a better API will export the
underlying backend's options for improving the proofs.

We also have a theory database, so that different theories can be used
in different CLIR files which may come from different origins, and,
for example, need reasoning about numbers taking machine arithmetic
into account or not.


Usage
=====

For the moment, the vcgen can be invoked from an interactive lisp
session (or from another lisp system), via the `ir.vc.user:test-clir`
function, or more easily, via the `ir.vc.user:easy-test` macro.


Usage with easy-test
--------------------

- Launch a lisp session from the `vcgen/` directory
- Write `(load "init.lisp")` in the lisp REPL
- Write `(easy-test qsort quicksort 'qsort)`


easy-test synposis
------------------

`(easy-test FILE-BASENAME FUNCTION-NAME FUNCTION-PACKAGE)`

- FILE-BASENAME is appended `.clir` and searched for at `../test/`.
- FUNCTION-NAME is the toplevel DEFINE-d function to be tested.
- FUNCTION-PACKAGE is the name of the package (as set in
  VERIFICATION-UNIT) in order to find the toplevel function in it.


Dependencies
============

This project needs QuickLisp and uses QLot for managing some of its
dependencies.

Use `(qlot:install 'clir2mlw)` after the first clone to get the
dependencies.


Contributing
============

This project encourages the [GitHub Flow][flow] for external
contributions. Please, send any improvements you may find via a GitHub
Pull Request. You can also send them via email (preferrably as a git
request-pull, but I can also accept git format-patch patches) and I
will merge them.


Acknowledgements
================

This work is partially supported by the Spanish MINECO project
CAVI-ART (TIN2013-44742-C4-3-R), Madrid regional project N-GREENS
Software-CM (S2013/ICE-2731) and UCM grant GR3/14-910502.

CAVI-ART stands for Computer Assisted ValIdation by Analysis,
tRansformation and Testing.