#! /usr/bin/python

import re
import sys
from functools import partial

llvmIntrinsicPrefix = "ve"

class Type:
    def __init__(self, ValueType, builtinCode, intrinDefType, ctype, elemType = None):
        self.ValueType = ValueType  # v256f64, f64, f32, i64, ...
        self.builtinCode = builtinCode  # V256d, d, f, ...
        self.intrinDefType = intrinDefType
        self.ctype = ctype
        self.elemType = elemType

    def isVectorType(self):
        return self.elemType != None

    def stride(self):
        if self.isVectorType():
            t = self.elemType
            if t == T_f64 or t == T_i64 or t == T_u64:
                return 8
            else:
                return 4
        raise Exception("not a vector type")

T_f64     = Type("f64",     "d",      "LLVMType<f64>", "double")
T_f32     = Type("f32",     "f",      "LLVMType<f32>", "float")
T_i64     = Type("i64",     "Li",     "LLVMType<i64>", "long int")
T_i32     = Type("i32",     "i",      "LLVMType<i32>", "int", "I32")
T_u64     = Type("i64",     "LUi",    "LLVMType<i64>", "unsigned long int")
T_u32     = Type("i32",     "Ui",     "LLVMType<i32>", "unsigned int")
T_voidp   = Type("i64",     "v*",     "llvm_ptr_ty",   "void*", "I64")
T_voidcp   = Type("i64",    "vC*",    "llvm_ptr_ty",   "void const*")

T_v256f64 = Type("v256f64", "V256d",  "LLVMType<v256f64>", "double*", T_f64)
T_v256f32 = Type("v256f64", "V256d",  "LLVMType<v256f64>", "float*",  T_f32)
T_v256i64 = Type("v256f64", "V256d",  "LLVMType<v256f64>", "long int*", T_i64)
T_v256i32 = Type("v256f64", "V256d",  "LLVMType<v256f64>", "int*", T_i32)
T_v256u64 = Type("v256f64", "V256d",  "LLVMType<v256f64>", "unsigned long int*", T_u64)
T_v256u32 = Type("v256f64", "V256d",  "LLVMType<v256f64>", "unsigned int*", T_u32)

T_v4u64   = Type("v4i64",   "V4ULi",   "LLVMType<v4i64>", "unsigned int*", T_u64) # for VM
T_v8u64   = Type("v8i64",   "V8ULi",   "LLVMType<v8i64>", "unsigned int*", T_u64) # for VM512

#T_v8u32   = Type("v8i32",   "V8ULi",   "unsigned int*",  T_u32)
#T_v16u32  = Type("v16i32",  "V16ULi",  "unsigned int*",  T_u32)

class Op(object):
    def __init__(self, kind, ty, name, regClass):
        self.kind = kind
        self.ty_ = ty
        self.name_ = name
        self.regClass_ = regClass

    def regClass(self): return self.regClass_
    def intrinDefType(self): return self.ty_.intrinDefType
    def ValueType(self): return self.ty_.ValueType
    def builtinCode(self): return self.ty_.builtinCode
    def elemType(self): return self.ty_.elemType
    def ctype(self): return self.ty_.ctype
    def stride(self): return self.ty_.stride()

    def dagOp(self):
        if self.kind == 'I' or self.kind == 'Z':
            return "({} {}:${})".format(self.ty_.ValueType, self.immType, self.name_)
        elif self.kind == 'c':
            return "({} uimm6:${})".format(self.ty_.ValueType, self.name_)
        else:
            return "{}:${}".format(self.ty_.ValueType, self.name_)

    def isImm(self): return self.kind == 'I' or self.kind == 'N' or self.kind == "Z"
    def isReg(self): return self.kind == 'v' or self.kind == 's'
    def isSReg(self): return self.kind == 's' or self.kind == 'f'
    def isVReg(self): return self.kind == 'v'
    def isMask(self): return self.kind == 'm' or self.kind == 'M'
    def isMask256(self): return self.kind == 'm'
    def isMask512(self): return self.kind == 'M'
    def isCC(self): return self.kind == 'c'
    def isVL(self): return self.kind == 'l'

    def regName(self):
        return self.name_

    def formalName(self):
        if self.isVReg() or self.isMask():
            return "p" + self.name_
        else:
            return self.name_

    def VectorType(self):
        if self.isVReg():
            return "__vr"
        elif self.isMask512():
            return "__vm512"
        elif self.isMask():
            return "__vm"
        raise Exception("not a vector type: {}".format(self.kind))

def VOp(ty, name):
    if ty == T_f64: return Op("v", T_v256f64, name, "V64")
    elif ty == T_f32: return Op("v", T_v256f32, name, "V64")
    elif ty == T_i64: return Op("v", T_v256i64, name, "V64")
    elif ty == T_i32: return Op("v", T_v256i32, name, "V64")
    elif ty == T_u64: return Op("v", T_v256u64, name, "V64")
    elif ty == T_u32: return Op("v", T_v256u32, name, "V64")
    else: raise Exception("unknown type")

def SOp(ty, name):
    if ty in [T_f64, T_i64, T_u64, T_voidp, T_voidcp]: 
        return Op("s", ty, name, "I64")
    elif ty == T_f32: return Op("s", ty, name, "F32")
    elif ty == T_i32: return Op("s", ty, name, "I32")
    elif ty == T_u32: return Op("s", ty, name, "I32")
    else: raise Exception("unknown type: {}".format(ty.ValueType))

def SX(ty): return SOp(ty, "sx")
def SY(ty): return SOp(ty, "sy")
def SZ(ty): return SOp(ty, "sz")
def SW(ty): return SOp(ty, "sw")

def VX(ty): return VOp(ty, "vx")
def VY(ty): return VOp(ty, "vy")
def VZ(ty): return VOp(ty, "vz")
def VW(ty): return VOp(ty, "vw")
def VD(ty): return VOp(ty, "vd")

VL = Op("l", T_u32, "vl", "VLS")
VM = Op("m", T_v4u64, "vm", "VM")
VMX = Op("m", T_v4u64, "vmx", "VM")
VMY = Op("m", T_v4u64, "vmy", "VM")
VMZ = Op("m", T_v4u64, "vmz", "VM")
VMD = Op("m", T_v4u64, "vmd", "VM")
VM512 = Op("M", T_v8u64, "vm", "VM512")
VMX512 = Op("M", T_v8u64, "vmx", "VM512")
VMY512 = Op("M", T_v8u64, "vmy", "VM512")
VMZ512 = Op("M", T_v8u64, "vmz", "VM512")
VMD512 = Op("M", T_v8u64, "vmd", "VM512")
CCOp = Op("c", T_u32, "cc", "CCOp")

class ImmOp(Op):
    def __init__(self, kind, ty, name, immType):
        super(ImmOp, self).__init__(kind, ty, name, "simm7Op64") # FIXME: regClass
        self.immType = immType

def ImmI(ty): return ImmOp("I", ty, "I", "simm7") # kind, type, varname
def ImmN(ty): return ImmOp("I", ty, "N", "uimm6")
def UImm7(ty): return ImmOp("I", ty, "N", "uimm7")
def ImmZ(ty): return ImmOp("Z", ty, "Z", "simm7") # FIXME: simm7?

#class OL(list):
#    def __init__(self):
#        super(OL, self).__init__(self)
#
#    def __init__(self, l):
#        super(OL, self).__init__(self)
#        for i in l:
#            self.append(i)

def Args_vvv(ty): return [VX(ty), VY(ty), VZ(ty)]
def Args_vsv(tyV, tyS = None): 
    if tyS == None:
        tyS = tyV
    return [VX(tyV), SY(tyS), VZ(tyV)]
def Args_vIv(ty): return [VX(ty), ImmI(ty), VZ(ty)]

class DummyInst:
    def __init__(self, inst, func, asm):
        self.inst_ = inst
        self.asm_ = asm
        self.func_ = func
    def inst(self):
        return self.inst_
    def asm(self):
        return self.asm_
    def func(self):
        return self.func_
    def isDummy(self):
        return True
    def hasInst(self):
        return self.inst_ != None

# inst: instruction in the manual. VFAD
# opc: op code (8bit)
# asm: vfadd.$df, vfmk.$df.$cf, vst.$nc.$ot
# llvmInst: Instruction in VEInstrVec.td. VFADdv
# intrinsicName: function name without prefix
#   => _ve_{intrinsicName}, __builtin_ve_{intrinsicName}, int_ve_{intrinsicName}

# subcode: cx, cx2, ... (4bit)
# subname: d, s, nc, ot, ...

