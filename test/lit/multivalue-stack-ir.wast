;; NOTE: Assertions have been generated by update_lit_checks.py and should not be edited.
;; RUN: wasm-opt %s -all --generate-stack-ir --optimize-stack-ir --roundtrip -S -o - | filecheck %s

;; Test that Stack IR optimizations do not interact poorly with the
;; optimizations for extracts of gets of tuple locals in the binary writer.

(module
 ;; CHECK:      (func $test (type $0)
 ;; CHECK-NEXT:  (local $pair f32)
 ;; CHECK-NEXT:  (local $f32 f32)
 ;; CHECK-NEXT:  (local $2 i32)
 ;; CHECK-NEXT:  (local $3 f32)
 ;; CHECK-NEXT:  (local.set $pair
 ;; CHECK-NEXT:   (block (result f32)
 ;; CHECK-NEXT:    (local.set $3
 ;; CHECK-NEXT:     (f32.const 0)
 ;; CHECK-NEXT:    )
 ;; CHECK-NEXT:    (local.set $2
 ;; CHECK-NEXT:     (i32.const 0)
 ;; CHECK-NEXT:    )
 ;; CHECK-NEXT:    (local.get $3)
 ;; CHECK-NEXT:   )
 ;; CHECK-NEXT:  )
 ;; CHECK-NEXT:  (local.set $f32
 ;; CHECK-NEXT:   (local.get $pair)
 ;; CHECK-NEXT:  )
 ;; CHECK-NEXT: )
 (func $test
  (local $pair (f32 i32))
  (local $f32 f32)
  ;; Normally this get-set pair would be eliminated by stack IR optimizations,
  ;; but then the binary writer's tuple optimizations would leave the only the
  ;; f32 on the stack where an f32 and i32 would be expected. We disable stack
  ;; IR optimizations on tuples to avoid this.
  (local.set $pair
   (tuple.make 2
    (f32.const 0)
    (i32.const 0)
   )
  )
  (local.set $f32
   (tuple.extract 0
    (local.get $pair)
   )
  )
 )
)