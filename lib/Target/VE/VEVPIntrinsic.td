// def : Pat<(int_ve_vstot_vss v256f64:$vx, i64:$sy, i64:$sz), (VSTotrr v256f64:$vx, i64:$sy, i64:$sz, (GetVL (i32 0)))>;

//TODO: many of those patterns would actually be better of using custom lowering!

// Helpers to disregard inputs.
//TODO: This should probably be solved differently!
class NOOP<dag outs, dag ins> : Instruction {
  let Namespace = "VE";
  let Size = 0;

  field bits<0> Inst;

  let OutOperandList = outs;
  let InOperandList = ins;
  let AsmString = ";";
  let Pattern = [];
}

def NOOPdm : NOOP<(outs V64:$out), (ins VMC:$m, V64:$in)> { let Constraints = "$out = $in"; }
def NOOPmi : NOOP<(outs VM:$out), (ins I32:$a, VM:$in)> { let Constraints = "$out = $in"; }
def NOOPmm : NOOP<(outs VM:$out), (ins VMC:$m, VM:$in)> { let Constraints = "$out = $in"; }

// Vector Load

//This must only be used when ROGUE=1 is set.
def : Pat<(v256i64 (vp_load i64:$addr, v256i1:$mask, i32:$avl)), (NOOPdm $mask, (VLDir 8, $addr, (COPY_TO_REGCLASS $avl, VLS)))>;
def : Pat<(v256f64 (vp_load i64:$addr, v256i1:$mask, i32:$avl)), (NOOPdm $mask, (VLDir 8, $addr, (COPY_TO_REGCLASS $avl, VLS)))>;

// Vector Store

def : Pat<(vp_store v256i64:$value, i64:$addr, v256i1:$mask, i32:$avl), (VSTirm $value, 8, $addr, $mask, (COPY_TO_REGCLASS $avl, VLS))>;
def : Pat<(vp_store v256f64:$value, i64:$addr, v256i1:$mask, i32:$avl), (VSTirm $value, 8, $addr, $mask, (COPY_TO_REGCLASS $avl, VLS))>;

// Arithmetic ops

def : Pat<(v256f64 (vp_fadd v256f64:$vx, v256f64:$vy, v256i1:$mask, i32:$avl)), (VFADdvm $vx, $vy, $mask, (v256f64 (IMPLICIT_DEF)), (COPY_TO_REGCLASS $avl, VLS))>;
def : Pat<(v256f64 (vp_fsub v256f64:$vx, v256f64:$vy, v256i1:$mask, i32:$avl)), (VFSBdvm $vx, $vy, $mask, (v256f64 (IMPLICIT_DEF)), (COPY_TO_REGCLASS $avl, VLS))>;
def : Pat<(v256f64 (vp_fmul v256f64:$vx, v256f64:$vy, v256i1:$mask, i32:$avl)), (VFMPdvm $vx, $vy, $mask, (v256f64 (IMPLICIT_DEF)), (COPY_TO_REGCLASS $avl, VLS))>;
def : Pat<(v256f64 (vp_fdiv v256f64:$vx, v256f64:$vy, v256i1:$mask, i32:$avl)), (VFDVdvm $vx, $vy, $mask, (v256f64 (IMPLICIT_DEF)), (COPY_TO_REGCLASS $avl, VLS))>;

def : Pat<(v256i64 (vp_add v256i64:$vx, v256i64:$vy, v256i1:$mask, i32:$avl)), (VADXlvm $vx, $vy, $mask, (v256i64 (IMPLICIT_DEF)), (COPY_TO_REGCLASS $avl, VLS))>;
def : Pat<(v256i64 (vp_sub v256i64:$vx, v256i64:$vy, v256i1:$mask, i32:$avl)), (VSBXlvm $vx, $vy, $mask, (v256i64 (IMPLICIT_DEF)), (COPY_TO_REGCLASS $avl, VLS))>;

// Logic ops

def : Pat<(v256i64 (vp_and v256i64:$vx, v256i64:$vy, v256i1:$mask, i32:$avl)), (VANDvm $vx, $vy, $mask, (v256i64 (IMPLICIT_DEF)), (COPY_TO_REGCLASS $avl, VLS))>;
def : Pat<(v256i64 (vp_or v256i64:$vx, v256i64:$vy, v256i1:$mask, i32:$avl)), (VORvm $vx, $vy, $mask, (v256i64 (IMPLICIT_DEF)), (COPY_TO_REGCLASS $avl, VLS))>;
def : Pat<(v256i64 (vp_xor v256i64:$vx, v256i64:$vy, v256i1:$mask, i32:$avl)), (VXORvm $vx, $vy, $mask, (v256i64 (IMPLICIT_DEF)), (COPY_TO_REGCLASS $avl, VLS))>;

def : Pat<(v256i1 (vp_and v256i1:$ma, v256i1:$mb, v256i1:$mask, i32:$avl)), (NOOPmi $avl, (NOOPmm $mask, (ANDM $ma, $mb)))>;
def : Pat<(v256i1 (vp_or v256i1:$ma, v256i1:$mb, v256i1:$mask, i32:$avl)), (NOOPmi $avl, (NOOPmm $mask, (ORM $ma, $mb)))>;
def : Pat<(v256i1 (vp_xor v256i1:$ma, v256i1:$mb, v256i1:$mask, i32:$avl)), (NOOPmi $avl, (NOOPmm $mask, (XORM $ma, $mb)))>;

// Shifts

def : Pat<(v256i64 (vp_srl v256i64:$val, v256i64:$n, v256i1:$mask, i32:$avl)), (VSRLvm $n, $val, $mask, (v256i64 (IMPLICIT_DEF)), (COPY_TO_REGCLASS $avl, VLS))>;
def : Pat<(v256i64 (vp_sra v256i64:$val, v256i64:$n, v256i1:$mask, i32:$avl)), (VSRAvm $n, $val, $mask, (v256i64 (IMPLICIT_DEF)), (COPY_TO_REGCLASS $avl, VLS))>;
def : Pat<(v256i64 (vp_shl v256i64:$val, v256i64:$n, v256i1:$mask, i32:$avl)), (VSLLvm $n, $val, $mask, (v256i64 (IMPLICIT_DEF)), (COPY_TO_REGCLASS $avl, VLS))>;
