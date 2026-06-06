; A global variable's pointee type is concrete (its value type) and must be used
; even for an undef-initialized, NON-constant aggregate — e.g. a Workgroup
; `[N x T]` shared tile. Otherwise the variable's type is inferred from a flat
; element-typed GEP use as the scalar element, the array-to-pointer-decay rewrite
; is skipped, and under Logical SPIR-V the dynamic index is dropped (every
; invocation accesses element 0). The variable must keep its array type and be
; indexed with an OpAccessChain carrying the dynamic index.

; RUN: llc -verify-machineinstrs -O0 -mtriple=spirv-unknown-vulkan1.3-compute %s -o - | FileCheck %s
; RUN: %if spirv-tools %{ llc -O0 -mtriple=spirv-unknown-vulkan1.3-compute %s -o - -filetype=obj | spirv-val %}

@tile = internal addrspace(3) global [64 x i32] undef, align 16

; CHECK-DAG: %[[#U32:]] = OpTypeInt 32 0
; CHECK-DAG: %[[#Arr:]] = OpTypeArray %[[#U32]] %[[#]]
; CHECK-DAG: %[[#ArrPtr:]] = OpTypePointer Workgroup %[[#Arr]]
; CHECK-DAG: %[[#EltPtr:]] = OpTypePointer Workgroup %[[#U32]]
; CHECK-DAG: %[[#Tile:]] = OpVariable %[[#ArrPtr]] Workgroup

; The (dynamic) index survives as an OpAccessChain into the array tile; it is not
; dropped, and the variable is not collapsed to a scalar `OpTypePointer Workgroup
; %u32` with no index.
; CHECK: %[[#Id:]] = OpCompositeExtract %[[#U32]] %[[#]] 0
; CHECK: %[[#Ptr:]] = OpAccessChain %[[#EltPtr]] %[[#Tile]] %[[#Id]]
; CHECK: OpStore %[[#Ptr]] %[[#]]

define void @store_dynamic_index() #0 {
entry:
  %id = call i32 @llvm.spv.thread.id.in.group.i32(i32 0)
  %p = getelementptr i32, ptr addrspace(3) @tile, i32 %id
  store i32 42, ptr addrspace(3) %p, align 4
  ret void
}

declare i32 @llvm.spv.thread.id.in.group.i32(i32)

attributes #0 = { "hlsl.shader"="compute" "hlsl.numthreads"="64,1,1" }
