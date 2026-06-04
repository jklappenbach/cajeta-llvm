; cajeta-gpu cooperative-matrix increment CM1: SPV_KHR_cooperative_matrix opaque
; CooperativeMatrix TYPE under the Vulkan/Shader flavor. Proves the backend lowers
; the parameterized target("spirv.CooperativeMatrixKHR", elem, scope, rows, cols, use)
; to OpTypeCooperativeMatrixKHR under spirv-unknown-vulkan1.3-compute (the flavor
; Cajeta emits), gated behind the CooperativeMatrixKHR capability + the
; SPV_KHR_cooperative_matrix extension — and errors cleanly without it.
;
; Like the ray-query opaque types, the existing BuiltinType machinery lowers the
; type flavor-agnostically, so no backend change is needed for the TYPE; this test
; locks that in under Vulkan. The cooperative-matrix OPERATIONS (load/store/muladd/
; length) reach the Shader flavor via llvm.spv.cooperative.matrix.* intrinsics in
; increment CM2 (the OpenCL __spirv_* builtin path is isShader()-gated off).
;
; Text-emission check only: a type-only module forces the type via a by-value
; parameter (which pulls in the Linkage capability), so it is intentionally not run
; through spirv-val here. A spirv-val-clean, matrix-USING compute kernel arrives in
; increment CM3.

; RUN: not llc -O0 -mtriple=spirv-unknown-vulkan1.3-compute %s -o /dev/null 2>&1 | FileCheck %s --check-prefix=CHECK-ERROR
; RUN: llc -verify-machineinstrs -O0 -mtriple=spirv-unknown-vulkan1.3-compute --spirv-ext=+SPV_KHR_cooperative_matrix %s -o - | FileCheck %s

; CHECK-ERROR: LLVM ERROR: OpTypeCooperativeMatrixKHR type requires the following SPIR-V extension: SPV_KHR_cooperative_matrix

; CHECK-DAG: OpCapability CooperativeMatrixKHR
; CHECK-DAG: OpExtension "SPV_KHR_cooperative_matrix"
; CHECK-DAG: {{%[0-9]+}} = OpTypeCooperativeMatrixKHR

; A by-value parameter of the opaque type forces OpTypeCooperativeMatrixKHR into the
; module (referenced by OpTypeFunction — cannot be eliminated like an unused local).
define spir_func void @use_coopmat(target("spirv.CooperativeMatrixKHR", i32, 3, 12, 12, 2) %m) {
entry:
  ret void
}
