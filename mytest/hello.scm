(define-module (hello)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix utils)
  #:use-module (guix packages)
  #:use-module (guix git-download)
  #:use-module (guix build-system cmake)
  #:use-module (gnu packages ssh)
  #:use-module (gnu packages web)
  #:use-module (gnu packages)
  #:use-module (guix build utils)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages python)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages tls))

; Check all GVAF with my additions
; guix build -L ./mytest/ mygit

(define (another-fun ext) (string-append "tests/repo/init" ext)) ; GVAF
(define gvaf-subst  '(substitute* "tests/repo/init.c"  ; GVAF
                                 (("#!/bin/sh") (string-append "#!" (which "sh")))))

(define-public mygit
  (define (repo-init-fun ext) (another-fun ext)) ; GVAF
  (let (
        (my-repo-init-1 "tests/repo/init.c")   ; GVAF
        (commit "e98d0a37c93574d2c6107bf7f31140b548c6a7bf")
        (revision "1"))
    (package
      (name "mygit")
      (version (git-version "0.26.6" revision commit))
      (source (origin
                (method git-fetch)
                (uri (git-reference
                      (url "https://github.com/libgit2/libgit2/")
                      (commit commit)))
                (file-name (git-file-name name version))
                (sha256
                 (base32
                  "17pjvprmdrx4h6bb1hhc98w9qi6ki7yl57f090n9kbhswxqfs7s3"))
                (patches (search-patches "libgit2-mtime-0.patch"))
                (modules '((guix build utils)))
                (snippet '(begin
                            ;; Remove bundled software.
                            (delete-file-recursively "deps")
                            #true))))
      (build-system cmake-build-system)
      (outputs '("out" "debug"))
      (arguments
       (let ((my-repo-init (repo-init-fun ".c"))  ; GVAF
             (my-replace '(replace 'check (lambda _ (invoke "./libgit2_clar" "-v" "-Q"))))
             (clar "tests/clar/fs.h"))            ; GVAF
         `(#:tests? #true                         ; Run the test suite (this is the default)
           #:configure-flags '("-DUSE_SHA1DC=ON") ; SHA-1 collision detection
           #:phases
           (modify-phases %standard-phases
                          (add-after 'unpack 'fix-hardcoded-paths
                                     (lambda _
                                     (substitute* ,my-repo-init-1          ; GVAF
                                                  (("#!/bin/sh") (string-append "#!" (which "sh"))))
                                     ,gvaf-subst ; GVAF
                                     (substitute* ,clar
                                                  (("/bin/cp") (which "cp"))
                                                  (("/bin/rm") (which "rm")))
                                 #true))
                          ;; Run checks more verbosely.
                          ,my-replace   ; GVAF
                          ;; (replace 'check
                          ;;        (lambda _ (invoke "./libgit2_clar" "-v" "-Q")))
                        (add-after 'unpack 'make-files-writable-for-tests
                                   (lambda _ (for-each make-file-writable (find-files "." ".*")))))))

       )
      (inputs
       `(("libssh2" ,libssh2)
         ("http-parser" ,http-parser)
         ("python" ,python-wrapper)))
      (native-inputs
       `(("pkg-config" ,pkg-config)))
      (propagated-inputs
       ;; These two libraries are in 'Requires.private' in libgit2.pc.
       `(("openssl" ,openssl)
         ("zlib" ,zlib)))
      (home-page "https://libgit2.github.com/")
      (synopsis "Library providing Git core methods")
      (description
       "Libgit2 is a portable, pure C implementation of the Git core methods
provided as a re-entrant linkable library with a solid API, allowing you to
write native speed custom Git applications in any language with bindings.")
      ;; GPLv2 with linking exception
      (license license:gpl2))))
