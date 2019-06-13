; RUN: llc < %s -mtriple=ve-unknown-unknown | FileCheck %s

; Function Attrs: nounwind
define void @vmulsl_vsvl(i64*, i64, i64*, i32) {
; CHECK: vmuls.l %v0,%s1,%v0
  %5 = icmp sgt i32 %3, 0
  br i1 %5, label %7, label %6

6:                                                ; preds = %7, %4
  ret void

7:                                                ; preds = %4, %7
  %8 = phi i64* [ %18, %7 ], [ %0, %4 ]
  %9 = phi i64* [ %19, %7 ], [ %2, %4 ]
  %10 = phi i32 [ %20, %7 ], [ 0, %4 ]
  %11 = sub nsw i32 %3, %10
  %12 = icmp slt i32 %11, 256
  %13 = select i1 %12, i32 %11, i32 256
  %14 = bitcast i64* %9 to i8*
  %15 = tail call <256 x double> @llvm.ve.vl.vld.vssl(i64 8, i8* %14, i32 %13)
  %16 = tail call <256 x double> @llvm.ve.vl.vmulsl.vsvl(i64 %1, <256 x double> %15, i32 %13)
  %17 = bitcast i64* %8 to i8*
  tail call void @llvm.ve.vl.vst.vssl(<256 x double> %16, i64 8, i8* %17, i32 %13)
  %18 = getelementptr inbounds i64, i64* %8, i64 256
  %19 = getelementptr inbounds i64, i64* %9, i64 256
  %20 = add nuw nsw i32 %10, 256
  %21 = icmp slt i32 %20, %3
  br i1 %21, label %7, label %6
}

; Function Attrs: nounwind readonly
declare <256 x double> @llvm.ve.vl.vld.vssl(i64, i8*, i32)

; Function Attrs: nounwind readnone
declare <256 x double> @llvm.ve.vl.vmulsl.vsvl(i64, <256 x double>, i32)

; Function Attrs: nounwind writeonly
declare void @llvm.ve.vl.vst.vssl(<256 x double>, i64, i8*, i32)