class Inst(object):
    def __init__(self, opc, inst, asm, intrinsicName, outs, ins, **kwargs):
        self.kwargs = kwargs
        self.opc = opc
        self.outs = outs
        self.ins = ins

        self.inst_ = inst
        self.llvmInst_ = kwargs['llvmInst']
        self.asm_ = asm
        self.intrinsicName_ = intrinsicName
        self.funcPrefix_ = "_ve_"
        self.llvmIntrinsicPrefix_ = "_ve_"

        self.hasTest_ = True
        self.prop_ = ["IntrNoMem"]
        self.hasBuiltin_ = True
        self.oldLowering_ = False
        self.hasMaskBaseReg_ = True
        self.hasPat_ = True
        self.hasLLVMInstDefine_ = True

    def inst(self): return self.inst_
    def llvmInst(self): return self.llvmInst_
    def intrinsicName(self): return self.intrinsicName_
    def asm(self): return self.asm_ if self.asm_ else ""
    def expr(self): return None if 'expr' not in self.kwargs else self.kwargs['expr']
    def funcName(self):
        return "{}{}".format(self.funcPrefix_, self.intrinsicName())
    def builtinName(self):
        return "__builtin{}{}".format(self.llvmIntrinsicPrefix_, self.intrinsicName())
    def llvmIntrinName(self):
        return "int{}{}".format(self.llvmIntrinsicPrefix_, self.intrinsicName())

    # difference among dummy and pseudo
    #   dummy: instructions to insert a entry into the manual
    #   pseudo:  instructions without opcode, ie: no machine instruction

    # predicates
    def isDummy(self): return False
    def isMasked(self): return any([op.regName() == "vm" for op in self.ins])
    def isPacked(self): return ('packed' in self.kwargs) and self.kwargs['packed']
    def isPseudo(self): return self.opc == None

    def noLLVMInstDefine(self): self.hasLLVMInstDefine_ = False
    def hasLLVMInstDefine(self): 
        return self.hasLLVMInstDefine_ and (not self.isDummy()) and (not self.isPseudo())

    def hasDummyOp(self): return any([op.regName() == "vd" for op in self.ins])
    def hasImmOp(self): return any([op.isImm() for op in self.ins])
    def hasVLOp(self): return any([op.isVL() for op in self.ins])

    def noBuiltin(self):
        self.hasBuiltin_ = False

    def hasMask(self):
        if len(self.outs) > 0 and self.outs[0].isMask():
            return True
        for op in self.ins:
            if op.isMask():
                return True
        return False

    def readMem(self):
        self.prop_ = ["IntrReadMem"]
        return self

    def writeMem(self):
        self.prop_ = ["IntrWriteMem"]
        return self

    def inaccessibleMemOrArgMemOnly(self):
        self.prop_ = ["IntrInaccessibleMemOrArgMemOnly"]
        return self

    def hasSideEffects(self):
        self.prop_ = ["IntrHasSideEffects"]

    def prop(self):
        return self.prop_

    def hasInst(self): return self.inst_ != None

    def hasBuiltin(self):
        return self.hasBuiltin_

    def instDefine(self):
        print("// {} {}".format(self.inst(), self.asm()))

        def fmtOps(ops):
            return ", ".join(["{}:${}".format(op.regClass(), op.regName()) for op in ops])

        outs = fmtOps(self.outs)
        ins = fmtOps(self.ins)
        tmp = [op for op in self.ins if op.regName() not in ["vd", "vl"]]
        ins2 = fmtOps(tmp)
        asmArgs = ",".join(["${}".format(op.regName()) for op in self.outs + tmp])

        instName = self.llvmInst()

        s = "def {} : RV<0x{:x}, (outs {}), (ins {}),\n".format(instName, self.opc, outs, ins)
        #s += "  : RV<0x{:x}, ({}), ({})\n".format(self.opc, outs, ins2)
        s += '       "{} {}",'.format(self.asm(), asmArgs) # asmstr
        s += " [], NoItinerary>\n" # pattern
        s += "{\n"
        if len(self.ins) > 2 and self.ins[1].kind == "s":
            s += '  let cs = 1;\n'
        if self.isPacked():
            s += '  let cx = 1;\n'
            s += '  let cx2 = 1;\n'
        if self.isMasked():
            s += '  bits<4> vm;\n'
            s += '  let m = vm;\n'
        if self.hasDummyOp():
            s += '  let Constraints = "${} = $vd";\n'.format(self.outs[0].regName())
        s += '  let DecoderNamespace = "VEL";\n'
        if self.hasVLOp():
            s += '  let DisableEncoding = "$vl";\n'
        s += "}\n"
        return s

    def pattern(self):
        s = None
        if self.hasInst()and self.hasPat():
            argsL = ", ".join([op.dagOp() for op in self.ins])
            argsR = ", ".join([op.dagOp() for op in self.ins])
            tmp = re.sub(r'[INZ]', 's', self.llvmIntrinName()) # replace Imm to s
            l = "({} {})".format(tmp, argsL)
            r = "({} {}, (GetVL (i32 0)))".format(self.llvmInst(), argsR)
            if self.isOldLowering() and (not self.hasMask()):
                s = "def : Pat<{}, {}>;".format(l, r)
        return s

    # to be included from IntrinsicsVE.td
    def intrinsicDefine(self):
        outs = ", ".join(["{}".format(op.intrinDefType()) for op in self.outs])
        ins = ", ".join(["{}".format(op.intrinDefType()) for op in self.ins])

        prop = ', '.join(self.prop())

        intrinName = "{}".format(self.llvmIntrinName())
        builtinName = "GCCBuiltin<\"{}\"".format(self.builtinName())

        return "let TargetPrefix = \"ve\" in def {} : {}>, Intrinsic<[{}], [{}], [{}]>;".format(intrinName, builtinName, outs, ins, prop)

    # to be included from BuiltinsVE.def
    def builtin(self):
        if len(self.outs) == 0:
            tmp = "v"
        else:
            tmp = "".join([i.builtinCode() for i in self.outs])
        tmp += "".join([i.builtinCode() for i in self.ins])
        return "BUILTIN({}, \"{}\", \"n\")".format(self.builtinName(), tmp)

    # to be included from veintrin.h
    def veintrin(self):
        return "#define {} {}".format(self.funcName(), self.builtinName())

    def noTest(self):
        self.hasTest_ = False
        return self

    def hasTest(self):
        return self.hasTest_

    def stride(self, op):
        if self.isPacked():
            return 8;
        else:
            return op.stride()

    def hasExpr(self): return self.expr() != None

    def oldLowering(self): self.oldLowering_ = True; return self
    def isOldLowering(self): return self.oldLowering_

    def noMaskBaseReg(self): self.hasMaskBaseReg_ = False; return self
    def hasMaskBaseReg(self): return self.hasMask() and self.hasMaskBaseReg_

    def noPat(self): self.hasPat_ = False
    def hasPat(self): return self.hasPat_

class InstVE(Inst):
    def __init__(self, opc, inst, asm, intrinsicName, outs, ins, **kwargs):
        super(InstVE, self).__init__(opc, inst, asm, intrinsicName, outs, ins, **kwargs)

class InstVEL(Inst):
    def __init__(self, opc, inst, asm, intrinsicName, outs, ins, **kwargs):
        # append dummyOp(pass through Op) and VL
        hasDummyOp = any([op.regName() == "vd" for op in ins])
        tmp = []
        if not hasDummyOp and len(outs) > 0 and outs[0].kind == "v":
            tmp.append(VD(outs[0].elemType()))
            intrinsicName += "v"
        ins = ins + tmp + [VL]
        intrinsicName += "l"

        if asm:
            suffix = "".join([op.kind for op in outs + ins])
            llvmInst = re.sub("\.", "", asm) + suffix
        else:
            llvmInst = None

        kwargs['llvmInst'] = llvmInst
        super(InstVEL, self).__init__(opc, inst, asm, intrinsicName, outs, ins, **kwargs)

        self.oldLowering_ = True
        self.funcPrefix_ = "_vel_"
        self.llvmIntrinsicPrefix_ = "_ve_vl_" # we have to start from "_ve_" in LLVM

    def pattern(self):
        s = None
        if self.hasInst()and self.hasPat():
            argsL = ", ".join([op.dagOp() for op in self.ins])
            argsR = ", ".join([op.dagOp() for op in self.ins])
            tmp = re.sub(r'[INZ]', 's', self.llvmIntrinName()) # replace Imm to s
            l = "({} {})".format(tmp, argsL)
            r = "({} {})".format(self.llvmInst(), argsR)
            if self.isOldLowering() and (not self.hasMask()):
                s = "def : Pat<{}, {}>;".format(l, r)
        return s


class TestFunc:
    def __init__(self, header, definition, ref):
        self.header_ = header
        self.definition_ = definition
        self.ref_ = ref

    def header(self):
        return self.header_

    def definition(self):
        return self.definition_

    def reference(self):
        return self.ref_

    def decl(self):
        return "extern {};".format(self.header_)

class TestGeneratorVMRG:
    def gen(self, I):

        p = {'type' : 'unsigned long int*',
             'stride' : 256, 'vm' : '__vm', 'vfmk' : '_ve_vfmkw_mcv',
             'vld' : '_ve_vldlzx_vss(4, pm)' }
        p['lvl'] = '_ve_lvl(n - i < 256 ? n - i : 256)'
        if I.ins[2].isMask512():
            p = {'type' : 'unsigned int*',
                 'stride': 512, 'vm' : '__vm512',
                 'vfmk' : '_ve_pvfmkw_Mcv', 'vld' : '_ve_vld_vss(8, pm)'}
            p['lvl'] = '_ve_lvl(n - i < 512 ? (n - i) / 2UL : 256)'

        header = "void {f}({ty} px, {ty} py, {ty} pz, unsigned int* pm, int n)".format(f=I.intrinsicName(), ty=p['type'])

        func = '''#include <veintrin.h>
{header}
{{
    for (int i = 0; i < n; i += {stride}) {{
        {lvl};
        __vr vy = _ve_vld_vss(8, py);
        __vr vz = _ve_vld_vss(8, pz);
        __vr tmp = {vld};
        {vm} vm = {vfmk}(VECC_G, tmp);
        __vr vx = _ve_{intrin}(vy, vz, vm);
        _ve_vst_vss(vx, 8, px);
        px += {stride};
        py += {stride};
        pz += {stride};
        pm += {stride};
    }}
}}'''.format(header=header, vm=p['vm'], vfmk=p['vfmk'], vld=p['vld'], stride=p['stride'], lvl=p['lvl'], intrin=I.intrinsicName())

        ref = '''{header}
{{
    for (int i = 0; i < n; ++i) {{
        px[i] = pm[i] > 0 ? pz[i] : py[i];
    }}
}}'''.format(header=header)

        return TestFunc(header, func, ref)

