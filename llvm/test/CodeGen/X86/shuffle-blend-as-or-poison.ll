; RUN: llc < %s -mtriple=x86_64-unknown-linux-gnu -mcpu=znver5 | FileCheck %s

; A blend of two arms must not become an OR when the lanes it skips are poison:
; an out-of-range shift is "known zero" there, and the and-mask's undef lanes
; are emitted as a splat.

define void @two_arm_select(ptr %out, ptr %in) {
; CHECK-LABEL: two_arm_select:
; CHECK:       vpblendd $240
; CHECK:       vpblendd $240
; CHECK-NOT:   vpternlogd $254
  %v = load <4 x i32>, ptr %in, align 4
  %s2 = shufflevector <4 x i32> %v, <4 x i32> poison, <8 x i32> <i32 2, i32 2, i32 2, i32 2, i32 2, i32 2, i32 2, i32 2>
  %s1 = shufflevector <4 x i32> %v, <4 x i32> poison, <8 x i32> <i32 1, i32 1, i32 1, i32 1, i32 1, i32 1, i32 1, i32 1>
  %s3 = shufflevector <4 x i32> %v, <4 x i32> poison, <8 x i32> <i32 3, i32 3, i32 3, i32 3, i32 3, i32 3, i32 3, i32 3>
  %a = ashr <8 x i32> %s3, <i32 -32, i32 -24, i32 -16, i32 -8, i32 0, i32 8, i32 16, i32 24>
  %b = and <8 x i32> %a, <i32 poison, i32 poison, i32 poison, i32 poison, i32 15, i32 15, i32 15, i32 15>
  %c = ashr <8 x i32> %s1, <i32 -32, i32 -24, i32 -16, i32 -8, i32 0, i32 8, i32 16, i32 24>
  %d = lshr <8 x i32> %c, splat (i32 2)
  %e = and <8 x i32> %d, <i32 poison, i32 poison, i32 poison, i32 poison, i32 48, i32 48, i32 48, i32 48>
  %hi = or disjoint <8 x i32> %b, %e
  %f = ashr <8 x i32> %s1, <i32 0, i32 8, i32 16, i32 24, i32 32, i32 40, i32 48, i32 56>
  %lo = and <8 x i32> %f, <i32 63, i32 63, i32 63, i32 63, i32 poison, i32 poison, i32 poison, i32 poison>
  %r = shufflevector <8 x i32> %lo, <8 x i32> %hi, <8 x i32> <i32 0, i32 1, i32 2, i32 3, i32 12, i32 13, i32 14, i32 15>
  store <8 x i32> %r, ptr %out, align 4
  %out2 = getelementptr i8, ptr %out, i64 32
  %g = lshr <8 x i32> %a, splat (i32 4)
  %h = and <8 x i32> %g, <i32 poison, i32 poison, i32 poison, i32 poison, i32 15, i32 15, i32 15, i32 15>
  %i = ashr <8 x i32> %s2, <i32 -32, i32 -24, i32 -16, i32 -8, i32 0, i32 8, i32 16, i32 24>
  %j = lshr <8 x i32> %i, splat (i32 2)
  %k = and <8 x i32> %j, <i32 poison, i32 poison, i32 poison, i32 poison, i32 48, i32 48, i32 48, i32 48>
  %hi2 = or disjoint <8 x i32> %h, %k
  %l = ashr <8 x i32> %s2, <i32 0, i32 8, i32 16, i32 24, i32 32, i32 40, i32 48, i32 56>
  %lo2 = and <8 x i32> %l, <i32 63, i32 63, i32 63, i32 63, i32 poison, i32 poison, i32 poison, i32 poison>
  %r2 = shufflevector <8 x i32> %lo2, <8 x i32> %hi2, <8 x i32> <i32 0, i32 1, i32 2, i32 3, i32 12, i32 13, i32 14, i32 15>
  store <8 x i32> %r2, ptr %out2, align 4
  ret void
}
