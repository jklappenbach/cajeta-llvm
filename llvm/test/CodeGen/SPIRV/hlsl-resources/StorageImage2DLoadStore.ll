; RUN: llc -O0 -verify-machineinstrs -mtriple=spirv-unknown-vulkan1.3-compute %s -o - | FileCheck %s
; RUN: %if spirv-tools %{ llc -O0 -mtriple=spirv-unknown-vulkan1.3-compute %s -o - -filetype=obj | spirv-val --target-env vulkan1.3 %}

; A 2-D storage image write and read. llvm.spv.resource.store.2d /
; llvm.spv.resource.load.2d take a 2-component integer coordinate (unlike
; store.typedbuffer / load.typedbuffer, which take a scalar index) and lower to a
; single OpImageWrite / OpImageRead. The image declares the R32f known format, so
; the access needs only the Shader capability (Unknown format would require
; StorageImage{Write,Read}WithoutFormat, unavailable for SPIR-V < 1.6). A scalar
; load result is read as a vec4 and component 0 extracted.

@.str.img = private unnamed_addr constant [4 x i8] c"img\00", align 1

; CHECK-DAG: [[float:%[0-9]+]] = OpTypeFloat 32
; CHECK-DAG: [[v4float:%[0-9]+]] = OpTypeVector [[float]] 4
; CHECK-DAG: [[ImageType:%[0-9]+]] = OpTypeImage [[float]] 2D 2 0 0 2 R32f {{$}}

; CHECK: OpImageWrite {{%[0-9]+}} {{%[0-9]+}} {{%[0-9]+}}

define void @StorageImage2D_Store() #0 {
  %img = call target("spirv.Image", float, 1, 2, 0, 0, 2, 3)
      @llvm.spv.resource.handlefrombinding.tspirv.Image_f32_1_2_0_0_2_3(
          i32 0, i32 0, i32 1, i32 0, ptr nonnull @.str.img)
  %c0 = insertelement <2 x i32> poison, i32 1, i64 0
  %coord = insertelement <2 x i32> %c0, i32 2, i64 1
  %texel = insertelement <4 x float> zeroinitializer, float 7.000000e+00, i64 0
  call void @llvm.spv.resource.store.2d.tspirv.Image_f32_1_2_0_0_2_3t.v4f32(
      target("spirv.Image", float, 1, 2, 0, 0, 2, 3) %img,
      <2 x i32> %coord, <4 x float> %texel)
  ret void
}

; CHECK: OpImageRead {{%[0-9]+}} {{%[0-9]+}} {{%[0-9]+}}

define void @StorageImage2D_LoadStore() #0 {
  %img = call target("spirv.Image", float, 1, 2, 0, 0, 2, 3)
      @llvm.spv.resource.handlefrombinding.tspirv.Image_f32_1_2_0_0_2_3(
          i32 0, i32 0, i32 1, i32 0, ptr nonnull @.str.img)
  %c0 = insertelement <2 x i32> poison, i32 3, i64 0
  %coord = insertelement <2 x i32> %c0, i32 4, i64 1
  %v = call float @llvm.spv.resource.load.2d.f32.tspirv.Image_f32_1_2_0_0_2_3t(
      target("spirv.Image", float, 1, 2, 0, 0, 2, 3) %img, <2 x i32> %coord)
  %v2 = fadd float %v, 1.000000e+00
  %texel = insertelement <4 x float> zeroinitializer, float %v2, i64 0
  call void @llvm.spv.resource.store.2d.tspirv.Image_f32_1_2_0_0_2_3t.v4f32(
      target("spirv.Image", float, 1, 2, 0, 0, 2, 3) %img,
      <2 x i32> %coord, <4 x float> %texel)
  ret void
}

attributes #0 = { convergent noinline norecurse "hlsl.numthreads"="64,1,1" "hlsl.shader"="compute" }
