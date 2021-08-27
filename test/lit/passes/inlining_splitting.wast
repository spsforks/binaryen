;; NOTE: Assertions have been generated by update_lit_checks.py --all-items and should not be edited.

;; RUN: foreach %s %t wasm-opt --inlining --optimize-level=3 --all-features -S -o - | filecheck %s

(module
  ;; CHECK:      (type $i32_=>_none (func (param i32)))

  ;; CHECK:      (type $none_=>_none (func))

  ;; CHECK:      (type $anyref_=>_anyref (func (param anyref) (result anyref)))

  ;; CHECK:      (type $anyref_=>_none (func (param anyref)))

  ;; CHECK:      (import "out" "func" (func $import))
  (import "out" "func" (func $import))

  ;; CHECK:      (global $glob i32 (i32.const 1))
  (global $glob i32 (i32.const 1))

  ;; CHECK:      (start $start-used-globally)
  (start $start-used-globally)

  ;; Pattern A: functions beginning with
  ;;
  ;;   if (simple) return;

  (func $maybe-work-hard (param $x i32)
    ;; A function that does a quick check before any heavy work. We can outline
    ;; the heavy work, so that the condition can be inlined.
    (if
      (local.get $x)
      (return)
    )
    (loop $l
      (call $import)
      (br $l)
    )
  )

  ;; CHECK:      (func $caller
  ;; CHECK-NEXT:  (local $0 i32)
  ;; CHECK-NEXT:  (local $1 i32)
  ;; CHECK-NEXT:  (local $2 i32)
  ;; CHECK-NEXT:  (block
  ;; CHECK-NEXT:   (block $__inlined_func$maybe-work-hard
  ;; CHECK-NEXT:    (local.set $0
  ;; CHECK-NEXT:     (i32.const 1)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (if
  ;; CHECK-NEXT:     (i32.eqz
  ;; CHECK-NEXT:      (local.get $0)
  ;; CHECK-NEXT:     )
  ;; CHECK-NEXT:     (call $maybe-work-hard$byn-outline-A
  ;; CHECK-NEXT:      (local.get $0)
  ;; CHECK-NEXT:     )
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (block
  ;; CHECK-NEXT:   (block $__inlined_func$maybe-work-hard0
  ;; CHECK-NEXT:    (local.set $1
  ;; CHECK-NEXT:     (i32.const 2)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (if
  ;; CHECK-NEXT:     (i32.eqz
  ;; CHECK-NEXT:      (local.get $1)
  ;; CHECK-NEXT:     )
  ;; CHECK-NEXT:     (call $maybe-work-hard$byn-outline-A
  ;; CHECK-NEXT:      (local.get $1)
  ;; CHECK-NEXT:     )
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (block
  ;; CHECK-NEXT:   (block $__inlined_func$maybe-work-hard1
  ;; CHECK-NEXT:    (local.set $2
  ;; CHECK-NEXT:     (i32.const 3)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (if
  ;; CHECK-NEXT:     (i32.eqz
  ;; CHECK-NEXT:      (local.get $2)
  ;; CHECK-NEXT:     )
  ;; CHECK-NEXT:     (call $maybe-work-hard$byn-outline-A
  ;; CHECK-NEXT:      (local.get $2)
  ;; CHECK-NEXT:     )
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $caller
    ;; Call the above function to verify that we can in fact inline it after
    ;; splitting. We should see each of these three calls replaced by inlined
    ;; code performing the if from $maybe-work-hard, and depending on that
    ;; result they each call the outlined code that must *not* be inlined.
    (call $maybe-work-hard (i32.const 1))
    (call $maybe-work-hard (i32.const 2))
    (call $maybe-work-hard (i32.const 3))
  )

  ;; CHECK:      (func $condition-eqz (param $x i32)
  ;; CHECK-NEXT:  (local $1 i32)
  ;; CHECK-NEXT:  (if
  ;; CHECK-NEXT:   (i32.eqz
  ;; CHECK-NEXT:    (i32.eqz
  ;; CHECK-NEXT:     (local.get $x)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:   (block $__inlined_func$condition-eqz$byn-outline-A
  ;; CHECK-NEXT:    (local.set $1
  ;; CHECK-NEXT:     (local.get $x)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (block
  ;; CHECK-NEXT:     (loop $l
  ;; CHECK-NEXT:      (call $import)
  ;; CHECK-NEXT:      (br $l)
  ;; CHECK-NEXT:     )
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (br $__inlined_func$condition-eqz$byn-outline-A)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $condition-eqz (param $x i32)
    (if
      ;; More work in the condition, but work that we still consider worth
      ;; optimizing: a unary op.
      (i32.eqz
        (local.get $x)
      )
      (return)
    )
    (loop $l
      (call $import)
      (br $l)
    )
  )

  ;; CHECK:      (func $condition-global
  ;; CHECK-NEXT:  (if
  ;; CHECK-NEXT:   (i32.eqz
  ;; CHECK-NEXT:    (global.get $glob)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:   (block $__inlined_func$condition-global$byn-outline-A
  ;; CHECK-NEXT:    (block
  ;; CHECK-NEXT:     (loop $l
  ;; CHECK-NEXT:      (call $import)
  ;; CHECK-NEXT:      (br $l)
  ;; CHECK-NEXT:     )
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (br $__inlined_func$condition-global$byn-outline-A)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $condition-global
    (if
      ;; A global read.
      (global.get $glob)
      (return)
    )
    (loop $l
      (call $import)
      (br $l)
    )
  )

  ;; CHECK:      (func $condition-ref.is (param $x anyref)
  ;; CHECK-NEXT:  (local $1 anyref)
  ;; CHECK-NEXT:  (if
  ;; CHECK-NEXT:   (i32.eqz
  ;; CHECK-NEXT:    (ref.is_null
  ;; CHECK-NEXT:     (local.get $x)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:   (block $__inlined_func$condition-ref.is$byn-outline-A
  ;; CHECK-NEXT:    (local.set $1
  ;; CHECK-NEXT:     (local.get $x)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (block
  ;; CHECK-NEXT:     (loop $l
  ;; CHECK-NEXT:      (call $import)
  ;; CHECK-NEXT:      (br $l)
  ;; CHECK-NEXT:     )
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (br $__inlined_func$condition-ref.is$byn-outline-A)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $condition-ref.is (param $x anyref)
    (if
      ;; A ref.is operation.
      (ref.is_null
        (local.get $x)
      )
      (return)
    )
    (loop $l
      (call $import)
      (br $l)
    )
  )

  ;; CHECK:      (func $condition-disallow-binary (param $x i32)
  ;; CHECK-NEXT:  (if
  ;; CHECK-NEXT:   (i32.add
  ;; CHECK-NEXT:    (local.get $x)
  ;; CHECK-NEXT:    (local.get $x)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:   (return)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (loop $l
  ;; CHECK-NEXT:   (call $import)
  ;; CHECK-NEXT:   (br $l)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $condition-disallow-binary (param $x i32)
    (if
      ;; Work we do *not* allow (at least for now), a binary.
      (i32.add
        (local.get $x)
        (local.get $x)
      )
      (return)
    )
    (loop $l
      (call $import)
      (br $l)
    )
  )

  ;; CHECK:      (func $condition-disallow-unreachable (param $x i32)
  ;; CHECK-NEXT:  (if
  ;; CHECK-NEXT:   (i32.eqz
  ;; CHECK-NEXT:    (unreachable)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:   (return)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (loop $l
  ;; CHECK-NEXT:   (call $import)
  ;; CHECK-NEXT:   (br $l)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $condition-disallow-unreachable (param $x i32)
    (if
      ;; Work we do *not* allow (at least for now), an unreachable.
      (i32.eqz
        (unreachable)
      )
      (return)
    )
    (loop $l
      (call $import)
      (br $l)
    )
  )

  ;; CHECK:      (func $start-used-globally
  ;; CHECK-NEXT:  (if
  ;; CHECK-NEXT:   (global.get $glob)
  ;; CHECK-NEXT:   (return)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (loop $l
  ;; CHECK-NEXT:   (call $import)
  ;; CHECK-NEXT:   (br $l)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $start-used-globally
    ;; This looks optimizable, but it is the start function, which means it is
    ;; used in more than the direct calls we can optimize, and so we do not
    ;; optimize it (for now).
    (if
      (global.get $glob)
      (return)
    )
    (loop $l
      (call $import)
      (br $l)
    )
  )

  ;; CHECK:      (func $inlineable
  ;; CHECK-NEXT:  (if
  ;; CHECK-NEXT:   (global.get $glob)
  ;; CHECK-NEXT:   (return)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $inlineable
    ;; This looks optimizable, but it is also inlineable - so we do not need to
    ;; outline it.
    (if
      (global.get $glob)
      (return)
    )
  )

  ;; CHECK:      (func $if-not-first (param $x i32)
  ;; CHECK-NEXT:  (nop)
  ;; CHECK-NEXT:  (if
  ;; CHECK-NEXT:   (local.get $x)
  ;; CHECK-NEXT:   (return)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (loop $l
  ;; CHECK-NEXT:   (call $import)
  ;; CHECK-NEXT:   (br $l)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $if-not-first (param $x i32)
    ;; Except for the initial nop, we should outline this. As the if is not
    ;; first any more, we ignore it.
    (nop)
    (if
      (local.get $x)
      (return)
    )
    (loop $l
      (call $import)
      (br $l)
    )
  )

  ;; CHECK:      (func $if-else (param $x i32)
  ;; CHECK-NEXT:  (if
  ;; CHECK-NEXT:   (local.get $x)
  ;; CHECK-NEXT:   (return)
  ;; CHECK-NEXT:   (nop)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (loop $l
  ;; CHECK-NEXT:   (call $import)
  ;; CHECK-NEXT:   (br $l)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $if-else (param $x i32)
    ;; An else in the if prevents us from recognizing the pattern we want.
    (if
      (local.get $x)
      (return)
      (nop)
    )
    (loop $l
      (call $import)
      (br $l)
    )
  )

  ;; CHECK:      (func $if-non-return (param $x i32)
  ;; CHECK-NEXT:  (if
  ;; CHECK-NEXT:   (local.get $x)
  ;; CHECK-NEXT:   (unreachable)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (loop $l
  ;; CHECK-NEXT:   (call $import)
  ;; CHECK-NEXT:   (br $l)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $if-non-return (param $x i32)
    ;; Something other than a return in the if body prevents us from outlining.
    (if
      (local.get $x)
      (unreachable)
    )
    (loop $l
      (call $import)
      (br $l)
    )
  )

  ;; CHECK:      (func $colliding-name (param $x i32)
  ;; CHECK-NEXT:  (local $1 i32)
  ;; CHECK-NEXT:  (if
  ;; CHECK-NEXT:   (i32.eqz
  ;; CHECK-NEXT:    (local.get $x)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:   (block $__inlined_func$colliding-name$byn-outline-A_0
  ;; CHECK-NEXT:    (local.set $1
  ;; CHECK-NEXT:     (local.get $x)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (block
  ;; CHECK-NEXT:     (loop $l
  ;; CHECK-NEXT:      (call $import)
  ;; CHECK-NEXT:      (br $l)
  ;; CHECK-NEXT:     )
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (br $__inlined_func$colliding-name$byn-outline-A_0)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $colliding-name (param $x i32)
    ;; When we outline this, the name should not collide with that of the
    ;; function after us.
    (if
      (local.get $x)
      (return)
    )
    (loop $l
      (call $import)
      (br $l)
    )
  )

  ;; CHECK:      (func $colliding-name$byn-outline-A
  ;; CHECK-NEXT:  (nop)
  ;; CHECK-NEXT: )
  (func $colliding-name$byn-outline-A
  )

  ;; Pattern B: functions containing
  ;;
  ;;   if (simple1) heavy-work-that-is-unreachable;
  ;;   simple2

  ;; CHECK:      (func $error-if-null (param $x anyref) (result anyref)
  ;; CHECK-NEXT:  (if
  ;; CHECK-NEXT:   (ref.is_null
  ;; CHECK-NEXT:    (local.get $x)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:   (return
  ;; CHECK-NEXT:    (call $error-if-null$byn-outline-B_0
  ;; CHECK-NEXT:     (local.get $x)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (local.get $x)
  ;; CHECK-NEXT: )
  (func $error-if-null (param $x anyref) (result anyref)
    ;; A "as non null" function: If the input is null, issue an error somehow
    ;; (here, by calling an import, but could also be a throwing of an
    ;; exception). If not null, return the value.
    (if
      (ref.is_null
        (local.get $x)
      )
      (block
        (call $import)
        (unreachable)
      )
    )
    (local.get $x)
  )

  ;; CHECK:      (func $too-many (param $x anyref) (result anyref)
  ;; CHECK-NEXT:  (if
  ;; CHECK-NEXT:   (ref.is_null
  ;; CHECK-NEXT:    (local.get $x)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:   (block $block
  ;; CHECK-NEXT:    (call $import)
  ;; CHECK-NEXT:    (unreachable)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (nop)
  ;; CHECK-NEXT:  (local.get $x)
  ;; CHECK-NEXT: )
  (func $too-many (param $x anyref) (result anyref)
    (if
      (ref.is_null
        (local.get $x)
      )
      (block
        (call $import)
        (unreachable)
      )
    )
    (nop) ;; An extra operation here prevents us from identifying the pattern.
    (local.get $x)
  )

  ;; CHECK:      (func $tail-not-simple (param $x anyref) (result anyref)
  ;; CHECK-NEXT:  (if
  ;; CHECK-NEXT:   (ref.is_null
  ;; CHECK-NEXT:    (local.get $x)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:   (block $block
  ;; CHECK-NEXT:    (call $import)
  ;; CHECK-NEXT:    (unreachable)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (unreachable)
  ;; CHECK-NEXT: )
  (func $tail-not-simple (param $x anyref) (result anyref)
    (if
      (ref.is_null
        (local.get $x)
      )
      (block
        (call $import)
        (unreachable)
      )
    )
    (unreachable) ;; This prevents us from optimizing
  )

  ;; CHECK:      (func $reachable-if-body (param $x anyref) (result anyref)
  ;; CHECK-NEXT:  (if
  ;; CHECK-NEXT:   (ref.is_null
  ;; CHECK-NEXT:    (local.get $x)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:   (call $import)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (local.get $x)
  ;; CHECK-NEXT: )
  (func $reachable-if-body (param $x anyref) (result anyref)
    (if
      (ref.is_null
        (local.get $x)
      )
      ;; The if body is not unreachable, which prevents the optimization.
      (call $import)
    )
    (local.get $x)
  )
)

;; CHECK:      (func $maybe-work-hard$byn-outline-A (param $x i32)
;; CHECK-NEXT:  (loop $l
;; CHECK-NEXT:   (call $import)
;; CHECK-NEXT:   (br $l)
;; CHECK-NEXT:  )
;; CHECK-NEXT: )

;; CHECK:      (func $error-if-null$byn-outline-B_0 (param $x anyref) (result anyref)
;; CHECK-NEXT:  (local $1 anyref)
;; CHECK-NEXT:  (local $2 anyref)
;; CHECK-NEXT:  (local $3 anyref)
;; CHECK-NEXT:  (local $4 anyref)
;; CHECK-NEXT:  (local $5 anyref)
;; CHECK-NEXT:  (local $6 anyref)
;; CHECK-NEXT:  (local $7 anyref)
;; CHECK-NEXT:  (local $8 anyref)
;; CHECK-NEXT:  (local $9 anyref)
;; CHECK-NEXT:  (return
;; CHECK-NEXT:   (block (result anyref)
;; CHECK-NEXT:    (block $__inlined_func$error-if-null$byn-outline-B (result anyref)
;; CHECK-NEXT:     (local.set $1
;; CHECK-NEXT:      (local.get $x)
;; CHECK-NEXT:     )
;; CHECK-NEXT:     (local.set $2
;; CHECK-NEXT:      (ref.null any)
;; CHECK-NEXT:     )
;; CHECK-NEXT:     (local.set $3
;; CHECK-NEXT:      (ref.null any)
;; CHECK-NEXT:     )
;; CHECK-NEXT:     (local.set $4
;; CHECK-NEXT:      (ref.null any)
;; CHECK-NEXT:     )
;; CHECK-NEXT:     (local.set $5
;; CHECK-NEXT:      (ref.null any)
;; CHECK-NEXT:     )
;; CHECK-NEXT:     (local.set $6
;; CHECK-NEXT:      (ref.null any)
;; CHECK-NEXT:     )
;; CHECK-NEXT:     (local.set $7
;; CHECK-NEXT:      (ref.null any)
;; CHECK-NEXT:     )
;; CHECK-NEXT:     (local.set $8
;; CHECK-NEXT:      (ref.null any)
;; CHECK-NEXT:     )
;; CHECK-NEXT:     (local.set $9
;; CHECK-NEXT:      (ref.null any)
;; CHECK-NEXT:     )
;; CHECK-NEXT:     (br $__inlined_func$error-if-null$byn-outline-B
;; CHECK-NEXT:      (block (result anyref)
;; CHECK-NEXT:       (block $__inlined_func$error-if-null$byn-outline-B_0 (result anyref)
;; CHECK-NEXT:        (local.set $2
;; CHECK-NEXT:         (local.get $1)
;; CHECK-NEXT:        )
;; CHECK-NEXT:        (local.set $3
;; CHECK-NEXT:         (ref.null any)
;; CHECK-NEXT:        )
;; CHECK-NEXT:        (local.set $4
;; CHECK-NEXT:         (ref.null any)
;; CHECK-NEXT:        )
;; CHECK-NEXT:        (local.set $5
;; CHECK-NEXT:         (ref.null any)
;; CHECK-NEXT:        )
;; CHECK-NEXT:        (local.set $6
;; CHECK-NEXT:         (ref.null any)
;; CHECK-NEXT:        )
;; CHECK-NEXT:        (local.set $7
;; CHECK-NEXT:         (ref.null any)
;; CHECK-NEXT:        )
;; CHECK-NEXT:        (local.set $8
;; CHECK-NEXT:         (ref.null any)
;; CHECK-NEXT:        )
;; CHECK-NEXT:        (local.set $9
;; CHECK-NEXT:         (ref.null any)
;; CHECK-NEXT:        )
;; CHECK-NEXT:        (br $__inlined_func$error-if-null$byn-outline-B_0
;; CHECK-NEXT:         (block (result anyref)
;; CHECK-NEXT:          (block $__inlined_func$error-if-null$byn-outline-B0 (result anyref)
;; CHECK-NEXT:           (local.set $3
;; CHECK-NEXT:            (local.get $2)
;; CHECK-NEXT:           )
;; CHECK-NEXT:           (local.set $4
;; CHECK-NEXT:            (ref.null any)
;; CHECK-NEXT:           )
;; CHECK-NEXT:           (local.set $5
;; CHECK-NEXT:            (ref.null any)
;; CHECK-NEXT:           )
;; CHECK-NEXT:           (local.set $6
;; CHECK-NEXT:            (ref.null any)
;; CHECK-NEXT:           )
;; CHECK-NEXT:           (local.set $7
;; CHECK-NEXT:            (ref.null any)
;; CHECK-NEXT:           )
;; CHECK-NEXT:           (local.set $8
;; CHECK-NEXT:            (ref.null any)
;; CHECK-NEXT:           )
;; CHECK-NEXT:           (local.set $9
;; CHECK-NEXT:            (ref.null any)
;; CHECK-NEXT:           )
;; CHECK-NEXT:           (br $__inlined_func$error-if-null$byn-outline-B0
;; CHECK-NEXT:            (block (result anyref)
;; CHECK-NEXT:             (block $__inlined_func$error-if-null$byn-outline-B_00 (result anyref)
;; CHECK-NEXT:              (local.set $4
;; CHECK-NEXT:               (local.get $3)
;; CHECK-NEXT:              )
;; CHECK-NEXT:              (local.set $5
;; CHECK-NEXT:               (ref.null any)
;; CHECK-NEXT:              )
;; CHECK-NEXT:              (local.set $6
;; CHECK-NEXT:               (ref.null any)
;; CHECK-NEXT:              )
;; CHECK-NEXT:              (local.set $7
;; CHECK-NEXT:               (ref.null any)
;; CHECK-NEXT:              )
;; CHECK-NEXT:              (local.set $8
;; CHECK-NEXT:               (ref.null any)
;; CHECK-NEXT:              )
;; CHECK-NEXT:              (local.set $9
;; CHECK-NEXT:               (ref.null any)
;; CHECK-NEXT:              )
;; CHECK-NEXT:              (br $__inlined_func$error-if-null$byn-outline-B_00
;; CHECK-NEXT:               (block (result anyref)
;; CHECK-NEXT:                (block $__inlined_func$error-if-null$byn-outline-B01 (result anyref)
;; CHECK-NEXT:                 (local.set $5
;; CHECK-NEXT:                  (local.get $4)
;; CHECK-NEXT:                 )
;; CHECK-NEXT:                 (local.set $6
;; CHECK-NEXT:                  (ref.null any)
;; CHECK-NEXT:                 )
;; CHECK-NEXT:                 (local.set $7
;; CHECK-NEXT:                  (ref.null any)
;; CHECK-NEXT:                 )
;; CHECK-NEXT:                 (local.set $8
;; CHECK-NEXT:                  (ref.null any)
;; CHECK-NEXT:                 )
;; CHECK-NEXT:                 (local.set $9
;; CHECK-NEXT:                  (ref.null any)
;; CHECK-NEXT:                 )
;; CHECK-NEXT:                 (br $__inlined_func$error-if-null$byn-outline-B01
;; CHECK-NEXT:                  (block (result anyref)
;; CHECK-NEXT:                   (block $__inlined_func$error-if-null$byn-outline-B_001 (result anyref)
;; CHECK-NEXT:                    (local.set $6
;; CHECK-NEXT:                     (local.get $5)
;; CHECK-NEXT:                    )
;; CHECK-NEXT:                    (local.set $7
;; CHECK-NEXT:                     (ref.null any)
;; CHECK-NEXT:                    )
;; CHECK-NEXT:                    (local.set $8
;; CHECK-NEXT:                     (ref.null any)
;; CHECK-NEXT:                    )
;; CHECK-NEXT:                    (local.set $9
;; CHECK-NEXT:                     (ref.null any)
;; CHECK-NEXT:                    )
;; CHECK-NEXT:                    (br $__inlined_func$error-if-null$byn-outline-B_001
;; CHECK-NEXT:                     (block (result anyref)
;; CHECK-NEXT:                      (block $__inlined_func$error-if-null$byn-outline-B012 (result anyref)
;; CHECK-NEXT:                       (local.set $7
;; CHECK-NEXT:                        (local.get $6)
;; CHECK-NEXT:                       )
;; CHECK-NEXT:                       (local.set $8
;; CHECK-NEXT:                        (ref.null any)
;; CHECK-NEXT:                       )
;; CHECK-NEXT:                       (local.set $9
;; CHECK-NEXT:                        (ref.null any)
;; CHECK-NEXT:                       )
;; CHECK-NEXT:                       (br $__inlined_func$error-if-null$byn-outline-B012
;; CHECK-NEXT:                        (block (result anyref)
;; CHECK-NEXT:                         (block $__inlined_func$error-if-null$byn-outline-B_0012 (result anyref)
;; CHECK-NEXT:                          (local.set $8
;; CHECK-NEXT:                           (local.get $7)
;; CHECK-NEXT:                          )
;; CHECK-NEXT:                          (local.set $9
;; CHECK-NEXT:                           (ref.null any)
;; CHECK-NEXT:                          )
;; CHECK-NEXT:                          (br $__inlined_func$error-if-null$byn-outline-B_0012
;; CHECK-NEXT:                           (block (result anyref)
;; CHECK-NEXT:                            (block $__inlined_func$error-if-null$byn-outline-B0123 (result anyref)
;; CHECK-NEXT:                             (local.set $9
;; CHECK-NEXT:                              (local.get $8)
;; CHECK-NEXT:                             )
;; CHECK-NEXT:                             (block $block
;; CHECK-NEXT:                              (call $import)
;; CHECK-NEXT:                              (unreachable)
;; CHECK-NEXT:                             )
;; CHECK-NEXT:                            )
;; CHECK-NEXT:                           )
;; CHECK-NEXT:                          )
;; CHECK-NEXT:                         )
;; CHECK-NEXT:                        )
;; CHECK-NEXT:                       )
;; CHECK-NEXT:                      )
;; CHECK-NEXT:                     )
;; CHECK-NEXT:                    )
;; CHECK-NEXT:                   )
;; CHECK-NEXT:                  )
;; CHECK-NEXT:                 )
;; CHECK-NEXT:                )
;; CHECK-NEXT:               )
;; CHECK-NEXT:              )
;; CHECK-NEXT:             )
;; CHECK-NEXT:            )
;; CHECK-NEXT:           )
;; CHECK-NEXT:          )
;; CHECK-NEXT:         )
;; CHECK-NEXT:        )
;; CHECK-NEXT:       )
;; CHECK-NEXT:      )
;; CHECK-NEXT:     )
;; CHECK-NEXT:    )
;; CHECK-NEXT:   )
;; CHECK-NEXT:  )
;; CHECK-NEXT: )