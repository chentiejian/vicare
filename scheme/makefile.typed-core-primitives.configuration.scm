;;
;;Part of: Vicare Scheme
;;Contents: table of expand-time properties for configuration core primitives
;;Date: Tue Dec 25, 2015
;;
;;Abstract
;;
;;
;;
;;Copyright (C) 2015 Marco Maggi <marco.maggi-ipsu@poste.it>
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

(section

 (let-syntax
     ((declare (syntax-rules ()
		 ((_ ?who)
		  (declare-core-primitive ?who
		      (safe)
		    (signatures
		     (()			=> (<boolean>)))
		    (attributes
		     (()			effect-free))))
		 )))
   (declare vicare-built-with-ffi-enabled)
   (declare vicare-built-with-iconv-enabled)
   (declare vicare-built-with-posix-enabled)
   (declare vicare-built-with-glibc-enabled)
   (declare vicare-built-with-linux-enabled)
   (declare vicare-built-with-srfi-enabled)
   (declare vicare-built-with-arguments-validation-enabled)
   #| end of LET-SYNTAX |# )


 /section)

;;; end of file
;; Local Variables:
;; mode: vicare
;; coding: utf-8-unix
;; eval: (put 'declare-core-primitive		'scheme-indent-function 2)
;; End:
