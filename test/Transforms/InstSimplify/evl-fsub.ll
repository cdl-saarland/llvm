; RUN: opt < %s -instsimplify -S | FileCheck %s

define <8 x double> @fsub_fadd_fold_evl_xy(<8 x double> %x, <8 x double> %y, <8 x i1> %m, i32 %len) {
; CHECK-LABEL: fsub_fadd_fold_evl_xy
;  CHECK-NEXT:   ret <8 x double> %x
  %tmp = call reassoc nsz <8 x double> @llvm.evl.fadd.v8f64(<8 x double> %x, <8 x double> %y, <8 x i1> %m, i32 %len)
  %res = call reassoc nsz <8 x double> @llvm.evl.fsub.v8f64(<8 x double> %tmp, <8 x double> %y, <8 x i1> %m, i32 %len)
  ret <8 x double> %x
}

define <8 x double> @fsub_fadd_fold_evl_yx(<8 x double> %x, <8 x double> %y, <8 x i1> %m, i32 %len) {
; CHECK-LABEL: fsub_fadd_fold_evl_yx
;  CHECK-NEXT:   ret <8 x double> %x
  %tmp = call reassoc nsz <8 x double> @llvm.evl.fadd.v8f64(<8 x double> %y, <8 x double> %x, <8 x i1> %m, i32 %len)
  %res = call reassoc nsz <8 x double> @llvm.evl.fsub.v8f64(<8 x double> %tmp, <8 x double> %y, <8 x i1> %m, i32 %len)
  ret <8 x double> %x
}

define <8 x double> @fsub_fadd_fold_evl_yx_olen(<8 x double> %x, <8 x double> %y, <8 x i1> %m, i32 %len, i32 %otherLen) {
; CHECK-LABEL: fsub_fadd_fold_evl_yx_olen
;  CHECK-NEXT:   %tmp = call reassoc nsz <8 x double> @llvm.evl.fadd.v8f64(<8 x double> %y, <8 x double> %x, <8 x i1> %m, i32 %otherLen)
;  CHECK-NEXT:   %res = call reassoc nsz <8 x double> @llvm.evl.fsub.v8f64(<8 x double> %tmp, <8 x double> %y, <8 x i1> %m, i32 %len)
;  CHECK-NEXT:   ret <8 x double> %res
  %tmp = call reassoc nsz <8 x double> @llvm.evl.fadd.v8f64(<8 x double> %y, <8 x double> %x, <8 x i1> %m, i32 %otherLen)
  %res = call reassoc nsz <8 x double> @llvm.evl.fsub.v8f64(<8 x double> %tmp, <8 x double> %y, <8 x i1> %m, i32 %len)
  ret <8 x double> %res
}

define <8 x double> @fsub_fadd_fold_evl_yx_omask(<8 x double> %x, <8 x double> %y, <8 x i1> %m, i32 %len, <8 x i1> %othermask) {
; CHECK-LABEL: fsub_fadd_fold_evl_yx_omask
;  CHECK-NEXT:   %tmp = call reassoc nsz <8 x double> @llvm.evl.fadd.v8f64(<8 x double> %y, <8 x double> %x, <8 x i1> %m, i32 %len)
;  CHECK-NEXT:   %res = call reassoc nsz <8 x double> @llvm.evl.fsub.v8f64(<8 x double> %tmp, <8 x double> %y, <8 x i1> %othermask, i32 %len)
;  CHECK-NEXT:   ret <8 x double> %res
  %tmp = call reassoc nsz <8 x double> @llvm.evl.fadd.v8f64(<8 x double> %y, <8 x double> %x, <8 x i1> %m, i32 %len)
  %res = call reassoc nsz <8 x double> @llvm.evl.fsub.v8f64(<8 x double> %tmp, <8 x double> %y, <8 x i1> %othermask, i32 %len)
  ret <8 x double> %res
}

; Function Attrs: nounwind readnone
declare <8 x double> @llvm.evl.fadd.v8f64(<8 x double>, <8 x double>, <8 x i1> mask, i32 vlen) #0

; Function Attrs: nounwind readnone
declare <8 x double> @llvm.evl.fsub.v8f64(<8 x double>, <8 x double>, <8 x i1> mask, i32 vlen) #0
