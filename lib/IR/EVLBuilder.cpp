#include <llvm/IR/EVLBuilder.h>
#include <llvm/IR/Intrinsics.h>
#include <llvm/IR/Instructions.h>

#include <llvm/ADT/SmallVector.h>

namespace llvm {

Module &
EVLBuilder::getModule() const {
  return *Builder.GetInsertBlock()->getParent()->getParent();
}

EVLIntrinsicDesc
EVLBuilder::GetEVLIntrinsicDesc(unsigned OC) {
  switch (OC) {
    // fp
    case Instruction::FAdd: return EVLIntrinsicDesc{ Intrinsic::evl_fadd, TypeTokenVec{EVLTypeToken::Vector}, 2, 3}; break;
    case Instruction::FSub: return EVLIntrinsicDesc{ Intrinsic::evl_fsub, TypeTokenVec{EVLTypeToken::Vector}, 2, 3}; break;
    case Instruction::FMul: return EVLIntrinsicDesc{ Intrinsic::evl_fmul, TypeTokenVec{EVLTypeToken::Vector}, 2, 3}; break;
    case Instruction::FDiv: return EVLIntrinsicDesc{ Intrinsic::evl_fdiv, TypeTokenVec{EVLTypeToken::Vector}, 2, 3}; break;
    case Instruction::FRem: return EVLIntrinsicDesc{ Intrinsic::evl_frem, TypeTokenVec{EVLTypeToken::Vector}, 2, 3}; break;

    // sign-oblivious
    case Instruction::Add: return EVLIntrinsicDesc{ Intrinsic::evl_add, TypeTokenVec{EVLTypeToken::Vector}, 2, 3}; break;
    case Instruction::Sub: return EVLIntrinsicDesc{ Intrinsic::evl_sub, TypeTokenVec{EVLTypeToken::Vector}, 2, 3}; break;
    case Instruction::Mul: return EVLIntrinsicDesc{ Intrinsic::evl_mul, TypeTokenVec{EVLTypeToken::Vector}, 2, 3}; break;

    // signed
    case Instruction::SDiv: return EVLIntrinsicDesc{ Intrinsic::evl_sdiv, TypeTokenVec{EVLTypeToken::Vector}, 2, 3}; break;
    case Instruction::UDiv: return EVLIntrinsicDesc{ Intrinsic::evl_udiv, TypeTokenVec{EVLTypeToken::Vector}, 2, 3}; break;
    case Instruction::SRem: return EVLIntrinsicDesc{ Intrinsic::evl_srem, TypeTokenVec{EVLTypeToken::Vector}, 2, 3}; break;
    case Instruction::URem: return EVLIntrinsicDesc{ Intrinsic::evl_urem, TypeTokenVec{EVLTypeToken::Vector}, 2, 3}; break;

  default:
    return EVLIntrinsicDesc{Intrinsic::not_intrinsic, TypeTokenVec(), -1, -1};
  }
}

static
ShortTypeVec
EncodeTypeTokens(TypeTokenVec TTVec, Type & VectorTy, Type & ScalarTy) {
  ShortTypeVec STV;

  for (auto Token : TTVec) {
    switch (Token) {
      case EVLTypeToken::Scalar: STV.push_back(&ScalarTy); break;
      case EVLTypeToken::Vector: STV.push_back(&VectorTy); break;
      default: abort(); // unsupported EVLTypeToken
    }
  }

  return STV;
}

Value&
EVLBuilder::GetMaskForType(VectorType & VecTy) {
  if (Mask) return *Mask;

  auto * boolTy = Builder.getInt1Ty();
  auto * maskTy = VectorType::get(boolTy, StaticVectorLength);
  return *ConstantInt::getAllOnesValue(maskTy);
}

Value&
EVLBuilder::GetEVLForType(VectorType & VecTy) {
  if (ExplicitVectorLength) return *ExplicitVectorLength;

  // TODO SVE
  auto * intTy = Builder.getInt32Ty();
  return *ConstantInt::get(intTy, StaticVectorLength);
}

Value*
EVLBuilder::CreateVectorCopy(Instruction & Inst, ValArray VecOpArray) {
  auto oc = Inst.getOpcode();

  if ((oc <= Instruction::BinaryOpsEnd) &&
      (oc >= Instruction::BinaryOpsBegin)) {
    assert(VecOpArray.size() == 2);
    Value & FirstOp = *VecOpArray[0];
    Value & SndOp = *VecOpArray[1];

    // Fetch the EVL intrinsic
    auto & VecTy = cast<VectorType>(*FirstOp.getType());
    auto & ScalarTy = *VecTy.getVectorElementType();
    auto evlDesc = GetEVLIntrinsicDesc(oc);
    if (evlDesc.ID == Intrinsic::not_intrinsic) {
      return nullptr;
    }

    assert (evlDesc.ID != Intrinsic::not_intrinsic);
    auto * Func = Intrinsic::getDeclaration(&getModule(), evlDesc.ID, EncodeTypeTokens(evlDesc.typeTokens, VecTy, ScalarTy));

    assert((evlDesc.MaskPos == 2) && (evlDesc.EVLPos == 3));

    // Materialize the Call
    ShortValueVec Args{&FirstOp, &SndOp, &GetMaskForType(VecTy), &GetEVLForType(VecTy)};

    auto & EVLCall = *Builder.CreateCall(Func, Args);

    // transfer fast math flags
    if (isa<FPMathOperator>(Inst)) {
      cast<CallInst>(EVLCall).copyFastMathFlags(Inst.getFastMathFlags());
    }

    return &EVLCall;
  }

  return nullptr;
}

VectorType&
EVLBuilder::getVectorType(Type &ElementTy) {
  return *VectorType::get(&ElementTy, StaticVectorLength);
}

Value&
EVLBuilder::CreateContiguousStore(Value & Val, Value & Pointer) {
  auto & VecTy = cast<VectorType>(*Val.getType());
  auto * StoreFunc = Intrinsic::getDeclaration(&getModule(), Intrinsic::evl_store, {Val.getType(), Pointer.getType()});
  ShortValueVec Args{&Val, &Pointer, &GetMaskForType(VecTy), &GetEVLForType(VecTy)};
  return *Builder.CreateCall(StoreFunc, Args);
}

Value&
EVLBuilder::CreateContiguousLoad(Value & Pointer, Value * Passthru) {
  auto & PointerTy = cast<PointerType>(*Pointer.getType());
  auto & VecTy = getVectorType(*PointerTy.getPointerElementType());

  auto * LoadFunc = Intrinsic::getDeclaration(&getModule(), Intrinsic::evl_load, {&VecTy, &PointerTy});
  if (!Passthru) {
    Passthru = UndefValue::get(&VecTy);
  }

  ShortValueVec Args{&Pointer, Passthru, &GetMaskForType(VecTy), &GetEVLForType(VecTy)};
  return *Builder.CreateCall(LoadFunc, Args);
}

Value&
EVLBuilder::CreateScatter(Value & Val, Value & PointerVec) {
  auto & VecTy = cast<VectorType>(*Val.getType());
  auto * ScatterFunc = Intrinsic::getDeclaration(&getModule(), Intrinsic::evl_scatter, {Val.getType(), PointerVec.getType()});
  ShortValueVec Args{&Val, &PointerVec, &GetMaskForType(VecTy), &GetEVLForType(VecTy)};
  return *Builder.CreateCall(ScatterFunc, Args);
}

Value&
EVLBuilder::CreateGather(Value & PointerVec, Value * Passthru) {
  auto & PointerVecTy = cast<VectorType>(*PointerVec.getType());
  auto & ElemTy = *cast<PointerType>(*PointerVecTy.getVectorElementType()).getPointerElementType();
  auto & VecTy = *VectorType::get(&ElemTy, PointerVecTy.getNumElements());
  auto * GatherFunc = Intrinsic::getDeclaration(&getModule(), Intrinsic::evl_gather, {&VecTy, &PointerVecTy});

  if (!Passthru) {
    Passthru = UndefValue::get(&VecTy);
  }
  ShortValueVec Args{&PointerVec, Passthru, &GetMaskForType(VecTy), &GetEVLForType(VecTy)};
  return *Builder.CreateCall(GatherFunc, Args);
}

} // namespace llvm
