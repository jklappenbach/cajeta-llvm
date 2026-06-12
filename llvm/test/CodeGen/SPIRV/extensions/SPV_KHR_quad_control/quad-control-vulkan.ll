; Quad (2x2) cross-lane ops reached from the Vulkan/Shader flavor via the
; llvm.spv.quad.* intrinsics and GlobalISel selection. broadcast and swap are
; core SPIR-V (GroupNonUniformQuad); all/any are SPV_KHR_quad_control (a
; quad-wide vote with no Scope operand, implicitly quad-scoped). The __spirv
; quad builtins are OpenCL-only (the builtin lowering is isShader()-gated off),
; so the Shader flavor needs the intrinsics, following the shader-clock,
; subgroup-rotate, ray-query, and cooperative-matrix pattern.
;
; A GLCompute kernel broadcasts a descriptor-bound value from quad lane 0, swaps
; it diagonally across the quad, then quad-votes a predicate over the 2x2 group.
; The whole module passes spirv-val --target-env vulkan1.3.

; RUN: llc -verify-machineinstrs -O0 -mtriple=spirv-unknown-vulkan1.3-compute --spirv-ext=+SPV_KHR_quad_control %s -o - | FileCheck %s
; RUN: %if spirv-tools %{ llc -O0 -mtriple=spirv-unknown-vulkan1.3-compute --spirv-ext=+SPV_KHR_quad_control %s -o - -filetype=obj | spirv-val --target-env vulkan1.3 %}

; CHECK-DAG: OpCapability GroupNonUniformQuad
; CHECK-DAG: OpCapability QuadControlKHR
; CHECK-DAG: OpExtension "SPV_KHR_quad_control"
; CHECK-DAG: OpEntryPoint GLCompute %[[#entry:]] "main"
; The Subgroup scope (3) and the quad lane / direction (0, 2) are constant <id>s.
; CHECK-DAG: %[[#u32:]] = OpTypeInt 32 0
; CHECK-DAG: %[[#bool:]] = OpTypeBool
; CHECK-DAG: %[[#scope:]] = OpConstant %[[#u32]] 3
; CHECK: %[[#v:]] = OpLoad %[[#u32]]
; CHECK: %[[#b:]] = OpGroupNonUniformQuadBroadcast %[[#u32]] %[[#scope]] %[[#v]]
; CHECK: %[[#s:]] = OpGroupNonUniformQuadSwap %[[#u32]] %[[#scope]] %[[#b]]
; CHECK: %[[#qall:]] = OpGroupNonUniformQuadAllKHR %[[#bool]] %[[#p:]]
; CHECK: %[[#qany:]] = OpGroupNonUniformQuadAnyKHR %[[#bool]] %[[#p]]

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
  %b = tail call i32 @llvm.spv.quad.broadcast.i32(i32 %v, i32 0)
  %s = tail call i32 @llvm.spv.quad.swap.i32(i32 %b, i32 2)
  %p = icmp ugt i32 %s, 0
  %qall = tail call i1 @llvm.spv.quad.all(i1 %p)
  %qany = tail call i1 @llvm.spv.quad.any(i1 %p)
  %vote = select i1 %qall, i32 %s, i32 0
  %vote2 = select i1 %qany, i32 %vote, i32 0
  store i32 %vote2, ptr addrspace(11) %po, align 4
  ret void
}

attributes #0 = { "hlsl.numthreads"="1,1,1" "hlsl.shader"="compute" }
