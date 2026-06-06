; cajeta-gpu shader clock: OpReadClockKHR reached from the Vulkan/Shader flavor
; via the llvm.spv.read.clock intrinsic + GlobalISel selection. The OpReadClockKHR
; builtin path (__spirv_ReadClockKHR / clock_read_*) is OpenCL-only (the builtin
; lowering is isShader()-gated off), so the Shader flavor Cajeta emits needs the
; intrinsic — the texture / ray-query / cooperative-matrix pattern.
;
; A GLCompute kernel times a region: read the subgroup clock (scope 3) before and
; after, store the tick delta into a descriptor-bound StorageBuffer. Two reads
; must stay two OpReadClockKHR (InaccessibleMemOnly prevents CSE). The whole
; module passes spirv-val --target-env vulkan1.3.

; RUN: llc -verify-machineinstrs -O0 -mtriple=spirv-unknown-vulkan1.3-compute --spirv-ext=+SPV_KHR_shader_clock %s -o - | FileCheck %s
; RUN: %if spirv-tools %{ llc -O0 -mtriple=spirv-unknown-vulkan1.3-compute --spirv-ext=+SPV_KHR_shader_clock %s -o - -filetype=obj | spirv-val --target-env vulkan1.3 %}

; CHECK-DAG: OpCapability ShaderClockKHR
; CHECK-DAG: OpExtension "SPV_KHR_shader_clock"
; CHECK-DAG: OpEntryPoint GLCompute %[[#entry:]] "main"
; The Subgroup scope (3) is a constant <id> operand to each read.
; CHECK-DAG: %[[#u64:]] = OpTypeInt 64 0
; CHECK-DAG: %[[#u32:]] = OpTypeInt 32 0
; CHECK-DAG: %[[#scope:]] = OpConstant %[[#u32]] 3
; CHECK: %[[#t0:]] = OpReadClockKHR %[[#u64]] %[[#scope]]
; CHECK: %[[#t1:]] = OpReadClockKHR %[[#u64]] %[[#scope]]
; CHECK: %[[#d:]] = OpISub %[[#u64]] %[[#t1]] %[[#t0]]

@.str.o = private unnamed_addr constant [2 x i8] c"o\00", align 1

define void @main() local_unnamed_addr #0 {
entry:
  %t0 = tail call i64 @llvm.spv.read.clock(i32 3)
  %t1 = tail call i64 @llvm.spv.read.clock(i32 3)
  %d = sub i64 %t1, %t0
  %ho = tail call target("spirv.VulkanBuffer", [0 x i64], 12, 1)
      @llvm.spv.resource.handlefrombinding.tspirv.VulkanBuffer_a0i64_12_1t(
          i32 0, i32 0, i32 1, i32 0, ptr nonnull @.str.o)
  %po = tail call ptr addrspace(11)
      @llvm.spv.resource.getpointer.p11.tspirv.VulkanBuffer_a0i64_12_1t(
          target("spirv.VulkanBuffer", [0 x i64], 12, 1) %ho, i32 0)
  store i64 %d, ptr addrspace(11) %po, align 8
  ret void
}

attributes #0 = { "hlsl.numthreads"="1,1,1" "hlsl.shader"="compute" }
