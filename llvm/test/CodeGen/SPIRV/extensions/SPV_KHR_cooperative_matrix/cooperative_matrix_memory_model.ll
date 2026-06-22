; A Shader module requiring CooperativeMatrixKHR derives the VulkanKHR memory
; model with no spirv.MemoryModel metadata (GLSL450 + CoopMatrix is invalid).

; RUN: llc -verify-machineinstrs -O0 -mtriple=spirv-unknown-vulkan1.3-compute --spirv-ext=+SPV_KHR_cooperative_matrix,+SPV_KHR_vulkan_memory_model %s -o - | FileCheck %s

; CHECK-DAG: OpCapability CooperativeMatrixKHR
; CHECK-DAG: OpExtension "SPV_KHR_cooperative_matrix"
; CHECK-DAG: OpCapability VulkanMemoryModelKHR
; CHECK-DAG: OpExtension "SPV_KHR_vulkan_memory_model"
; CHECK-DAG: OpMemoryModel Logical VulkanKHR

define spir_func void @use(ptr %p) {
entry:
  %a = call target("spirv.CooperativeMatrixKHR", float, 3, 16, 16, 0)
       @llvm.spv.cooperative.matrix.load(ptr %p, i32 0, i32 16)
  call void @llvm.spv.cooperative.matrix.store(
         ptr %p,
         target("spirv.CooperativeMatrixKHR", float, 3, 16, 16, 0) %a,
         i32 0, i32 16)
  ret void
}
