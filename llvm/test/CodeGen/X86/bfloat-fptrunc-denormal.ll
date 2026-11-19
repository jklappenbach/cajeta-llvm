; Every x86 bf16 conversion instruction (AVX512-BF16's vcvtneps2bf16 and
; AVX-NE-CONVERT's form) treats a float32 denormal input as zero. An IEEE fptrunc
; keeps it: 1.0e-40 (0x000116C2) narrows to the bf16 subnormal 0x0001. So the
; instruction is chosen only where the function's float32 denormal mode lets inputs
; flush. Otherwise the conversion is the integer round-to-nearest-even it is on a CPU
; without the feature (cajeta bf16-cast-denormals, 2026-11-18). Instruction flags
; such as afn do not decide it: type legalization drops them before the scalar and
; promoted-arithmetic roundings reach the lowering.
;
; RUN: llc < %s -mtriple=x86_64-linux-gnu -mattr=+avx512bf16,+avx512vl | FileCheck %s
; RUN: llc < %s -mtriple=x86_64-linux-gnu -mattr=+avxneconvert,+f16c | FileCheck %s

; CHECK-LABEL: scalar_ieee:
; CHECK-NOT: vcvtneps2bf16
; CHECK: ret
define bfloat @scalar_ieee(float %x) {
  %b = fptrunc float %x to bfloat
  ret bfloat %b
}

; CHECK-LABEL: scalar_afn:
; CHECK-NOT: vcvtneps2bf16
; CHECK: ret
define bfloat @scalar_afn(float %x) {
  %b = fptrunc afn float %x to bfloat
  ret bfloat %b
}

; CHECK-LABEL: scalar_daz:
; CHECK: vcvtneps2bf16
define bfloat @scalar_daz(float %x) #0 {
  %b = fptrunc float %x to bfloat
  ret bfloat %b
}

; CHECK-LABEL: v8_ieee:
; CHECK-NOT: vcvtneps2bf16
; CHECK: ret
define <8 x bfloat> @v8_ieee(<8 x float> %x) {
  %b = fptrunc <8 x float> %x to <8 x bfloat>
  ret <8 x bfloat> %b
}

; CHECK-LABEL: v8_afn:
; CHECK-NOT: vcvtneps2bf16
; CHECK: ret
define <8 x bfloat> @v8_afn(<8 x float> %x) {
  %b = fptrunc afn <8 x float> %x to <8 x bfloat>
  ret <8 x bfloat> %b
}

; CHECK-LABEL: v8_daz:
; CHECK: vcvtneps2bf16
define <8 x bfloat> @v8_daz(<8 x float> %x) #0 {
  %b = fptrunc <8 x float> %x to <8 x bfloat>
  ret <8 x bfloat> %b
}

; CHECK-LABEL: v16_ieee:
; CHECK-NOT: vcvtneps2bf16
; CHECK: ret
define <16 x bfloat> @v16_ieee(<16 x float> %x) {
  %b = fptrunc <16 x float> %x to <16 x bfloat>
  ret <16 x bfloat> %b
}

; bf16 arithmetic is computed in float32 and rounded back by the backend: that
; rounding is IEEE too unless the operation allows flushing.
; CHECK-LABEL: add_ieee:
; CHECK-NOT: vcvtneps2bf16
; CHECK: ret
define bfloat @add_ieee(bfloat %a, bfloat %b) {
  %r = fadd bfloat %a, %b
  ret bfloat %r
}

; CHECK-LABEL: vmul_ieee:
; CHECK-NOT: vcvtneps2bf16
; CHECK: ret
define <8 x bfloat> @vmul_ieee(<8 x bfloat> %a, <8 x bfloat> %b) {
  %r = fmul <8 x bfloat> %a, %b
  ret <8 x bfloat> %r
}

; CHECK-LABEL: vmul_daz:
; CHECK: vcvtneps2bf16
define <8 x bfloat> @vmul_daz(<8 x bfloat> %a, <8 x bfloat> %b) #0 {
  %r = fmul <8 x bfloat> %a, %b
  ret <8 x bfloat> %r
}

attributes #0 = { denormal_fpenv(float: preservesign) }
