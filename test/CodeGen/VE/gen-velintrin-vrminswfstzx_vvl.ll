; RUN: llc < %s -mtriple=ve-unknown-unknown | FileCheck %s

; Function Attrs: nounwind
define void @vrminswfstzx_vvl(i32*, i32*, i32) {
; CHECK: vrmins.w.fst.zx %v0,%v0
  %4 = icmp sgt i32 %2, 0
  br i1 %4, label %6, label %5

5:                                                ; preds = %6, %3
  ret void

6:                                                ; preds = %3, %6
  %7 = phi i32* [ %17, %6 ], [ %0, %3 ]
  %8 = phi i32* [ %18, %6 ], [ %1, %3 ]
  %9 = phi i32 [ %19, %6 ], [ 0, %3 ]
  %10 = sub nsw i32 %2, %9
  %11 = icmp slt i32 %10, 256
  %12 = select i1 %11, i32 %10, i32 256
  %13 = bitcast i32* %8 to i8*
  %14 = tail call <256 x double> @llvm.ve.vl.vldlsx.vssl(i64 4, i8* %13, i32 %12)
  %15 = tail call <256 x double> @llvm.ve.vl.vrminswfstzx.vvl(<256 x double> %14, i32 %12)
  %16 = bitcast i32* %7 to i8*
  tail call void @llvm.ve.vl.vstl.vssl(<256 x double> %15, i64 4, i8* %16, i32 %12)
  %17 = getelementptr inbounds i32, i32* %7, i64 256
  %18 = getelementptr inbounds i32, i32* %8, i64 256
  %19 = add nuw nsw i32 %9, 256
  %20 = icmp slt i32 %19, %2
  br i1 %20, label %6, label %5
}

; Function Attrs: nounwind readonly
declare <256 x double> @llvm.ve.vl.vldlsx.vssl(i64, i8*, i32)

; Function Attrs: nounwind readnone
declare <256 x double> @llvm.ve.vl.vrminswfstzx.vvl(<256 x double>, i32)

; Function Attrs: nounwind writeonly
declare void @llvm.ve.vl.vstl.vssl(<256 x double>, i64, i8*, i32)