class TestGeneratorMask:
    def gen(self, I):
        intrinsicName = re.sub(r'[IN]', 's', I.intrinsicName())
        header = "void {}(unsigned long int* px, unsigned long int const* py, unsigned long int* pz, int n)".format(I.intrinsicName())

        args = ", ".join([op.regName() for op in I.ins])

        is512 = I.outs[0].isMask512()

        if (is512):
            vm = "__vm512"
            m = "M"
            l = 8
        else:
            vm = "__vm"
            m = "m"
            l = 4

        lvm = ""
        svm = ""
        for i in range(l):
            lvm += "    vmy = _ve_lvm_{m}{m}ss(vmy, {i}, py[{i}]);\n".format(m=m, i=i)
            lvm += "    vmz = _ve_lvm_{m}{m}ss(vmz, {i}, pz[{i}]);\n".format(m=m, i=i)
            svm += "    px[{i}] = _ve_svm_s{m}s(vmx, {i});\n".format(m=m, i=i)

        func = '''#include <veintrin.h>
{header}
{{
    {vm} vmx, vmy, vmz;
{lvm}
    vmx = _ve_{inst}({args});

{svm}
}}
'''.format(header=header, inst=intrinsicName, args=args, vm=vm, lvm=lvm, svm=svm)

        if I.hasExpr():
            args = ["px[i]", "py[i]", "pz[i]"]
            #line = I.expr.format(*[op.regName() for op in I.outs + I.ins])
            line = I.expr().format(*args)
            ref = '''{header}
{{
    for (int i = 0; i < {l}; ++i)
        {line};
}}
'''.format(header=header, line=line, l=l)
        else:
            ref = None

        return TestFunc(header, func, ref);

class TestGenerator:
    def funcHeader(self, I):
        tmp = [i for i in (I.outs + I.ins) if not i.isImm()]
        args = ["{} {}".format(i.ctype(), i.formalName()) for i in tmp]

        return "void {name}({args}, int n)".format(name=I.intrinsicName(), args=", ".join(args))

    def get_vld_vst_inst(self, I, op):
        vld = "vld_vss"
        vst = "vst_vss"
        if not I.isPacked():
            if op.elemType() == T_f32:
                vld = "vldu_vss"
                vst = "vstu_vss"
            elif op.elemType() == T_i32 or op.elemType() == T_u32:
                vld = "vldlsx_vss"
                vst = "vstl_vss"
        return [vld, vst]

    def test_(self, I):
        head = self.funcHeader(I)
    
        out = I.outs[0]
        body = ""
        indent = " " * 8
    
        #print(I.instName)
    
        if I.isPacked():
            #stride = 8
            step = 512
            body += indent + "int l = n - i < 512 ? (n - i) / 2UL : 256;\n"
        else:
            #stride = I.outs[0].ty.stride()
            step = 256
            body += indent + "int l = n - i < 256 ? n - i : 256;\n"
    
        body += indent + "_ve_lvl(l);\n"
    
        cond = "VECC_G"
    
        ins = I.ins
        if I.hasMask() and I.ins[-1].isVReg(): # remove vd when vm, vd
            ins = I.ins[0:-1]
    
        # input
        args = []
        for op in ins:
            if op.isVReg():
                stride = I.stride(op)
                vld, vst = self.get_vld_vst_inst(I, op)
                body += indent + "__vr {} = _ve_{}({}, p{});\n".format(op.regName(), vld, stride, op.regName())
            if op.isMask512():
                stride = I.stride(op)
                #vld, vst = self.get_vld_vst_inst(I, op)
                body += indent + "__vr {}0 = _ve_vld_vss({}, p{});\n".format(op.regName(), stride, op.regName())
                body += indent + "__vm512 {} = _ve_pvfmkw_Mcv({}, {}0);\n".format(op.regName(), cond, op.regName())
            elif op.isMask():
                stride = I.stride(op)
                #vld, vst = self.get_vld_vst_inst(I, op)
                body += indent + "__vr {}0 = _ve_vldlzx_vss(4, p{});\n".format(op.regName(), op.regName(), stride)
                body += indent + "__vm {} = _ve_vfmkw_mcv({}, {}0);\n".format(op.regName(), cond, op.regName())
            if op.isReg() or op.isMask():
                args.append(op.regName())
            elif op.isImm():
                args.append("3")
            elif op.isCC():
                args.append(op.name)

        intrinsicName = re.sub(r'[IN]', 's', I.intrinsicName())
    
        if I.hasMask():
            op = I.outs[0]
            vld, vst = self.get_vld_vst_inst(I, op)
            stride = I.stride(op)
            body += indent + "__vr {} = _ve_{}({}, p{});\n".format(op.regName(), vld, stride, op.regName())
            if I.hasMaskBaseReg():
                body += indent + "{} = _ve_{}({});\n".format(out.regName(), intrinsicName, ', '.join(args + [op.regName()]))
            else:
                body += indent + "{} = _ve_{}({});\n".format(out.regName(), intrinsicName, ', '.join(args))
        else:
            body += indent + "__vr {} = _ve_{}({});\n".format(out.regName(), intrinsicName, ', '.join(args))
    
        if out.isVReg():
            stride = I.stride(out)
            vld, vst = self.get_vld_vst_inst(I, out)
            body += indent + "_ve_{}({}, {}, {});\n".format(vst, out.regName(), stride, out.formalName())
    
        tmp = []
        for op in (I.outs + ins):
            if op.isVReg() or op.isMask():
                tmp.append(indent + "p{} += {};".format(op.regName(), "512" if I.isPacked() else "256"))
    
        body += "\n".join(tmp)
    
        func = '''#include "veintrin.h"
{} {{
    for (int i = 0; i < n; i += {}) {{
{}
    }}
}}
'''
        return func.format(head, step, body)
        
    def reference(self, I):
        if not I.hasExpr():
            return None

        head = self.funcHeader(I)

        tmp = []
        for op in I.outs + I.ins:
            if op.isVReg():
                tmp.append("p{}[i]".format(op.regName()))
            elif op.isReg():
                tmp.append(op.regName())
            elif op.isImm():
                tmp.append("3")

        body = I.expr().format(*tmp) + ";"

        preprocess = ''
        for op in I.ins:
            if op.isSReg():
                if I.isPacked():
                    ctype = I.outs[0].elemType().ctype
                    preprocess = '{} sy0 = *({}*)&sy;'.format(ctype, ctype)
                    body = re.sub('sy', "sy0", body)

        if I.hasMask():
            body = "if (pvm[i] > 0) {{ {} }}".format(body)

        func = '''{}
{{
    {}
    for (int i = 0; i < n; ++i) {{
        {}
    }}
}}'''

        return func.format(head, preprocess, body);

    def gen(self, I):
        return TestFunc(self.funcHeader(I), self.test_(I), self.reference(I));

def getTestGenerator(I):
    if (I.inst() == 'VMRG'):
        return TestGeneratorVMRG()
    if len(I.outs) > 0 and I.outs[0].isMask():
        return TestGeneratorMask()
    return TestGenerator()

class ManualInstPrinter:
    def __init__(self):
        pass

    def printAll(self, insts):
        for i in insts:
            self.printI(i)

    def make(self, I):
        v = []

        outType = "void"
        if len(I.outs) > 0:
            out = I.outs[0]
            if out.isVReg():
                outType = "__vr"
                v.append("{}[:]".format(out.regName()))
            elif out.isMask512():
                outType = "__vm512"
                v.append("{}[:]".format(out.regName()))
            elif out.isMask():
                outType = "__vm256"
                v.append("{}[:]".format(out.regName()))
            elif out.isSReg():
                outType = out.ctype()
            else:
                raise Exception("unknown output operand type: {}".format(out.kind))
                #v.append(out.regName())

        ins = []
        for op in I.ins:
            if op.isVReg():
                ins.append("__vr " + op.regName())
                v.append("{}[:]".format(op.regName()))
            elif op.isSReg():
                ins.append("{} {}".format(op.ctype(), op.regName()))
                v.append("{}".format(op.regName()))
            elif op.isMask512():
                ins.append("__vm512 {}".format(op.regName()))
                v.append("{}[:]".format(op.regName()))
            elif op.isMask():
                ins.append("__vm256 {}".format(op.regName()))
                v.append("{}[:]".format(op.regName()))
            elif op.isImm():
                ins.append("{} {}".format(op.ctype(), op.regName()))
                v.append("{}".format(op.regName()))
            elif op.isCC():
                ins.append("int cc".format(op.ctype()))
            elif op.isVL():
                ins.append("int vl".format(op.ctype()))
            else:
                raise Exception("unknown register kind: {}".format(op.kind))
        
        funcName = re.sub(r'[IN]', 's', I.funcName())
        func = "{} {}({})".format(outType, funcName, ", ".join(ins))

        #if outType:
        #    func = "{} _ve_{}({})".format(outType, intrinsicName, ", ".join(ins))
        #else:
        #    func = "_ve_{}({})".format(intrinsicName, ", ".join(ins))

        if I.hasExpr():
            if I.hasMask():
                expr = I.expr().format(*v)
                expr = re.sub(r'.*= ', '', expr)
                expr = "{} = {} ? {} : {}".format(v[0], v[-2], expr, v[-1])
            else:
                expr = I.expr().format(*v)
        else:
            expr = ""
        return [func, expr]

    def printI(self, I):
        if not I.hasExpr():
            return

        func, expr = self.make(I)
        line = "    {:<80} // {}".format(func, expr)
        print line

