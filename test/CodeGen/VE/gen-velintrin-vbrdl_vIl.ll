; RUN: llc < %s -mtriple=ve-unknown-unknown | FileCheck %s

; Function Attrs: nounwind writeonly
define void @vbrdl_vIl(i64*, i32) {
; CHECK: vbrd %v0,3
  %3 = icmp sgt i32 %1, 0
  br i1 %3, label %5, label %4

4:                                                ; preds = %5, %2
  ret void

5:                                                ; preds = %2, %5
  %6 = phi i64* [ %13, %5 ], [ %0, %2 ]
  %7 = phi i32 [ %14, %5 ], [ 0, %2 ]
  %8 = sub nsw i32 %1, %7
  %9 = icmp slt i32 %8, 256
  %10 = select i1 %9, i32 %8, i32 256
  %11 = tail call <256 x double> @llvm.ve.vl.vbrdl.vsl(i64 3, i32 %10)
  %12 = bitcast i64* %6 to i8*
  tail call void @llvm.ve.vl.vst.vssl(<256 x double> %11, i64 8, i8* %12, i32 %10)
  %13 = getelementptr inbounds i64, i64* %6, i64 256
  %14 = add nuw nsw i32 %7, 256
  %15 = icmp slt i32 %14, %1
  br i1 %15, label %5, label %4
}

; Function Attrs: nounwind readnone
declare <256 x double> @llvm.ve.vl.vbrdl.vsl(i64, i32)

; Function Attrs: nounwind writeonly
declare void @llvm.ve.vl.vst.vssl(<256 x double>, i64, i8*, i32)

