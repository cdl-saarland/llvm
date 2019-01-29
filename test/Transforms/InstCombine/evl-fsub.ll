; RUN: opt < %s -instcombine -S | FileCheck %s

; PR4374

define <4 x float> @test1_evl(<4 x float> %x, <4 x float> %y, <4 x i1> %M, i32 %L) {
; CHECK-LABEL: @test1_evl(
;
  %t1 = call <4 x float> @llvm.evl.fsub.v4f32(<4 x float> %x, <4 x float> %y, <4 x i1> %M, i32 %L)
  %t2 = call <4 x float> @llvm.evl.fsub.v4f32(<4 x float> <float -0.0, float -0.0, float -0.0, float -0.0>, <4 x float> %t1, <4 x i1> %M, i32 %L)
  ret <4 x float> %t2
}

; Can't do anything with the test above because -0.0 - 0.0 = -0.0, but if we have nsz:
; -(X - Y) --> Y - X

; TODO predicated FAdd folding
define <4 x float> @neg_sub_nsz_evl(<4 x float> %x, <4 x float> %y, <4 x i1> %M, i32 %L) {
; CH***-LABEL: @neg_sub_nsz_evl(
;
  %t1 = call <4 x float> @llvm.evl.fsub.v4f32(<4 x float> %x, <4 x float> %y, <4 x i1> %M, i32 %L)
  %t2 = call nsz <4 x float> @llvm.evl.fsub.v4f32(<4 x float> <float -0.0, float -0.0, float -0.0, float -0.0>, <4 x float> %t1, <4 x i1> %M, i32 %L)
  ret <4 x float> %t2
}

; With nsz: Z - (X - Y) --> Z + (Y - X)

define <4 x float> @sub_sub_nsz_evl(<4 x float> %x, <4 x float> %y, <4 x float> %z, <4 x i1> %M, i32 %L) {
; CHECK-LABEL: @sub_sub_nsz_evl(
;  CHECK-NEXT:   %1 = call nsz <4 x float> @llvm.evl.fsub.v4f32(<4 x float> %y, <4 x float> %x, <4 x i1> %M, i32 %L)
;  CHECK-NEXT:   %t2 = call nsz <4 x float> @llvm.evl.fadd.v4f32(<4 x float> %z, <4 x float> %1, <4 x i1> %M, i32 %L)
;  CHECK-NEXT:   ret <4 x float> %t2
  %t1 = call <4 x float> @llvm.evl.fsub.v4f32(<4 x float> %x, <4 x float> %y, <4 x i1> %M, i32 %L)
  %t2 = call nsz <4 x float> @llvm.evl.fsub.v4f32(<4 x float> %z, <4 x float> %t1, <4 x i1> %M, i32 %L)
  ret <4 x float> %t2
}



; Function Attrs: nounwind readnone
declare <4 x float> @llvm.evl.fadd.v4f32(<4 x float>, <4 x float>, <4 x i1> mask, i32 vlen) #0

; Function Attrs: nounwind readnone
declare <4 x float> @llvm.evl.fsub.v4f32(<4 x float>, <4 x float>, <4 x i1> mask, i32 vlen) #0
