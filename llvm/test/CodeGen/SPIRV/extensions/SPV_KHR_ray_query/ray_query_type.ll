; cajeta-gpu C3.3 increment 1: SPV_KHR_ray_query opaque RayQuery TYPE.
; Proves the backend lowers target("spirv.RayQueryKHR") to OpTypeRayQueryKHR under
; the Vulkan flavor (ray query is an EnvVulkan-only extension), gated behind the
; RayQueryKHR capability + SPV_KHR_ray_query extension — and errors cleanly without
; the extension enabled.
;
; This is a text-emission check only: a type-only module forces the type via a
; by-value parameter (which pulls in the Linkage capability), so it is intentionally
; not run through spirv-val here. A spirv-val-clean, query-USING compute kernel
; arrives with the ray-query operations in increment 2.

; RUN: not llc -O0 -mtriple=spirv-unknown-vulkan1.3-compute %s -o /dev/null 2>&1 | FileCheck %s --check-prefix=CHECK-ERROR
; RUN: llc -verify-machineinstrs -O0 -mtriple=spirv-unknown-vulkan1.3-compute --spirv-ext=+SPV_KHR_ray_query %s -o - | FileCheck %s

; CHECK-ERROR: LLVM ERROR: OpTypeRayQueryKHR type requires the following SPIR-V extension: SPV_KHR_ray_query

; CHECK-DAG: OpCapability RayQueryKHR
; CHECK-DAG: OpExtension "SPV_KHR_ray_query"
; CHECK-DAG: {{%[0-9]+}} = OpTypeRayQueryKHR

; A by-value parameter of the opaque type forces OpTypeRayQueryKHR into the module
; (referenced by OpTypeFunction — cannot be eliminated like an unused local).
define spir_func void @use_ray_query(target("spirv.RayQueryKHR") %rq) {
entry:
  ret void
}
