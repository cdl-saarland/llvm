#include <llvm/IR/PredicatedInst.h>
#include <llvm/IR/Instruction.h>
#include <llvm/IR/Instructions.h>
#include <llvm/IR/InstrTypes.h>
#include <llvm/IR/IntrinsicInst.h>

namespace {
  using namespace llvm;
  using ShortValueVec = SmallVector<Value*, 4>;
}

namespace llvm {

void
PredicatedOperator::copyIRFlags(const Value * V, bool IncludeWrapFlags) {
  auto * I = dyn_cast<Instruction>(this);
  if (I) I->copyIRFlags(V, IncludeWrapFlags);
}

Instruction*
PredicatedBinaryOperator::Create(Module * Mod,
                                 Value *Mask, Value *VectorLen,
                                 Instruction::BinaryOps Opc,
                                 Value *V1, Value *V2,
                                 const Twine &Name,
                                 BasicBlock * InsertAtEnd,
                                 Instruction * InsertBefore) {
  assert(!(InsertAtEnd && InsertBefore));

  auto evlDesc = VPIntrinsic::GetVPIntrinsicDesc(Opc);

  if ((!Mod ||
      (!Mask && !VectorLen)) ||
      evlDesc.ID == Intrinsic::not_intrinsic) {
    if (InsertAtEnd) {
      return BinaryOperator::Create(Opc, V1, V2, Name, InsertAtEnd);
    } else {
      return BinaryOperator::Create(Opc, V1, V2, Name, InsertBefore);
    }
  }

  assert(Mod && "Need a module to emit VP Intrinsics");

  // Fetch the VP intrinsic
  auto & VecTy = cast<VectorType>(*V1->getType());
  auto & ScalarTy = *VecTy.getVectorElementType();
  auto * Func = Intrinsic::getDeclaration(Mod, evlDesc.ID, VPIntrinsic::EncodeTypeTokens(evlDesc.typeTokens, VecTy, ScalarTy));

  assert((evlDesc.MaskPos == 2) && (evlDesc.EVLPos == 3));

  // Materialize the Call
  ShortValueVec Args{V1, V2, Mask, VectorLen};

  if (InsertAtEnd) {
    return CallInst::Create(Func, {V1, V2, Mask, VectorLen}, Name, InsertAtEnd);
  } else {
    return CallInst::Create(Func, {V1, V2, Mask, VectorLen}, Name, InsertBefore);
  }
}

}
