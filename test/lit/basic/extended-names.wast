;; NOTE: Assertions have been generated by update_lit_checks.py --all-items and should not be edited.

;; RUN: wasm-opt %s -all -o %t.text.wast -g -S
;; RUN: wasm-as %s -all -g -o %t.wasm
;; RUN: wasm-dis %t.wasm -all -o %t.bin.wast
;; RUN: wasm-as %s -all -o %t.nodebug.wasm
;; RUN: wasm-dis %t.nodebug.wasm -all -o %t.bin.nodebug.wast
;; RUN: cat %t.text.wast | filecheck %s --check-prefix=CHECK-TEXT
;; RUN: cat %t.bin.wast | filecheck %s --check-prefix=CHECK-BIN
;; RUN: cat %t.bin.nodebug.wast | filecheck %s --check-prefix=CHECK-BIN-NODEBUG

(module $foo
  ;; CHECK-TEXT:      (memory $m1 1 1)

  ;; CHECK-TEXT:      (data $mydata (i32.const 0) "a")

  ;; CHECK-TEXT:      (data $passive_data "b")

  ;; CHECK-TEXT:      (data $2 "c")

  ;; CHECK-TEXT:      (table $t1 1 funcref)
  ;; CHECK-BIN:      (memory $m1 1 1)

  ;; CHECK-BIN:      (data $mydata (i32.const 0) "a")

  ;; CHECK-BIN:      (data $passive_data "b")

  ;; CHECK-BIN:      (data $2 "c")

  ;; CHECK-BIN:      (table $t1 1 funcref)
  (table $t1 1 funcref)
  (memory $m1 1 1)
  (data $mydata (i32.const 0) "a")
  (data $passive_data "b")
  (data "c")
)
;; CHECK-BIN-NODEBUG:      (memory $0 1 1)

;; CHECK-BIN-NODEBUG:      (data $0 (i32.const 0) "a")

;; CHECK-BIN-NODEBUG:      (data $1 "b")

;; CHECK-BIN-NODEBUG:      (data $2 "c")

;; CHECK-BIN-NODEBUG:      (table $0 1 funcref)
