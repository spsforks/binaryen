;; NOTE: Assertions have been generated by update_lit_checks.py and should not be edited.
;; RUN: wasm-opt %s -all --dse -S -o - | filecheck %s

(module
 (type $A (struct (field (mut i32))))
 (type $B (struct (field (mut f64))))

 ;; CHECK:      (func $simple-param (param $x (ref $A))
 ;; CHECK-NEXT:  (block
 ;; CHECK-NEXT:   (drop
 ;; CHECK-NEXT:    (local.get $x)
 ;; CHECK-NEXT:   )
 ;; CHECK-NEXT:   (drop
 ;; CHECK-NEXT:    (i32.const 10)
 ;; CHECK-NEXT:   )
 ;; CHECK-NEXT:  )
 ;; CHECK-NEXT:  (block
 ;; CHECK-NEXT:   (drop
 ;; CHECK-NEXT:    (local.get $x)
 ;; CHECK-NEXT:   )
 ;; CHECK-NEXT:   (drop
 ;; CHECK-NEXT:    (i32.const 20)
 ;; CHECK-NEXT:   )
 ;; CHECK-NEXT:  )
 ;; CHECK-NEXT:  (struct.set $A 0
 ;; CHECK-NEXT:   (local.get $x)
 ;; CHECK-NEXT:   (i32.const 30)
 ;; CHECK-NEXT:  )
 ;; CHECK-NEXT: )
 (func $simple-param (param $x (ref $A))
  (struct.set $A 0
   (local.get $x)
   (i32.const 10)
  )
  (struct.set $A 0
   (local.get $x)
   (i32.const 20)
  )
  ;; the last store escapes to the outside, and cannot be modified
  (struct.set $A 0
   (local.get $x)
   (i32.const 30)
  )
 )

 ;; CHECK:      (func $simple-local
 ;; CHECK-NEXT:  (local $x (ref null $A))
 ;; CHECK-NEXT:  (block
 ;; CHECK-NEXT:   (drop
 ;; CHECK-NEXT:    (ref.as_non_null
 ;; CHECK-NEXT:     (local.get $x)
 ;; CHECK-NEXT:    )
 ;; CHECK-NEXT:   )
 ;; CHECK-NEXT:   (drop
 ;; CHECK-NEXT:    (i32.const 10)
 ;; CHECK-NEXT:   )
 ;; CHECK-NEXT:  )
 ;; CHECK-NEXT:  (struct.set $A 0
 ;; CHECK-NEXT:   (ref.as_non_null
 ;; CHECK-NEXT:    (local.get $x)
 ;; CHECK-NEXT:   )
 ;; CHECK-NEXT:   (i32.const 20)
 ;; CHECK-NEXT:  )
 ;; CHECK-NEXT: )
 (func $simple-local
  (local $x (ref null $A))
  (struct.set $A 0
   (ref.as_non_null ;; these would trap, but that doesn't matter
    (local.get $x)
   )
   (i32.const 10)
  )
  (struct.set $A 0
   (ref.as_non_null
    (local.get $x)
   )
   (i32.const 20)
  )
 )

 ;; CHECK:      (func $simple-use (param $x (ref $A))
 ;; CHECK-NEXT:  (block
 ;; CHECK-NEXT:   (drop
 ;; CHECK-NEXT:    (local.get $x)
 ;; CHECK-NEXT:   )
 ;; CHECK-NEXT:   (drop
 ;; CHECK-NEXT:    (i32.const 10)
 ;; CHECK-NEXT:   )
 ;; CHECK-NEXT:  )
 ;; CHECK-NEXT:  (struct.set $A 0
 ;; CHECK-NEXT:   (local.get $x)
 ;; CHECK-NEXT:   (i32.const 20)
 ;; CHECK-NEXT:  )
 ;; CHECK-NEXT:  (drop
 ;; CHECK-NEXT:   (struct.get $A 0
 ;; CHECK-NEXT:    (local.get $x)
 ;; CHECK-NEXT:   )
 ;; CHECK-NEXT:  )
 ;; CHECK-NEXT:  (struct.set $A 0
 ;; CHECK-NEXT:   (local.get $x)
 ;; CHECK-NEXT:   (i32.const 30)
 ;; CHECK-NEXT:  )
 ;; CHECK-NEXT: )
 (func $simple-use (param $x (ref $A))
  (struct.set $A 0
   (local.get $x)
   (i32.const 10)
  )
  (struct.set $A 0
   (local.get $x)
   (i32.const 20)
  )
  (drop
   (struct.get $A 0
    (local.get $x)
   )
  )
  (struct.set $A 0
   (local.get $x)
   (i32.const 30)
  )
 )

 ;; CHECK:      (func $two-types (param $x (ref $A)) (param $y (ref $B))
 ;; CHECK-NEXT:  (block
 ;; CHECK-NEXT:   (drop
 ;; CHECK-NEXT:    (local.get $x)
 ;; CHECK-NEXT:   )
 ;; CHECK-NEXT:   (drop
 ;; CHECK-NEXT:    (i32.const 10)
 ;; CHECK-NEXT:   )
 ;; CHECK-NEXT:  )
 ;; CHECK-NEXT:  (block
 ;; CHECK-NEXT:   (drop
 ;; CHECK-NEXT:    (local.get $y)
 ;; CHECK-NEXT:   )
 ;; CHECK-NEXT:   (drop
 ;; CHECK-NEXT:    (f64.const 20)
 ;; CHECK-NEXT:   )
 ;; CHECK-NEXT:  )
 ;; CHECK-NEXT:  (struct.set $A 0
 ;; CHECK-NEXT:   (local.get $x)
 ;; CHECK-NEXT:   (i32.const 30)
 ;; CHECK-NEXT:  )
 ;; CHECK-NEXT: )
 (func $two-types (param $x (ref $A)) (param $y (ref $B))
  (struct.set $A 0
   (local.get $x)
   (i32.const 10)
  )
  ;; the simple analysis currently gives up on a set we cannot easily classify
  (struct.set $B 0
   (local.get $y)



   (f64.const 20) ;; FIXME this one fails



  )
  (struct.set $A 0
   (local.get $x)
   (i32.const 30)
  )
 )

 (func $foo)

 ;; CHECK:      (func $call (param $x (ref $A))
 ;; CHECK-NEXT:  (struct.set $A 0
 ;; CHECK-NEXT:   (local.get $x)
 ;; CHECK-NEXT:   (i32.const 10)
 ;; CHECK-NEXT:  )
 ;; CHECK-NEXT:  (call $foo)
 ;; CHECK-NEXT:  (struct.set $A 0
 ;; CHECK-NEXT:   (local.get $x)
 ;; CHECK-NEXT:   (i32.const 30)
 ;; CHECK-NEXT:  )
 ;; CHECK-NEXT: )
 (func $call (param $x (ref $A))
  (struct.set $A 0
   (local.get $x)
   (i32.const 10)
  )
  ;; the analysis gives up on a call
  (call $foo)
  (struct.set $A 0
   (local.get $x)
   (i32.const 30)
  )
 )
)