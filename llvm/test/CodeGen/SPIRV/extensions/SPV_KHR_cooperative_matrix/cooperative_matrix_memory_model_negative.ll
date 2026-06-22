; Negative control: a Shader module without CooperativeMatrixKHR keeps the
; default GLSL450 memory model (the upgrade is capability-conditional).

; RUN: llc -verify-machineinstrs -O0 -mtriple=spirv-unknown-vulkan1.3-compute %s -o - | FileCheck %s

; CHECK-NOT: OpCapability VulkanMemoryModelKHR
; CHECK-NOT: OpExtension "SPV_KHR_vulkan_memory_model"
; CHECK: OpMemoryModel Logical GLSL450
; CHECK-NOT: OpMemoryModel Logical VulkanKHR

define spir_func void @nop() {
entry:
  ret void
}