class HtmlManualPrinter(ManualInstPrinter):
    def printAll(self, T, opt_no_link):
        idx = 0
        for s in T.sections:
            print("<a href=\"#sec{}\">{}</a><br>".format(idx, s.name))
            idx += 1
        idx = 0
        for s in T.sections:
            rowspan = {}
            tmp = []
            for I in s.instsWithDummy():
                if I.isDummy():
                    func = I.func()
                    expr = ""
                else:
                    func, expr = self.make(I)
                inst = I.inst() if I.hasInst() else ""
                inst = re.sub(r'i64|i32|f64|f32', '', inst)
                #print("inst={}".format(inst))
                if inst in rowspan:
                    rowspan[inst] += 1
                else:
                    rowspan[inst] = 1
                if opt_no_link:
                    asm = "{}".format(I.asm())
                else:
                    asm = "<a href=\"Aurora-as-manual-v3.2.pdf#page={}\">{}</a>".format(s.page, I.asm())
                #tmp.append([inst, func, I.asm(), expr])
                tmp.append([inst, func, asm, expr])

            print("<h3><a name=\"sec{}\">{}</a></h3>".format(idx, s.name))
            print("<table border=1>")
            print("<tr><th>Instruction</th><th>Function</th><th>asm</th><th>Description</th></tr>")
            row = 0
            for a in tmp:
                inst = a.pop(0)
                print("<tr>")
                if row == 0:
                    row = rowspan[inst]
                    print("<td rowspan={}>{}</td>".format(row, inst))
                row -= 1
                print("<td>{}</td><td>{}</td><td>{}</td></tr>".format(*a))
            print("</table>")
            idx += 1

class InstList:
    def __init__(self, clazz):
        self.a = []
        self.clazz = clazz
    def add(self, I):
        self.a.append(I)
        return self
    def Inst(self, opc, inst, ni, asm, intrinsicName, outs, ins, **kwargs):
        I = self.clazz(opc, inst, ni, asm, intrinsicName, outs, ins, **kwargs)
        self.add(I)
        return I
    def __iter__(self):
        return self.a.__iter__()
    def __getattr__(self, attrname):
        def _method_missing(self, name, *args):
            for i in self.a:
                getattr(i, name)(*args)
            return self
        return partial(_method_missing, self, attrname)

class Section:
    def __init__(self, name, page):
        self.name = name
        self.page = page
        self.a = []
    def add(self, i):
        self.a.append(i)
    def insts(self):
        return [i for i in self.a if not i.isDummy()]
    def instsWithDummy(self):
        return self.a

