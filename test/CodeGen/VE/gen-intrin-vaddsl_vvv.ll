; RUN: llc < %s -mtriple=ve-unknown-unknown | FileCheck %s

; Function Attrs: nounwind
define void @vaddsl_vvv(i64* %pvx, i64* %pvy, i64* %pvz, i32 %n) {
; CHECK-LABEL: vaddsl_vvv
; CHECK: .LBB0_2
; CHECK: 	vadds.l %v0,%v0,%v1
entry:
  %cmp18 = icmp sgt i32 %n, 0
  br i1 %cmp18, label %for.body, label %for.cond.cleanup

for.cond.cleanup:                                 ; preds = %for.body, %entry
  ret void

for.body:                                         ; preds = %entry, %for.body
  %pvx.addr.022 = phi i64* [ %add.ptr, %for.body ], [ %pvx, %entry ]
  %pvy.addr.021 = phi i64* [ %add.ptr3, %for.body ], [ %pvy, %entry ]
  %pvz.addr.020 = phi i64* [ %add.ptr4, %for.body ], [ %pvz, %entry ]
  %i.019 = phi i32 [ %add, %for.body ], [ 0, %entry ]
  %sub = sub nsw i32 %n, %i.019
  %cmp1 = icmp slt i32 %sub, 256
  %spec.select = select i1 %cmp1, i32 %sub, i32 256
  tail call void @llvm.ve.lvl(i32 %spec.select)
  %0 = bitcast i64* %pvy.addr.021 to i8*
  %1 = tail call <256 x double> @llvm.ve.vld.vss(i64 8, i8* %0)
  %2 = bitcast i64* %pvz.addr.020 to i8*
  %3 = tail call <256 x double> @llvm.ve.vld.vss(i64 8, i8* %2)
  %4 = tail call <256 x double> @llvm.ve.vaddsl.vvv(<256 x double> %1, <256 x double> %3)
  %5 = bitcast i64* %pvx.addr.022 to i8*
  tail call void @llvm.ve.vst.vss(<256 x double> %4, i64 8, i8* %5)
  %add.ptr = getelementptr inbounds i64, i64* %pvx.addr.022, i64 256
  %add.ptr3 = getelementptr inbounds i64, i64* %pvy.addr.021, i64 256
  %add.ptr4 = getelementptr inbounds i64, i64* %pvz.addr.020, i64 256
  %add = add nuw nsw i32 %i.019, 256
  %cmp = icmp slt i32 %add, %n
  br i1 %cmp, label %for.body, label %for.cond.cleanup
}

; Function Attrs: nounwind
declare void @llvm.ve.lvl(i32)

; Function Attrs: nounwind readonly
declare <256 x double> @llvm.ve.vld.vss(i64, i8*)

; Function Attrs: nounwind readnone
declare <256 x double> @llvm.ve.vaddsl.vvv(<256 x double>, <256 x double>)

; Function Attrs: nounwind writeonly
declare void @llvm.ve.vst.vss(<256 x double>, i64, i8*)

