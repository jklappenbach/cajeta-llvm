; cajeta-gpu subgroup rotate: OpGroupNonUniformRotateKHR reached from the
; Vulkan/Shader flavor via the llvm.spv.subgroup.rotate intrinsic + GlobalISel
; selection. The __spirv builtin path (sub_group_rotate) is OpenCL-only (the
; builtin lowering is isShader()-gated off), so the Shader flavor Cajeta emits
; needs the intrinsic — the shader-clock / ray-query / cooperative-matrix
; pattern. The opcode, the GroupNonUniformRotateKHR capability, the
; SPV_KHR_subgroup_rotate extension, and the module-analysis requirement all
; already exist in the backend; this wires the intrinsic to the op.
;
; A GLCompute kernel rotates a descriptor-bound value across the subgroup by a
; lane delta and stores it back. The whole module passes spirv-val
; --target-env vulkan1.3.

; RUN: llc -verify-machineinstrs -O0 -mtriple=spirv-unknown-vulkan1.3-compute --spirv-ext=+SPV_KHR_subgroup_rotate %s -o - | FileCheck %s
; RUN: %if spirv-tools %{ llc -O0 -mtriple=spirv-unknown-vulkan1.3-compute --spirv-ext=+SPV_KHR_subgroup_rotate %s -o - -filetype=obj | spirv-val --target-env vulkan1.3 %}

; CHECK-DAG: OpCapability GroupNonUniformRotateKHR
; CHECK-DAG: OpExtension "SPV_KHR_subgroup_rotate"
; CHECK-DAG: OpEntryPoint GLCompute %[[#entry:]] "main"
; The Subgroup scope (3) and the lane delta (1) are constant <id> operands.
; CHECK-DAG: %[[#u32:]] = OpTypeInt 32 0
; CHECK-DAG: %[[#scope:]] = OpConstant %[[#u32]] 3
; CHECK-DAG: %[[#delta:]] = OpConstant %[[#u32]] 1
; CHECK: %[[#v:]] = OpLoad %[[#u32]]
; CHECK: %[[#r:]] = OpGroupNonUniformRotateKHR %[[#u32]] %[[#scope]] %[[#v]] %[[#delta]]

@.str.o = private unnamed_addr constant [2 x i8] c"o\00", align 1

define void @main() local_unnamed_addr #0 {
entry:
  %ho = tail call target("spirv.VulkanBuffer", [0 x i32], 12, 1)
      @llvm.spv.resource.handlefrombinding.tspirv.VulkanBuffer_a0i32_12_1t(
          i32 0, i32 0, i32 1, i32 0, ptr nonnull @.str.o)
  %po = tail call ptr addrspace(11)
      @llvm.spv.resource.getpointer.p11.tspirv.VulkanBuffer_a0i32_12_1t(
          target("spirv.VulkanBuffer", [0 x i32], 12, 1) %ho, i32 0)
  %v = load i32, ptr addrspace(11) %po, align 4
  %r = tail call i32 @llvm.spv.subgroup.rotate.i32(i32 %v, i32 1)
  store i32 %r, ptr addrspace(11) %po, align 4
  ret void
}

attributes #0 = { "hlsl.numthreads"="1,1,1" "hlsl.shader"="compute" }
