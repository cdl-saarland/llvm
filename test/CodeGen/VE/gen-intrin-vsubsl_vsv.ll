; RUN: llc < %s -mtriple=ve-unknown-unknown | FileCheck %s
; ModuleID = 'gen/tests/vsubsl_vsv.c'
source_filename = "gen/tests/vsubsl_vsv.c"
target datalayout = "e-m:e-i64:64-n32:64-S64-v16384:64:64"
target triple = "ve"

; Function Attrs: nounwind
define dso_local void @vsubsl_vsv(i64* %pvx, i64 %sy, i64* %pvz, i32 %n) local_unnamed_addr #0 {
; CHECK-LABEL: vsubsl_vsv
; CHECK: .LBB0_2
; CHECK: 	vsubs.l %v0,%s1,%v0
entry:
  %cmp15 = icmp sgt i32 %n, 0
  br i1 %cmp15, label %for.body, label %for.cond.cleanup

for.cond.cleanup:                                 ; preds = %for.body, %entry
  ret void

for.body:                                         ; preds = %entry, %for.body
  %pvx.addr.018 = phi i64* [ %add.ptr, %for.body ], [ %pvx, %entry ]
  %pvz.addr.017 = phi i64* [ %add.ptr3, %for.body ], [ %pvz, %entry ]
  %i.016 = phi i32 [ %add, %for.body ], [ 0, %entry ]
  %sub = sub nsw i32 %n, %i.016
  %cmp1 = icmp slt i32 %sub, 256
  %spec.select = select i1 %cmp1, i32 %sub, i32 256
  tail call void @llvm.ve.lvl(i32 %spec.select)
  %0 = bitcast i64* %pvz.addr.017 to i8*
  %1 = tail call <256 x double> @llvm.ve.vld.vss(i64 8, i8* %0)
  %2 = tail call <256 x double> @llvm.ve.vsubsl.vsv(i64 %sy, <256 x double> %1)
  %3 = bitcast i64* %pvx.addr.018 to i8*
  tail call void @llvm.ve.vst.vss(<256 x double> %2, i64 8, i8* %3)
  %add.ptr = getelementptr inbounds i64, i64* %pvx.addr.018, i64 256
  %add.ptr3 = getelementptr inbounds i64, i64* %pvz.addr.017, i64 256
  %add = add nuw nsw i32 %i.016, 256
  %cmp = icmp slt i32 %add, %n
  br i1 %cmp, label %for.body, label %for.cond.cleanup
}

; Function Attrs: nounwind
declare void @llvm.ve.lvl(i32) #1

; Function Attrs: nounwind readonly
declare <256 x double> @llvm.ve.vld.vss(i64, i8*) #2

; Function Attrs: nounwind readnone
declare <256 x double> @llvm.ve.vsubsl.vsv(i64, <256 x double>) #3

; Function Attrs: nounwind writeonly
declare void @llvm.ve.vst.vss(<256 x double>, i64, i8*) #4

attributes #0 = { nounwind "correctly-rounded-divide-sqrt-fp-math"="false" "disable-tail-calls"="false" "less-precise-fpmad"="false" "no-frame-pointer-elim"="true" "no-frame-pointer-elim-non-leaf" "no-infs-fp-math"="false" "no-jump-tables"="false" "no-nans-fp-math"="false" "no-signed-zeros-fp-math"="false" "no-trapping-math"="false" "stack-protector-buffer-size"="8" "unsafe-fp-math"="false" "use-soft-float"="false" }
attributes #1 = { nounwind }
attributes #2 = { nounwind readonly }
attributes #3 = { nounwind readnone }
attributes #4 = { nounwind writeonly }

!llvm.module.flags = !{!0}
!llvm.ident = !{!1}

!0 = !{i32 1, !"wchar_size", i32 4}
!1 = !{!"clang version 7.0.0 (git@socsv218.svp.cl.nec.co.jp:ve-llvm/clang.git d326119e3a71593369edd97e642577b570bf7c32) (llvm/llvm.git 453ce7931582b8cea4ec8bb639e18532858e5f51)"}
