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
    // fp unary
    case Instruction::FNeg: return EVLIntrinsicDesc{ Intrinsic::evl_fneg, TypeTokenVec{EVLTypeToken::Vector}, 1, 2}; break;

    // fp binary
    case Instruction::FAdd: return EVLIntrinsicDesc{ Intrinsic::evl_fadd, TypeTokenVec{EVLTypeToken::Vector}, 2, 3}; break;
    case Instruction::FSub: return EVLIntrinsicDesc{ Intrinsic::evl_fsub, TypeTokenVec{EVLTypeToken::Vector}, 2, 3}; break;
    case Instruction::FMul: return EVLIntrinsicDesc{ Intrinsic::evl_fmul, TypeTokenVec{EVLTypeToken::Vector}, 2, 3}; break;
    case Instruction::FDiv: return EVLIntrinsicDesc{ Intrinsic::evl_fdiv, TypeTokenVec{EVLTypeToken::Vector}, 2, 3}; break;
    case Instruction::FRem: return EVLIntrinsicDesc{ Intrinsic::evl_frem, TypeTokenVec{EVLTypeToken::Vector}, 2, 3}; break;

    // sign-oblivious int
    case Instruction::Add: return EVLIntrinsicDesc{ Intrinsic::evl_add, TypeTokenVec{EVLTypeToken::Vector}, 2, 3}; break;
    case Instruction::Sub: return EVLIntrinsicDesc{ Intrinsic::evl_sub, TypeTokenVec{EVLTypeToken::Vector}, 2, 3}; break;
    case Instruction::Mul: return EVLIntrinsicDesc{ Intrinsic::evl_mul, TypeTokenVec{EVLTypeToken::Vector}, 2, 3}; break;

    // signed/unsigned int
    case Instruction::SDiv: return EVLIntrinsicDesc{ Intrinsic::evl_sdiv, TypeTokenVec{EVLTypeToken::Vector}, 2, 3}; break;
    case Instruction::UDiv: return EVLIntrinsicDesc{ Intrinsic::evl_udiv, TypeTokenVec{EVLTypeToken::Vector}, 2, 3}; break;
    case Instruction::SRem: return EVLIntrinsicDesc{ Intrinsic::evl_srem, TypeTokenVec{EVLTypeToken::Vector}, 2, 3}; break;
    case Instruction::URem: return EVLIntrinsicDesc{ Intrinsic::evl_urem, TypeTokenVec{EVLTypeToken::Vector}, 2, 3}; break;

    // logical
    case Instruction::Or:  return EVLIntrinsicDesc{ Intrinsic::evl_or, TypeTokenVec{EVLTypeToken::Vector}, 2, 3}; break;
    case Instruction::And: return EVLIntrinsicDesc{ Intrinsic::evl_and, TypeTokenVec{EVLTypeToken::Vector}, 2, 3}; break;
    case Instruction::Xor: return EVLIntrinsicDesc{ Intrinsic::evl_xor, TypeTokenVec{EVLTypeToken::Vector}, 2, 3}; break;

    case Instruction::LShr: return EVLIntrinsicDesc{ Intrinsic::evl_lshr, TypeTokenVec{EVLTypeToken::Vector}, 2, 3}; break;
    case Instruction::AShr: return EVLIntrinsicDesc{ Intrinsic::evl_ashr, TypeTokenVec{EVLTypeToken::Vector}, 2, 3}; break;
    case Instruction::Shl:  return EVLIntrinsicDesc{ Intrinsic::evl_shl, TypeTokenVec{EVLTypeToken::Vector}, 2, 3}; break;

    // comparison
    case Instruction::ICmp:
    case Instruction::FCmp:
      return EVLIntrinsicDesc{ Intrinsic::evl_cmp, TypeTokenVec{EVLTypeToken::Mask, EVLTypeToken::Vector}, 2, 3}; break;

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
    default:
      llvm_unreachable("unsupported token"); // unsupported EVLTypeToken

    case EVLTypeToken::Scalar: STV.push_back(&ScalarTy); break;
    case EVLTypeToken::Vector: STV.push_back(&VectorTy); break;
    case EVLTypeToken::Mask:
      auto NumElems = VectorTy.getVectorNumElements();
      auto MaskTy = VectorType::get(Type::getInt1Ty(VectorTy.getContext()), NumElems);
      STV.push_back(MaskTy); break;

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

  auto evlDesc = GetEVLIntrinsicDesc(oc);
  if (evlDesc.ID == Intrinsic::not_intrinsic) {
    return nullptr;
  }

  if ((oc <= Instruction::BinaryOpsEnd) &&
      (oc >= Instruction::BinaryOpsBegin)) {

    assert(VecOpArray.size() == 2);
    Value & FirstOp = *VecOpArray[0];
    Value & SndOp = *VecOpArray[1];

    // Fetch the EVL intrinsic
    auto & VecTy = cast<VectorType>(*FirstOp.getType());
    auto & ScalarTy = *VecTy.getVectorElementType();
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

  if ((oc <= Instruction::UnaryOpsBegin) &&
      (oc >= Instruction::UnaryOpsEnd)) {
    assert(VecOpArray.size() == 1);
    Value & FirstOp = *VecOpArray[0];

    // Fetch the EVL intrinsic
    auto & VecTy = cast<VectorType>(*FirstOp.getType());
    auto & ScalarTy = *VecTy.getVectorElementType();
    auto * Func = Intrinsic::getDeclaration(&getModule(), evlDesc.ID, EncodeTypeTokens(evlDesc.typeTokens, VecTy, ScalarTy));

    assert((evlDesc.MaskPos == 1) && (evlDesc.EVLPos == 2));

    // Materialize the Call
    ShortValueVec Args{&FirstOp, &GetMaskForType(VecTy), &GetEVLForType(VecTy)};

    auto & EVLCall = *Builder.CreateCall(Func, Args);

    // transfer fast math flags
    if (isa<FPMathOperator>(Inst)) {
      cast<CallInst>(EVLCall).copyFastMathFlags(Inst.getFastMathFlags());
    }

    return &EVLCall;
  }

  switch (oc) {
    default:
      return nullptr;

    case Instruction::FCmp:
    case Instruction::ICmp: {
      assert(VecOpArray.size() == 2);
      Value & FirstOp = *VecOpArray[0];
      Value & SndOp = *VecOpArray[1];

      // Fetch the EVL intrinsic
      auto & VecTy = cast<VectorType>(*FirstOp.getType());
      auto & ScalarTy = *VecTy.getVectorElementType();
      auto * Func = Intrinsic::getDeclaration(&getModule(), evlDesc.ID, EncodeTypeTokens(evlDesc.typeTokens, VecTy, ScalarTy));

      assert((evlDesc.MaskPos == 2) && (evlDesc.EVLPos == 3));

      // encode comparison predicate as MD
      uint8_t RawPred = cast<CmpInst>(Inst).getPredicate();
      auto Int8Ty = Builder.getInt8Ty();
      auto PredArg = ConstantInt::get(Int8Ty, RawPred, false);

      // Materialize the Call
      ShortValueVec Args{&FirstOp, &SndOp, &GetMaskForType(VecTy), &GetEVLForType(VecTy), PredArg};

      return Builder.CreateCall(Func, Args);
    }

     case Instruction::Select: {
      assert(VecOpArray.size() == 2);
      Value & MaskOp = *VecOpArray[0];
      Value & OnTrueOp = *VecOpArray[1];
      Value & OnFalseOp = *VecOpArray[2];

      // Fetch the EVL intrinsic
      auto & VecTy = cast<VectorType>(*OnTrueOp.getType());
      auto & ScalarTy = *VecTy.getVectorElementType();

      auto * Func = Intrinsic::getDeclaration(&getModule(), evlDesc.ID, EncodeTypeTokens(evlDesc.typeTokens, VecTy, ScalarTy));

      assert((evlDesc.MaskPos == 2) && (evlDesc.EVLPos == 3));

      // Materialize the Call
      ShortValueVec Args{&OnTrueOp, &OnFalseOp, &MaskOp, &GetEVLForType(VecTy)};

      return Builder.CreateCall(Func, Args);
    }
  }
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
EVLBuilder::CreateContiguousLoad(Value & Pointer) {
  auto & PointerTy = cast<PointerType>(*Pointer.getType());
  auto & VecTy = getVectorType(*PointerTy.getPointerElementType());

  auto * LoadFunc = Intrinsic::getDeclaration(&getModule(), Intrinsic::evl_load, {&VecTy, &PointerTy});
  ShortValueVec Args{&Pointer, &GetMaskForType(VecTy), &GetEVLForType(VecTy)};
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
EVLBuilder::CreateGather(Value & PointerVec) {
  auto & PointerVecTy = cast<VectorType>(*PointerVec.getType());
  auto & ElemTy = *cast<PointerType>(*PointerVecTy.getVectorElementType()).getPointerElementType();
  auto & VecTy = *VectorType::get(&ElemTy, PointerVecTy.getNumElements());
  auto * GatherFunc = Intrinsic::getDeclaration(&getModule(), Intrinsic::evl_gather, {&VecTy, &PointerVecTy});

  ShortValueVec Args{&PointerVec, &GetMaskForType(VecTy), &GetEVLForType(VecTy)};
  return *Builder.CreateCall(GatherFunc, Args);
}

} // namespace llvm
