; RUN: llc < %s -mtriple=ve-unknown-unknown | FileCheck %s
; ModuleID = 'gen/tests/vfmins_vvv.c'
source_filename = "gen/tests/vfmins_vvv.c"
target datalayout = "e-m:e-i64:64-n32:64-S64-v16384:64:64"
target triple = "ve"

; Function Attrs: nounwind
define dso_local void @vfmins_vvv(float* %pvx, float* %pvy, float* %pvz, i32 %n) local_unnamed_addr #0 {
; CHECK-LABEL: vfmins_vvv
; CHECK: .LBB0_2
; CHECK: 	vfmin.s %v0,%v0,%v1
entry:
  %cmp18 = icmp sgt i32 %n, 0
  br i1 %cmp18, label %for.body, label %for.cond.cleanup

for.cond.cleanup:                                 ; preds = %for.body, %entry
  ret void

for.body:                                         ; preds = %entry, %for.body
  %pvx.addr.022 = phi float* [ %add.ptr, %for.body ], [ %pvx, %entry ]
  %pvy.addr.021 = phi float* [ %add.ptr3, %for.body ], [ %pvy, %entry ]
  %pvz.addr.020 = phi float* [ %add.ptr4, %for.body ], [ %pvz, %entry ]
  %i.019 = phi i32 [ %add, %for.body ], [ 0, %entry ]
  %sub = sub nsw i32 %n, %i.019
  %cmp1 = icmp slt i32 %sub, 256
  %spec.select = select i1 %cmp1, i32 %sub, i32 256
  tail call void @llvm.ve.lvl(i32 %spec.select)
  %0 = bitcast float* %pvy.addr.021 to i8*
  %1 = tail call <256 x double> @llvm.ve.vldu.vss(i64 4, i8* %0)
  %2 = bitcast float* %pvz.addr.020 to i8*
  %3 = tail call <256 x double> @llvm.ve.vldu.vss(i64 4, i8* %2)
  %4 = tail call <256 x double> @llvm.ve.vfmins.vvv(<256 x double> %1, <256 x double> %3)
  %5 = bitcast float* %pvx.addr.022 to i8*
  tail call void @llvm.ve.vstu.vss(<256 x double> %4, i64 4, i8* %5)
  %add.ptr = getelementptr inbounds float, float* %pvx.addr.022, i64 256
  %add.ptr3 = getelementptr inbounds float, float* %pvy.addr.021, i64 256
  %add.ptr4 = getelementptr inbounds float, float* %pvz.addr.020, i64 256
  %add = add nuw nsw i32 %i.019, 256
  %cmp = icmp slt i32 %add, %n
  br i1 %cmp, label %for.body, label %for.cond.cleanup
}

; Function Attrs: nounwind
declare void @llvm.ve.lvl(i32) #1

; Function Attrs: nounwind readonly
declare <256 x double> @llvm.ve.vldu.vss(i64, i8*) #2

; Function Attrs: nounwind readnone
declare <256 x double> @llvm.ve.vfmins.vvv(<256 x double>, <256 x double>) #3

; Function Attrs: nounwind writeonly
declare void @llvm.ve.vstu.vss(<256 x double>, i64, i8*) #4

attributes #0 = { nounwind "correctly-rounded-divide-sqrt-fp-math"="false" "disable-tail-calls"="false" "less-precise-fpmad"="false" "no-frame-pointer-elim"="true" "no-frame-pointer-elim-non-leaf" "no-infs-fp-math"="false" "no-jump-tables"="false" "no-nans-fp-math"="false" "no-signed-zeros-fp-math"="false" "no-trapping-math"="false" "stack-protector-buffer-size"="8" "unsafe-fp-math"="false" "use-soft-float"="false" }
attributes #1 = { nounwind }
attributes #2 = { nounwind readonly }
attributes #3 = { nounwind readnone }
attributes #4 = { nounwind writeonly }

!llvm.module.flags = !{!0}
!llvm.ident = !{!1}

!0 = !{i32 1, !"wchar_size", i32 4}
!1 = !{!"clang version 7.0.0 (git@socsv218.svp.cl.nec.co.jp:ve-llvm/clang.git d326119e3a71593369edd97e642577b570bf7c32) (llvm/llvm.git 453ce7931582b8cea4ec8bb639e18532858e5f51)"}