class InstTable:
    def __init__(self, InstClass):
        self.currentSection = []
        self.sections = []
        self.clazz = InstClass

    def Section(self, name, page):
        s = Section(name, page)
        self.sections.append(s)
        self.currentSection = s

    def insts(self):
        a = []
        for s in self.sections:
            a.extend(s.insts())
        return a

    def add(self, inst):
        self.currentSection.add(inst)
        return inst

    def addList(self, L):
        for I in L:
            self.add(I)
        return L

    #def Inst(self, *args):
    #    return self.add(Inst(*args))

    def args_to_func_suffix(self, args):
        return "_" + "".join([op.kind for op in args if op])

    def args_to_inst_suffix(self, args):
        tbl = {
               "v"    : "v",
               "ss"   : "", # PFCHV
               "Is"   : "", # PFCHV
               "vv"   : "v",
               "vs"   : "r",
               "vI"   : "i",
               #"vN"   : "i",
               "vsmv" : "rm",
               "vsMv" : "rm",
               "vImv" : "im",
               "vIMv" : "im",
               #"vNmv" : "im",
               #"vNMv" : "im",
               "vvv"  : "v",
               "vvvmv": "vm",
               "vvvMv": "vm",
               "vvsMv": "rm2",
               "vvs"  : "r2",
               "vss"  : "rr",  # VLD
               "vIs"  : "ir",  # VLD
               "vsZ"  : "rz",  # VLD
               "vIZ"  : "iz",  # VLD
               "vvsmv": "rm2",
               "vvI"  : "i2",
               "vvImv": "im2",
               "vvss" : "r", # LSV
               "vvssmv" : "rm", # VSFA
               "svs"  : "r", # LVS
               #"vvN"  : "i2",
               "vsv"  : "r",
               "vsvmv": "rm",
               "vsvMv": "rm",
               "vIv"  : "i",
               "vIvmv": "im",
               "vvvv" : "v",
               "vsvv" : "r",
               "vvsv" : "r2",
               "vIvv" : "i",
               "vvIv" : "i2",
               "vvvvmv" : "vm",
               "vsvvmv" : "rm",
               "vvsvmv" : "r2m",
               "vIvvmv" : "im",
               "vvIvmv" : "i2m",
               "mmm" : "",
               "MMM" : "",
               "mm" : "",
               "MM" : "",
               "sms" : "",
               "smI" : "",
               "sMI" : "",
               "mmss" : "",
               "mmIs" : "",
               "MMIs" : "",
               "vvvm" : "v",
               "vvvM" : "v",
               "vvvs" : "r", # VSHF
               "vvvI" : "i", # VSHF

               "m"    : "", # VFMK at, af
               "M"    : "", # VFMKp at, af
               "mcv"  : "v",
               "mcvm" : "vm",
               "Mcv"  : "v",
               "McvM" : "vm",
               "vvIs" : "i", # VSFA
               "vvIsmv" : "im", # VSFA
               "sm"   : "", # PCMV, etc
               "sM"   : "", # PCMV, etc
               "vvmv" : "vm", # VCP, VEX
               "vvMv" : "vm", # VFIXp
               "vvm"  : "vm", # VGT, VSC

               "vvvvMv" : "vm", # VFMAD, etc
               "vsvvMv" : "rm", # VFMAD, etc
               "vvsvMv" : "r2m", # VFMAD, etc
               }

        tmp = "".join([op.kind for op in args if op])
        return tbl[tmp]

    def Dummy(self, inst, func, asm):
        self.add(DummyInst(inst, func, asm))

    def NoImpl(self, inst):
        self.add(DummyInst(inst, "not yet implemented", ""))

    # intrinsic name is generated from asm and arguments
    def InstX(self, opc, baseLLVMInst, asm, ary, expr = None, **kwargs):
        inst = re.sub(r'[a-z]*', '', baseLLVMInst) if baseLLVMInst else None
        isPacked = asm[0] == 'p'
        baseIntrinName = re.sub(r'\.', '', asm)
        if opc == None: # pseudo
            asm = ""
        IL = InstList(self.clazz)
        for args in ary:
            llvmInst = baseLLVMInst + self.args_to_inst_suffix(args) if baseLLVMInst else None
            intrinsicName = baseIntrinName + self.args_to_func_suffix(args)
            outs = [args[0]] if args[0] else []
            ins = args[1:]
            kwargs['packed'] = isPacked
            kwargs['expr'] = expr
            kwargs['llvmInst'] = llvmInst
            i = self.clazz(opc, inst, asm, intrinsicName, outs, ins, **kwargs)
            self.add(i)
            IL.add(i)
        return IL

    def InstXM(self, opc, baseInstName, asm, OL, expr = None):
        vm = VM512 if asm[0] == 'p' else VM
        OL = self.addMask(OL, vm)
        return self.InstX(opc, baseInstName, asm, OL, expr)

    def addMask(self, ary, MaskOp = VM):
        tmp = []
        for a in ary:
            tmp.append(a + [MaskOp, VD(a[0].elemType())])
        return ary + tmp

    def VLDm(self, opc, inst, asm):
        O = []
        O.append([VX(T_u64), SY(T_u64), SZ(T_voidcp)])
        O.append([VX(T_u64), ImmI(T_u64), SZ(T_voidcp)])
        #O.append([VX(T_u64), SY(T_u64), ImmZ(T_voidcp)])
        #O.append([VX(T_u64), ImmI(T_u64), ImmZ(T_voidcp)])

        return self.InstX(opc, inst, asm, O).noTest().readMem()

    def VSTm(self, opc, inst, asm):
        O_rr = [None, VX(T_u64), SY(T_u64), SZ(T_voidp)]
        O_ir = [None, VX(T_u64), ImmI(T_u64), SZ(T_voidp)]
        self.InstX(opc, inst, asm, [O_rr, O_ir]).noTest().writeMem()
        self.InstX(opc, inst+"ot", asm+".ot", [O_rr, O_ir]).oldLowering().noTest().writeMem()

        return
        O_rr = [VX(T_u64), SY(T_u64), SZ(T_voidp)]
        O_ir = [VX(T_u64), ImmI(T_u64), SZ(T_voidp)]
        L = InstList(self.clazz)
        L.Inst(opc, inst, inst+"rr", asm, asm+"_vss", [], O_rr)
        L.Inst(opc, inst, inst+"ir", asm, asm+"_vss", [], O_ir)
        L.Inst(opc, inst, inst+"otrr", asm+".ot", asm+"ot_vss", [], O_rr).oldLowering()
        L.Inst(opc, inst, inst+"otrr", asm+".ot", asm+"ot_vss", [], O_ir).oldLowering()
        #L.Inst(opc, inst+"rz", asm, asm, [], [VX(T_u64), SY(T_u64), ImmZ(T_voidp)])
        #L.Inst(opc, inst+"iz", asm, asm, [], [VX(T_u64), ImmI(T_u64), ImmZ(T_voidp)])
        self.addList(L).noTest().writeMem()

    def VBRDm(self, opc):
        expr = "{0} = {1}"
        I = self.clazz
        self.add(I(0x8C, "VBRD", "vbrd",  "vbrd_vs_f64",    [VX(T_f64)], [SY(T_f64)], expr=expr, llvmInst="VBRDf64r")).noLLVMInstDefine()
        self.add(I(0x8C, "VBRD", "vbrd",  "vbrd_vsmv_f64",  [VX(T_f64)], [SY(T_f64), VM, VD(T_f64)], expr=expr, llvmInst="VBRDf64rm")).noLLVMInstDefine()
        self.add(I(0x8C, "VBRD", "vbrd",  "vbrd_vs_i64",    [VX(T_i64)], [SY(T_i64)], expr=expr, llvmInst="VBRDr"))
        self.add(I(0x8C, "VBRD", "vbrd",  "vbrd_vsmv_i64",  [VX(T_i64)], [SY(T_i64), VM, VD(T_i64)], expr=expr, llvmInst="VBRDrm"))
        self.add(I(0x8C, "VBRD", "vbrd",  "vbrd_vI_i64",    [VX(T_i64)], [ImmI(T_i64)], expr=expr, llvmInst="VBRDi"))
        self.add(I(0x8C, "VBRD", "vbrd",  "vbrd_vImv_i64",  [VX(T_i64)], [ImmI(T_i64), VM, VD(T_i64)], expr=expr, llvmInst="VBRDim"))
        self.add(I(0x8C, "VBRD", "vbrdu", "vbrdu_vs_f32",   [VX(T_f32)], [SY(T_f32)], expr=expr, llvmInst="VBRDf32r"))
        self.add(I(0x8C, "VBRD", "vbrdu", "vbrdu_vsmv_f32", [VX(T_f32)], [SY(T_f32), VM, VD(T_f32)], expr=expr, llvmInst="VBRDf32rm"))
        self.add(I(0x8C, "VBRD", "vbrdl", "vbrdl_vs_i32",   [VX(T_i32)], [SY(T_i32)], expr=expr, llvmInst="VBRDi32r"))
        self.add(I(0x8C, "VBRD", "vbrdl", "vbrdl_vsmv_i32", [VX(T_i32)], [SY(T_i32), VM, VD(T_i32)], expr=expr, llvmInst="VBRDi32rm"))
        self.add(I(0x8C, "VBRD", "vbrdl", "vbrdl_vI_i32",   [VX(T_i32)], [ImmI(T_i32)], expr=expr, llvmInst="VBRDi32i"))
        self.add(I(0x8C, "VBRD", "vbrdl", "vbrdl_vImv_i32", [VX(T_i32)], [ImmI(T_i32), VM, VD(T_i32)], expr=expr, llvmInst="VBRDi32im"))
        self.add(I(0x8C, "VBRD", "pvbrd", "pvbrd_vs_i64",   [VX(T_u32)], [SY(T_u64)], packed=True, expr=expr, llvmInst="VBRDp"))
        self.add(I(0x8C, "VBRD", "pvbrd", "pvbrd_vsMv_i64", [VX(T_u32)], [SY(T_u64), VM512, VD(T_u32)], packed=True, expr=expr, llvmInst="VBRDpm"))

    def LVSm(self, opc):
        I = self.clazz
        self.add(I(opc, "LVS", "lvs", "lvs_svs_u64", [SX(T_u64)], [VX(T_u64), SY(T_u32)], llvmInst="LVSi64r").noTest())
        self.add(I(opc, "LVS", "lvs", "lvs_svs_f64", [SX(T_f64)], [VX(T_u64), SY(T_u32)], llvmInst="LVSf64r").noTest()).noLLVMInstDefine()
        self.add(I(opc, "LVS", "lvs", "lvs_svs_f32", [SX(T_f32)], [VX(T_u64), SY(T_u32)], llvmInst="LVSf32r").noTest()).noLLVMInstDefine() # FIXME

    def Inst2f(self, opc, name, instName, expr, hasPacked = True):
        self.InstX(opc, instName+"d", name+".d", [[VX(T_f64), VY(T_f64)]], expr)
        self.InstX(opc, instName+"s", name+".s", [[VX(T_f32), VY(T_f32)]], expr)
        if hasPacked:
            self.InstX(opc, instName+"p", "p"+name, [[VX(T_f32), VY(T_f32)]], expr) 

    def Inst3f(self, opc, name, instName, expr, hasPacked = True):
        O_f64 = [Args_vvv(T_f64), Args_vsv(T_f64)]
        O_f32 = [Args_vvv(T_f32), Args_vsv(T_f32)]
        O_pf32 = [Args_vvv(T_f32), [VX(T_f32), SY(T_u64), VZ(T_f32)]]

        O_f64 = self.addMask(O_f64)
        O_f32 = self.addMask(O_f32)
        O_pf32 = self.addMask(O_pf32, VM512)

        self.InstX(opc, instName+"d", name+".d", O_f64, expr)
        self.InstX(opc, instName+"s", name+".s", O_f32, expr)
        if hasPacked:
            self.InstX(opc, instName+"p", "p"+name, O_pf32, expr) 

    # 3 operands, u64/u32
    def Inst3u(self, opc, name, instName, expr, hasPacked = True):
        O_u64 = [Args_vvv(T_u64), Args_vsv(T_u64), Args_vIv(T_u64)]
        O_u32 = [Args_vvv(T_u32), Args_vsv(T_u32), Args_vIv(T_u32)]
        O_pu32 = [Args_vvv(T_u32), [VX(T_u32), SY(T_u64), VZ(T_u32)]]

        O_u64 = self.addMask(O_u64)
        O_u32 = self.addMask(O_u32)
        O_pu32 = self.addMask(O_pu32, VM512)

        self.InstX(opc, instName+"l", name+".l", O_u64, expr)
        self.InstX(opc, instName+"w", name+".w", O_u32, expr)
        if hasPacked:
            self.InstX(opc, instName+"p", "p"+name, O_pu32, expr)

    # 3 operands, i64
    def Inst3l(self, opc, name, instName, expr):
        O = [Args_vvv(T_i64), Args_vsv(T_i64), Args_vIv(T_i64)]
        O = self.addMask(O)
        self.InstX(opc, instName+"l", name+".l", O, expr)

    # 3 operands, i32
    def Inst3w(self, opc, name, instName, expr, hasPacked = True):
        O_i32 = [Args_vvv(T_i32), Args_vsv(T_i32), Args_vIv(T_i32)]
        O_pi32 = [Args_vvv(T_i32), [VX(T_i32), SY(T_u64), VZ(T_i32)]]

        O_i32 = self.addMask(O_i32)
        O_pi32 = self.addMask(O_pi32, VM512)

        self.InstX(opc, instName+"wsx", name+".w.sx", O_i32, expr)
        self.InstX(opc, instName+"wzx", name+".w.zx", O_i32, expr)
        if hasPacked:
            self.InstX(opc, instName+"p", "p"+name, O_pi32, expr)

    def Inst3divbys(self, opc, name, instName, ty):
        O_s = [VX(ty), VY(ty), SY(ty)]
        O_i = [VX(ty), VY(ty), ImmI(ty)]
        O = [O_s, O_i]
        O = self.addMask(O)
        self.InstX(opc, instName, name, O, "{0} = {1} / {2}")

    def Logical(self, opc, name, instName, expr):
        O_u32_vsv = [VX(T_u32), SY(T_u64), VZ(T_u32)]

        Args = [Args_vvv(T_u64), Args_vsv(T_u64)]
        Args = self.addMask(Args)

        ArgsP = [Args_vvv(T_u32), O_u32_vsv]
        ArgsP = self.addMask(ArgsP, VM512)

        self.InstX(opc, instName, name, Args, expr)
        self.InstX(opc, instName+"p", "p"+name, ArgsP, expr)

    def Shift(self, opc, name, instName, ty, expr):
        O_vvv = [VX(ty), VZ(ty), VY(T_u64)]
        O_vvs = [VX(ty), VZ(ty), SY(T_u64)]
        O_vvN = [VX(ty), VZ(ty), ImmN(T_u64)]

        OL = [O_vvv, O_vvs, O_vvN]
        OL = self.addMask(OL);

        self.InstX(opc, instName, name, OL, expr)

    def ShiftPacked(self, opc, name, instName, ty, expr):
        O_vvv = [VX(ty), VZ(ty), VY(T_u32)]
        O_vvs = [VX(ty), VZ(ty), SY(T_u64)]

        OL = [O_vvv, O_vvs]
        OL = self.addMask(OL, VM512)

        self.InstX(opc, instName+"p", "p"+name, OL, expr)

    def Inst4f(self, opc, name, instName, expr):
        O_f64_vvvv = [VX(T_f64), VY(T_f64), VZ(T_f64), VW(T_f64)]
        O_f64_vsvv = [VX(T_f64), SY(T_f64), VZ(T_f64), VW(T_f64)]
        O_f64_vvsv = [VX(T_f64), VY(T_f64), SY(T_f64), VW(T_f64)]

        O_f32_vvvv = [VX(T_f32), VY(T_f32), VZ(T_f32), VW(T_f32)]
        O_f32_vsvv = [VX(T_f32), SY(T_f32), VZ(T_f32), VW(T_f32)]
        O_f32_vvsv = [VX(T_f32), VY(T_f32), SY(T_f32), VW(T_f32)]

        O_pf32_vsvv = [VX(T_f32), SY(T_u64), VZ(T_f32), VW(T_f32)]
        O_pf32_vvsv = [VX(T_f32), VY(T_f32), SY(T_u64), VW(T_f32)]

        O_f64 = [O_f64_vvvv, O_f64_vsvv, O_f64_vvsv]
        O_f32 = [O_f32_vvvv, O_f32_vsvv, O_f32_vvsv]
        O_pf32 = [O_f32_vvvv, O_pf32_vsvv, O_pf32_vvsv]

        O_f64 = self.addMask(O_f64)
        O_f32 = self.addMask(O_f32)
        O_pf32 = self.addMask(O_pf32, VM512)

        self.InstX(opc, instName+"d", name+".d", O_f64, expr)
        self.InstX(opc, instName+"s", name+".s", O_f32, expr)
        self.InstX(opc, instName+"p", "p"+name, O_pf32, expr)

    def FLm(self, opc, inst, asm, args):
        self.InstX(opc, inst.format(fl="f"), asm.format(fl=".fst"), args)
        self.InstX(opc, inst.format(fl="l"), asm.format(fl=".lst"), args).noTest()

    def VFMKm(self, opc, inst, asm):
        self.InstX(opc, inst, asm, [[VM, CCOp, VZ(T_i64)]]).noTest()
        self.InstX(opc, inst, asm, [[VMX, CCOp, VZ(T_i64), VM]]).noTest()

    def VGTm(self, opc, inst, asm):
        O_v = [VX(T_u64), VY(T_u64)]
        O_vm = [VX(T_u64), VY(T_u64), VM]
        O = [O_v, O_vm]
        self.InstX(opc, inst, asm, O).noTest().readMem()

    def VSCm(self, opc, inst0, inst, asm):
        O_v = [None, VX(T_u64), VY(T_u64)]
        O_vm = [None, VX(T_u64), VY(T_u64), VM]
        #O_s = [VX(T_u64), SW(T_u64)]
        O = [O_v, O_vm]
        self.InstX(opc, inst0, asm, O).noTest().writeMem()
        self.InstX(opc, inst0+"ot", asm+".ot", O).noTest().writeMem().oldLowering()
        return

        O_v = [VX(T_u64), VY(T_u64)]
        O_vm = [VX(T_u64), VY(T_u64), VM]
        #O_s = [VX(T_u64), SW(T_u64)]
        O = [O_v, O_vm]

        baseIntrinName = re.sub(r'\.', '', asm)

        L = InstList(self.clazz)
        for op in O:
            si = self.args_to_inst_suffix(op)
            sf = self.args_to_func_suffix(op)
            L.Inst(opc, inst0, inst+si, asm, baseIntrinName+sf, [], op).noTest().writeMem()
            #self.add(Inst(opc, inst+si, asm, baseIntrinName+sf, [], op, False).noTest().writeMem()

        return self.addList(L)

    def VSUM(self, opc, inst, asm, baseOps):
        OL = []
        for op in baseOps:
            OL.append(op)
            OL.append(op + [VM])
        self.InstX(opc, inst, asm, OL).noMaskBaseReg()

    def VFIX(self, opc, inst, asm, OL, ty):
        expr = "{0} = (" + ty + ")({1}+0.5)"
        self.InstXM(opc, inst, asm, OL, expr)
        expr = "{0} = (" + ty + ")({1})"
        self.InstXM(opc, inst + "rz", asm+".rz", OL, expr)

