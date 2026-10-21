; acc + s * src on accumulator tiles under the Vulkan/Shader flavor: the
; times.scalar and fadd intrinsics select OpMatrixTimesScalar and OpFAdd on
; OpTypeCooperativeMatrixKHR values, each decorated NoContraction so a driver
; may not fuse them into an fma (callers rely on two roundings).

; RUN: llc -verify-machineinstrs -O0 -mtriple=spirv-unknown-vulkan1.3-compute --spirv-ext=+SPV_KHR_cooperative_matrix,+SPV_KHR_vulkan_memory_model %s -o - | FileCheck %s
; RUN: %if spirv-tools %{ llc -O0 -mtriple=spirv-unknown-vulkan1.3-compute --spirv-ext=+SPV_KHR_cooperative_matrix,+SPV_KHR_vulkan_memory_model %s -o - -filetype=obj | spirv-val --target-env vulkan1.3 %}

; CHECK-DAG: OpCapability CooperativeMatrixKHR
; CHECK-DAG: OpDecorate %[[#M:]] NoContraction
; CHECK-DAG: OpDecorate %[[#S:]] NoContraction
; CHECK-DAG: %[[#F32:]] = OpTypeFloat 32
; CHECK-DAG: %[[#ACC:]] = OpTypeCooperativeMatrixKHR %[[#F32]]
; CHECK: %[[#SRC:]] = OpCooperativeMatrixLoadKHR %[[#ACC]]
; CHECK: %[[#DST:]] = OpCooperativeMatrixLoadKHR %[[#ACC]]
; CHECK: %[[#M]] = OpMatrixTimesScalar %[[#ACC]] %[[#SRC]] %[[#]]
; CHECK: %[[#S]] = OpFAdd %[[#ACC]] %[[#DST]] %[[#M]]
; CHECK: OpCooperativeMatrixStoreKHR %[[#]] %[[#S]]

@src = internal addrspace(3) global [256 x float] poison, align 16
@dst = internal addrspace(3) global [256 x float] poison, align 16

define void @scale_add() #0 {
entry:
  %src = call target("spirv.CooperativeMatrixKHR", float, 3, 16, 16, 2)
         @llvm.spv.cooperative.matrix.load(ptr addrspace(3) @src, i32 0, i32 16)
  %dst = call target("spirv.CooperativeMatrixKHR", float, 3, 16, 16, 2)
         @llvm.spv.cooperative.matrix.load(ptr addrspace(3) @dst, i32 0, i32 16)
  %m = call target("spirv.CooperativeMatrixKHR", float, 3, 16, 16, 2)
       @llvm.spv.cooperative.matrix.times.scalar(
         target("spirv.CooperativeMatrixKHR", float, 3, 16, 16, 2) %src,
         float 0x3F50000000000000)
  %r = call target("spirv.CooperativeMatrixKHR", float, 3, 16, 16, 2)
       @llvm.spv.cooperative.matrix.fadd(
         target("spirv.CooperativeMatrixKHR", float, 3, 16, 16, 2) %dst,
         target("spirv.CooperativeMatrixKHR", float, 3, 16, 16, 2) %m)
  call void @llvm.spv.cooperative.matrix.store(
         ptr addrspace(3) @dst,
         target("spirv.CooperativeMatrixKHR", float, 3, 16, 16, 2) %r,
         i32 0, i32 16)
  ret void
}

attributes #0 = { "hlsl.shader"="compute" "hlsl.numthreads"="32,1,1" }
