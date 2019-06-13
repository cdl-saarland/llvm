; RUN: llc < %s -mtriple=ve-unknown-unknown | FileCheck %s

; Function Attrs: nounwind
define void @vsumwsx_vvml(i32*, i32*, i32*, i32) {
; CHECK: vsum.w.sx %v0,%v0,%vm1
  %5 = icmp sgt i32 %3, 0
  br i1 %5, label %7, label %6

6:                                                ; preds = %7, %4
  ret void

7:                                                ; preds = %4, %7
  %8 = phi i32* [ %22, %7 ], [ %0, %4 ]
  %9 = phi i32* [ %23, %7 ], [ %1, %4 ]
  %10 = phi i32* [ %24, %7 ], [ %2, %4 ]
  %11 = phi i32 [ %25, %7 ], [ 0, %4 ]
  %12 = sub nsw i32 %3, %11
  %13 = icmp slt i32 %12, 256
  %14 = select i1 %13, i32 %12, i32 256
  %15 = bitcast i32* %9 to i8*
  %16 = tail call <256 x double> @llvm.ve.vl.vldlsx.vssl(i64 4, i8* %15, i32 %14)
  %17 = bitcast i32* %10 to i8*
  %18 = tail call <256 x double> @llvm.ve.vl.vldlzx.vssl(i64 4, i8* %17, i32 %14)
  %19 = tail call <4 x i64> @llvm.ve.vl.vfmkwgt.mvl(<256 x double> %18, i32 %14)
  %20 = bitcast i32* %8 to i8*
  %21 = tail call <256 x double> @llvm.ve.vl.vsumwsx.vvml(<256 x double> %16, <4 x i64> %19, i32 %14)
  tail call void @llvm.ve.vl.vstl.vssl(<256 x double> %21, i64 4, i8* %20, i32 %14)
  %22 = getelementptr inbounds i32, i32* %8, i64 256
  %23 = getelementptr inbounds i32, i32* %9, i64 256
  %24 = getelementptr inbounds i32, i32* %10, i64 256
  %25 = add nuw nsw i32 %11, 256
  %26 = icmp slt i32 %25, %3
  br i1 %26, label %7, label %6
}

; Function Attrs: nounwind readonly
declare <256 x double> @llvm.ve.vl.vldlsx.vssl(i64, i8*, i32)

; Function Attrs: nounwind readonly
declare <256 x double> @llvm.ve.vl.vldlzx.vssl(i64, i8*, i32)

; Function Attrs: nounwind readnone
declare <4 x i64> @llvm.ve.vl.vfmkwgt.mvl(<256 x double>, i32)

; Function Attrs: nounwind readnone
declare <256 x double> @llvm.ve.vl.vsumwsx.vvml(<256 x double>, <4 x i64>, i32)

; Function Attrs: nounwind writeonly
declare void @llvm.ve.vl.vstl.vssl(<256 x double>, i64, i8*, i32)