def cmpwrite(filename, data):
    need_write = True
    try:
        with open(filename, "r") as f:
            old = f.read()
            need_write = old != data
    except:
        pass
    if need_write:
        print("write " + filename)
        with open(filename, "w") as f:
            f.write(data)

def gen_test(insts, directory):
    for I in insts:
        if I.hasTest():
            data = getTestGenerator(I).gen(I).definition()
            if directory:
                filename = "{}/{}.c".format(directory, I.intrinsicName())
                cmpwrite(filename, data)
            else:
                print data 

def gen_inst_def(insts):
    for I in insts:
        if I.hasLLVMInstDefine():
            print I.instDefine()

def gen_intrinsic_def(insts):
    for I in insts:
        if not I.hasImmOp():
            print I.intrinsicDefine()

def gen_pattern(insts):
    for I in insts:
        if I.hasInst()and I.hasPat():
            s = I.pattern()
            if s:
                print s

def gen_bulitin(insts):
    for I in insts:
        if (not I.hasImmOp()) and I.hasBuiltin():
            print I.builtin()

def gen_veintrin_h(insts):
    for I in insts:
        if (not I.hasImmOp()) and I.hasBuiltin():
            print I.veintrin()

def gen_mktest(insts):
    for I in insts:
        if I.hasTest() and I.asm():
            intrin = I.intrinsicName()
            print("python mktest.py {name} gen/tests/{name}.ll"
                  " gen/tests/{name}.s {asm} > tmp/gen-intrin-{name}.ll"
                  .format(name=intrin, asm=I.asm()))

def gen_lowering(insts):
    ary = []
    for I in insts:
        if I.hasMask() and I.isOldLowering():
            ary.append("case Intrinsic::ve_{}: return LowerIntrinsicWithMaskAndVL(Op, DAG, Subtarget, VE::{});"
                       .format(I.intrinsicName(), I.llvmInst(), len(I.ins)))
#            print("case Intrinsic::ve_{}: return LowerIntrinsicWithMaskAndVL(Op, DAG, Subtarget, VE::{});"
#                  .format(I.intrinsicName(), I.instName, len(I.ins)))
    # uniq because multiple Insts have the same intrinsic. ex VSTotrr and VSTotir
    ary = list(set(ary)) 
    for l in ary:
        print(l)

def createInstructionTable(isVL):
    InstClass = InstVE
    if isVL:
        InstClass = InstVEL
    T = InstTable(InstClass)
    I = InstClass # shortcut
    
    #
    # Start of instruction definition
    #
    
    T.Section("5.3.2.7. Vector Transfer Instructions", 18)
    T.VLDm(0x81, "VLD", "vld")
    T.VLDm(0x82, "VLDU", "vldu")
    T.VLDm(0x83, "VLDLsx", "vldl.sx")
    T.VLDm(0x83, "VLDLzx", "vldl.zx")
    T.VLDm(0xC1, "VLD2D", "vld2d")
    T.VLDm(0xC2, "VLDU2D", "vldu2d")
    T.VLDm(0xC3, "VLDL2Dsx", "vldl2d.sx")
    T.VLDm(0xC3, "VLDL2Dzx", "vldl2d.zx")
    T.VSTm(0x91, "VST", "vst")
    T.VSTm(0x92, "VSTU", "vstu")
    T.VSTm(0x93, "VSTL", "vstl")
    T.VSTm(0xD1, "VST2D", "vst2d")
    T.VSTm(0xD2, "VSTU2D", "vstu2d")
    T.VSTm(0xD3, "VSTL2D", "vstl2d")
    T.InstX(0x80, "PFCHV", "pfchv", [[None, SY(T_i64), SZ(T_voidcp)]], llvmInst="PFCHVr").noTest().inaccessibleMemOrArgMemOnly()
    T.InstX(0x80, "PFCHV", "pfchv", [[None, ImmI(T_i64), SZ(T_voidcp)]], llvmInst="PFCHVi").noTest().inaccessibleMemOrArgMemOnly()
    T.InstX(0x8E, "LSV", "lsv", [[VX(T_u64), VD(T_u64), SY(T_u32), SZ(T_u64)]]).noTest()
    #T.InstX(0x9E, "LVS", "lvs", [[SX(T_u64), VX(T_u64), SY(T_u32)]]).noTest()
    T.LVSm(0x9E)
    T.InstX(0xB7, "LVMr", "lvm", [[VMX, VMD, SY(T_u64), SZ(T_u64)]]).noTest()
    T.InstX(0xB7, "LVMi", "lvm", [[VMX, VMD, ImmN(T_u64), SZ(T_u64)]]).noTest()
    T.InstX(0xB7, "LVMpi","lvm", [[VMX512, VMD512, ImmN(T_u64), SZ(T_u64)]]).noTest()
    T.InstX(0xA7, "SVMr", "svm", [[SX(T_u64), VMZ, SY(T_u64)]]).noTest()
    T.InstX(0xA7, "SVMi", "svm", [[SX(T_u64), VMZ, ImmN(T_u64)]]).noTest()
    T.InstX(0xA7, "SVMpi", "svm", [[SX(T_u64), VMZ512, ImmN(T_u64)]]).noTest()
    T.VBRDm(0x8C)
    T.InstX(0x9C, "VMV", "vmv", [[VX(T_u64), SY(T_u32), VZ(T_u64)]]).noTest()
    T.InstX(0x9C, "VMV", "vmv", [[VX(T_u64), UImm7(T_u32), VZ(T_u64)]]).noTest()
    
    O_VMPD = [[VX(T_i64), VY(T_i32), VZ(T_i32)], 
              [VX(T_i64), SY(T_i32), VZ(T_i32)], 
              [VX(T_i64), ImmI(T_i32), VZ(T_i32)]]
    
    T.Section("5.3.2.8. Vector Fixed-Point Arithmetic Operation Instructions", 19)
    T.Inst3u(0xC8, "vaddu", "VADD", "{0} = {1} + {2}") # u32, u64
    T.Inst3w(0xCA, "vadds", "VADS", "{0} = {1} + {2}") # i32
    T.Inst3l(0x8B, "vadds", "VADX", "{0} = {1} + {2}") # i64
    T.Inst3u(0xC8, "vsubu", "VSUB", "{0} = {1} - {2}") # u32, u64
    T.Inst3w(0xCA, "vsubs", "VSBS", "{0} = {1} - {2}") # i32
    T.Inst3l(0x8B, "vsubs", "VSBX", "{0} = {1} - {2}") # i64
    T.Inst3u(0xC9, "vmulu", "VMPY", "{0} = {1} * {2}", False)
    T.Inst3w(0xCB, "vmuls", "VMPS", "{0} = {1} * {2}", False)
    T.Inst3l(0xDB, "vmuls", "VMPX", "{0} = {1} * {2}")
    T.InstX(0xD9, "VMPD", "vmuls.l.w", O_VMPD, "{0} = {1} * {2}")
    T.Inst3u(0xE9, "vdivu", "VDIV", "{0} = {1} / {2}", False)
    T.Inst3divbys(0xE9, "vdivu.l", "VDIVl", T_u64)
    T.Inst3divbys(0xE9, "vdivu.w", "VDIVw", T_u32)
    T.Inst3w(0xEB, "vdivs", "VDVS", "{0} = {1} / {2}", False)
    T.Inst3divbys(0xEB, "vdivs.w.sx", "VDVSwsx", T_i32)
    T.Inst3divbys(0xEB, "vdivs.w.zx", "VDVSwzx", T_i32)
    T.Inst3l(0xFB, "vdivs", "VDVX", "{0} = {1} / {2}")
    T.Inst3divbys(0xEB, "vdivs.l", "VDVXl", T_i64)
    T.Inst3u(0xB9, "vcmpu", "VCMP", "{0} = compare({1}, {2})")
    T.Inst3w(0xFA, "vcmps", "VCPS", "{0} = compare({1}, {2})")
    T.Inst3l(0xBA, "vcmps", "VCPX", "{0} = compare({1}, {2})")
    T.Inst3w(0x8A, "vmaxs", "VCMSa", "{0} = max({1}, {2})")
    T.Inst3w(0x8A, "vmins", "VCMSi", "{0} = min({1}, {2})")
    T.Inst3l(0x9A, "vmaxs", "VCMXa", "{0} = max({1}, {2})")
    T.Inst3l(0x9A, "vmins", "VCMXi", "{0} = min({1}, {2})")
    
    T.Section("5.3.2.9. Vector Logical Arithmetic Operation Instructions", 23)
    T.Logical(0xC4, "vand", "VAND", "{0} = {1} & {2}")
    T.Logical(0xC5, "vor",  "VOR",  "{0} = {1} | {2}")
    T.Logical(0xC6, "vxor", "VXOR", "{0} = {1} ^ {2}")
    T.Logical(0xC7, "veqv", "VEQV", "{0} = ~({1} ^ {2})")
    T.NoImpl("VLDZ")
    T.NoImpl("VPCNT")
    T.NoImpl("VBRV")
    T.InstX(0x99, "VSEQ", "vseq", [[VX(T_u64)]], "{0} = i").noTest()
    T.InstX(0x99, "VSEQl", "pvseq.lo", [[VX(T_u64)]], "{0} = i").noTest()
    T.InstX(0x99, "VSEQu", "pvseq.up", [[VX(T_u64)]], "{0} = i").noTest()
    T.InstX(0x99, "VSEQp", "pvseq", [[VX(T_u64)]], "{0} = i").noTest()
    
    T.Section("5.3.2.10. Vector Shift Instructions", 25)
    T.Shift(0xE5, "vsll", "VSLL", T_u64, "{0} = {1} << ({2} & 0x3f)")
    T.ShiftPacked(0xE5, "vsll", "VSLL", T_u32, "{0} = {1} << ({2} & 0x1f)")
    T.NoImpl("VSLD")
    T.Shift(0xF5, "vsrl", "VSRL", T_u64, "{0} = {1} >> ({2} & 0x3f)")
    T.ShiftPacked(0xF5, "vsrl", "VSRL", T_u32, "{0} = {1} >> ({2} & 0x1f)")
    T.NoImpl("VSRD")
    T.Shift(0xE6, "vsla.w", "VSLA", T_i32, "{0} = {1} << ({2} & 0x1f)")
    T.ShiftPacked(0xE6, "vsla", "VSLA", T_i32, "{0} = {1} << ({2} & 0x1f)")
    T.Shift(0xD4, "vsla.l", "VSLAX", T_i64, "{0} = {1} << ({2} & 0x3f)")
    T.Shift(0xF6, "vsra.w", "VSRA", T_i32, "{0} = {1} >> ({2} & 0x1f)")
    T.ShiftPacked(0xF6, "vsra", "VSRA", T_i32, "{0} = {1} >> ({2} & 0x1f)")
    T.Shift(0xD5, "vsra.l", "VSRAX", T_i64, "{0} = {1} >> ({2} & 0x3f)")
    
    O_vsfa = [[VX(T_u64), VZ(T_u64), SY(T_u64), SZ(T_u64)],[VX(T_u64), VZ(T_u64), ImmI(T_u64), SZ(T_u64)]]
    O_vsfa = T.addMask(O_vsfa)
    T.InstX(0xD7, "VSFA", "vsfa", O_vsfa, "{0} = ({1} << ({2} & 0x7)) + {3}")
    
    T.Section("5.3.2.11. Vector Floating-Point Operation Instructions", 26)
    T.Inst3f(0xCC, "vfadd", "VFAD", "{0} = {1} + {2}")
    T.Inst3f(0xDC, "vfsub", "VFSB", "{0} = {1} - {2}")
    T.Inst3f(0xCD, "vfmul", "VFMP", "{0} = {1} * {2}")
    T.Inst3f(0xDD, "vfdiv", "VFDV", "{0} = {1} / {2}", False)
    T.InstX(None, None, "vfdivsA", [[VX(T_f32), VY(T_f32), VZ(T_f32)]], expr="{0} = {1} / {2}")
    T.InstX(None, None, "vfdivsA", [[VX(T_f32), SY(T_f32), VZ(T_f32)]], expr="{0} = {1} / {2}")
    T.InstX(None, None, "pvfdivA", [[VX(T_f32), VY(T_f32), VZ(T_f32)]], expr="{0} = {1} / {2}")
    T.Inst2f(0xED, "vfsqrt", "VFSQRT", "{0} = std::sqrt({1})", False)
    T.Inst3f(0xFC, "vfcmp", "VFCP", "{0} = compare({1}, {2})")
    T.Inst3f(0xBD, "vfmax", "VFCMa", "{0} = max({1}, {2})")
    T.Inst3f(0xBD, "vfmin", "VFCMi", "{0} = min({1}, {2})")
    T.Inst4f(0xE2, "vfmad", "VFMAD", "{0} = {2} * {3} + {1}")
    T.Inst4f(0xF2, "vfmsb", "VFMSB", "{0} = {2} * {3} - {1}")
    T.Inst4f(0xE3, "vfnmad", "VFNMAD", "{0} =  - ({2} * {3} + {1})")
    T.Inst4f(0xF3, "vfnmsb", "VFNMSB", "{0} =  - ({2} * {3} - {1})")
    T.Inst2f(0xE1, "vrcp", "VRCP", "{0} = 1.0f / {1}")
    T.Inst2f(0xF1, "vrsqrt", "VRSQRT", "{0} = 1.0f / std::sqrt({1})", True)
    T.NoImpl("VRSQRTnex")
    T.VFIX(0xE8, "VFIXdsx", "vcvt.w.d.sx", [[VX(T_i32), VY(T_f64)]], "int")
    T.VFIX(0xE8, "VFIXdzx", "vcvt.w.d.zx", [[VX(T_i32), VY(T_f64)]], "unsigned int")
    T.VFIX(0xE8, "VFIXssx", "vcvt.w.s.sx", [[VX(T_i32), VY(T_f32)]], "int")
    T.VFIX(0xE8, "VFIXszx", "vcvt.w.s.zx", [[VX(T_i32), VY(T_f32)]], "unsigned int")
    T.VFIX(0xE8, "VFIXp", "pvcvt.w.s", [[VX(T_i32), VY(T_f32)]], "int")
    T.VFIX(0xA8, "VFIXX", "vcvt.l.d", [[VX(T_i64), VY(T_f64)]], "long long")
    T.InstX(0xF8, "VFLTd", "vcvt.d.w", [[VX(T_f64), VY(T_i32)]], "{0} = (double){1}")
    T.InstX(0xF8, "VFLTs", "vcvt.s.w", [[VX(T_f32), VY(T_i32)]], "{0} = (float){1}")
    T.InstX(0xF8, "VFLTp", "pvcvt.s.w", [[VX(T_f32), VY(T_i32)]], "{0} = (float){1}")
    T.InstX(0xB8, "VFLTX", "vcvt.d.l", [[VX(T_f64), VY(T_i64)]], "{0} = (double){1}")
    T.InstX(0x8F, "VCVD", "vcvt.d.s", [[VX(T_f64), VY(T_f32)]], "{0} = (double){1}")
    T.InstX(0x9F, "VCVS", "vcvt.s.d", [[VX(T_f32), VY(T_f64)]], "{0} = (float){1}")
    
    T.Section("5.3.2.12. Vector Mask Arithmetic Instructions", 31)
    T.InstX(0xD6, "VMRG", "vmrg", [[VX(T_u64), VY(T_u64), VZ(T_u64), VM]])
    T.add(I(0xD6, "VMRG", "vmrg.w", "vmrgw_vvvM", [VX(T_u32)], [VY(T_u32), VZ(T_u32), VM512], packed=True, llvmInst='VMRGpvm')) # packed but not pvmrg
    T.InstX(0xBC, "VSHF", "vshf", [[VX(T_u64), VY(T_u64), VZ(T_u64), SY(T_u64)], [VX(T_u64), VY(T_u64), VZ(T_u64), ImmN(T_u64)]])
    T.InstX(0x8D, "VCP", "vcp", [[VX(T_u64), VZ(T_u64), VM, VD(T_u64)]]).noTest()
    T.InstX(0x9D, "VEX", "vex", [[VX(T_u64), VZ(T_u64), VM, VD(T_u64)]]).noTest()
    T.VFMKm(0xB4, "VFMK", "vfmk.l")
    T.InstX(0xB4, "VFMKat", "vfmk.at", [[VM]]).noTest()
    T.InstX(0xB4, "VFMKaf", "vfmk.af", [[VM]]).noTest()
    T.InstX(None, "VFMKpat", "pvfmk.at", [[VM512]]).noTest() # Pseudo
    T.InstX(None, "VFMKpaf", "pvfmk.af", [[VM512]]).noTest() # Pseudo
    T.VFMKm(0xB4, "VFMS", "vfmk.w")
    T.InstX(None, "VFMSp", "pvfmk.w", [[VM512, CCOp, VZ(T_i32)]]).noTest() # Pseudo
    T.InstX(None, "VFMSp", "pvfmk.w", [[VMX512, CCOp, VZ(T_i32), VM512]]).noTest() # Pseudo
    T.VFMKm(0xB4, "VFMFd", "vfmk.d")
    T.VFMKm(0xB4, "VFMFs", "vfmk.s")
    T.InstX(None, "VFMFp", "pvfmk.s", [[VM512, CCOp, VZ(T_f32)]]).noTest() # Pseudo
    T.InstX(None, "VFMFp", "pvfmk.s", [[VMX512, CCOp, VZ(T_f32), VM512]]).noTest() # Pseudo
    
    
    T.Section("5.3.2.13. Vector Recursive Relation Instructions", 32)
    T.VSUM(0xEA, "VSUMSsx", "vsum.w.sx", [[VX(T_i32), VY(T_i32)]])
    T.VSUM(0xEA, "VSUMSzx", "vsum.w.zx", [[VX(T_i32), VY(T_i32)]])
    T.VSUM(0xAA, "VSUMX", "vsum.l", [[VX(T_i64), VY(T_i64)]])
    T.VSUM(0xEC, "VFSUMd", "vfsum.d", [[VX(T_f64), VY(T_f64)]])
    T.VSUM(0xEC, "VFSUMs", "vfsum.s", [[VX(T_f32), VY(T_f32)]])
    T.FLm(0xBB, "VMAXSa{fl}sx", "vrmaxs.w{fl}.sx", [[VX(T_i32), VY(T_i32)]])
    T.FLm(0xBB, "VMAXSa{fl}zx", "vrmaxs.w{fl}.zx", [[VX(T_u32), VY(T_u32)]])
    T.FLm(0xBB, "VMAXSi{fl}sx", "vrmins.w{fl}.sx", [[VX(T_i32), VY(T_i32)]])
    T.FLm(0xBB, "VMAXSi{fl}zx", "vrmins.w{fl}.zx", [[VX(T_u32), VY(T_u32)]])
    T.FLm(0xAB, "VMAXXa{fl}", "vrmaxs.l{fl}", [[VX(T_i64), VY(T_i64)]])
    T.FLm(0xAB, "VMAXXi{fl}", "vrmins.l{fl}", [[VX(T_i64), VY(T_i64)]])
    T.FLm(0xAD, "VFMAXad{fl}", "vfrmax.d{fl}", [[VX(T_f64), VY(T_f64)]])
    T.FLm(0xAD, "VFMAXas{fl}", "vfrmax.s{fl}", [[VX(T_f32), VY(T_f32)]])
    T.FLm(0xAD, "VFMAXid{fl}", "vfrmin.d{fl}", [[VX(T_f64), VY(T_f64)]])
    T.FLm(0xAD, "VFMAXis{fl}", "vfrmin.s{fl}", [[VX(T_f32), VY(T_f32)]])
    T.NoImpl("VRAND")
    T.NoImpl("VROR")
    T.NoImpl("VRXOR")
    T.NoImpl("VFIA")
    T.NoImpl("VFIS")
    T.NoImpl("VFIM")
    T.NoImpl("VFIAM")
    T.NoImpl("VFISM")
    T.NoImpl("VFIMA")
    T.NoImpl("VFIMS")
    
    T.Section("5.3.2.14. Vector Gathering/Scattering Instructions", 33)
    T.VGTm(0xA1, "VGT", "vgt")
    T.VGTm(0xA2, "VGTU", "vgtu")
    T.VGTm(0xA3, "VGTLsx", "vgtl.sx")
    T.VGTm(0xA3, "VGTLzx", "vgtl.zx")
    T.VSCm(0xB1, "VSC", "VSC", "vsc")
    T.VSCm(0xB2, "VSCU", "VSCU", "vscu")
    T.VSCm(0xB3, "VSCL", "VSCL", "vscl")
    
    T.Section("5.3.2.15. Vector Mask Register Instructions", 34)
    T.InstX(0x84, "ANDM", "andm", [[VMX, VMY, VMZ]], "{0} = {1} & {2}")
    T.InstX(0x84, "ANDMp", "andm", [[VMX512, VMY512, VMZ512]], "{0} = {1} & {2}")
    T.InstX(0x85, "ORM",  "orm",  [[VMX, VMY, VMZ]], "{0} = {1} | {2}")
    T.InstX(0x85, "ORMp",  "orm",  [[VMX512, VMY512, VMZ512]], "{0} = {1} | {2}")
    T.InstX(0x86, "XORM", "xorm", [[VMX, VMY, VMZ]], "{0} = {1} ^ {2}")
    T.InstX(0x86, "XORMp", "xorm", [[VMX512, VMY512, VMZ512]], "{0} = {1} ^ {2}")
    T.InstX(0x87, "EQVM", "eqvm", [[VMX, VMY, VMZ]], "{0} = ~({1} ^ {2})")
    T.InstX(0x87, "EQVMp", "eqvm", [[VMX512, VMY512, VMZ512]], "{0} = ~({1} ^ {2})")
    T.InstX(0x94, "NNDM", "nndm", [[VMX, VMY, VMZ]], "{0} = (~{1}) & {2}")
    T.InstX(0x94, "NNDMp", "nndm", [[VMX512, VMY512, VMZ512]], "{0} = (~{1}) & {2}")
    T.InstX(0x95, "NEGM", "negm", [[VMX, VMY]], "{0} = ~{1}")
    T.InstX(0x95, "NEGMp", "negm", [[VMX512, VMY512]], "{0} = ~{1}")
    T.InstX(0xA4, "PCVM", "pcvm", [[SX(T_u64), VMY]]).noTest();
    T.InstX(0xA5, "LZVM", "lzvm", [[SX(T_u64), VMY]]).noTest();
    T.InstX(0xA6, "TOVM", "tovm", [[SX(T_u64), VMY]]).noTest();
    
    
    T.Section("5.3.2.16. Vector Control Instructions", 34)
    T.Dummy("LVL", "void _ve_lvl(int vl)", "lvl")
    T.NoImpl("SVL")
    T.NoImpl("SMVL")
    T.NoImpl("LVIX")
    
    T.Section("5.3.2.17. Control Instructions", 35)
    T.Dummy("SVOB", "void _ve_svob(void)", "svob");
    
    T.Section("Others", None)
    T.Dummy("", "unsigned long int _ve_pack_f32p(float const* p0, float const* p1)", "ldu,ldl,or")
    T.Dummy("", "unsigned long int _ve_pack_f32a(float const* p)", "load and mul")
    T.Dummy("", "unsigned long int _ve_pack_i32(int a, int b)", "sll,add,or")
    
    T.InstX(None, None, "vec_expf", [[VX(T_f32), VY(T_f32)]], "{0} = expf({1})").noBuiltin()
    T.InstX(None, None, "vec_exp", [[VX(T_f64), VY(T_f64)]], "{0} = exp({1})").noBuiltin()
    T.Dummy("", "__vm _ve_extract_vm512u(__vm512 vm)", "")
    T.Dummy("", "__vm _ve_extract_vm512l(__vm512 vm)", "")
    T.Dummy("", "__vm512 _ve_insert_vm512u(__vm512 vmx, __vm vmy)", "")
    T.Dummy("", "__vm512 _ve_insert_vm512l(__vm512 vmx, __vm vmy)", "")

    return T

#
# End of instruction definition
#

import argparse

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('-i', '--intrin', dest="opt_intrin", action="store_true")
    parser.add_argument('--inst', dest="opt_inst", action="store_true")
    parser.add_argument('-p', "--pattern", dest="opt_pat", action="store_true")
    parser.add_argument('-b', dest="opt_builtin", action="store_true")
    parser.add_argument('--veintrin', dest="opt_veintrin", action="store_true")
    parser.add_argument('--decl', dest="opt_decl", action="store_true")
    parser.add_argument('-t', dest="opt_test", action="store_true")
    parser.add_argument('-r', dest="opt_reference", action="store_true")
    parser.add_argument('-f', dest="opt_filter", action="store")
    parser.add_argument('-m', dest="opt_manual", action="store_true")
    parser.add_argument('-a', dest="opt_all", action="store_true")
    parser.add_argument('--html', dest="opt_html", action="store_true")
    parser.add_argument('--html-no-link', action="store_true")
    parser.add_argument('--mktest', dest="opt_mktest", action="store_true")
    parser.add_argument('-l', dest="opt_lowering", action="store_true")
    parser.add_argument('--vl', action="store_true")
    args, others = parser.parse_known_args()
    
    global llvmIntrinsicPrefix
    if args.vl:
        llvmIntrinsicPrefix = "ve_vl"
    
    T = createInstructionTable(args.vl)
    insts = T.insts()
    
    test_dir = "../llvm-test/intrinsic/gen/tests"
    
    if args.opt_filter:
        insts = [i for i in insts if re.search(args.opt_filter, i.intrinsicName())]
        print "filter: {} -> {}".format(args.opt_filter, len(insts))
    
    if args.opt_all:
        args.opt_inst = True
        args.opt_intrin = True
        args.opt_pat = True
        args.opt_builtin = True
        args.opt_veintrin = True
        args.opt_decl = True
        args.opt_reference = True
        args.opt_test = True
        #args.opt_html = True
        test_dir = None

    if args.opt_inst:
        gen_inst_def(insts)
    if args.opt_intrin:
        gen_intrinsic_def(insts)
    if args.opt_pat:
        gen_pattern(insts)
    if args.opt_builtin:
        gen_bulitin(insts)
    if args.opt_veintrin:
        gen_veintrin_h(insts)
    if args.opt_decl:
        for I in insts:
            if I.hasTest():
                print getTestGenerator(I).gen(I).decl()
    if args.opt_test:
        gen_test(insts, test_dir)
    if args.opt_reference:
        print '#include <math.h>'
        print '#include <algorithm>'
        print 'using namespace std;'
        print '#include "../refutils.h"'
        print 'namespace ref {'
        for I in insts:
            if I.hasTest():
                f = getTestGenerator(I).gen(I).reference()
                if f:
                    print f
            continue
            
            if len(i.outs) > 0 and i.outs[0].isMask() and i.hasExpr():
                f = TestGeneratorMask().gen(i)
                print f.reference()
                continue
            if i.hasTest() and i.hasExpr():
                print TestGenerator().reference(i)
        print '}'
    if args.opt_html:
        HtmlManualPrinter().printAll(T, False)
    if args.html_no_link:
        HtmlManualPrinter().printAll(T, True)
    if args.opt_mktest:
        gen_mktest(insts)
    if args.opt_lowering:
        gen_lowering(insts)
    
    if args.opt_manual:
        ManualInstPrinter().printAll(insts)
    
if __name__ == "__main__":
    main()
