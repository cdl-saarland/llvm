//===-- InstrinsicInst.cpp - Intrinsic Instruction Wrappers ---------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file implements methods that make it really easy to deal with intrinsic
// functions.
//
// All intrinsic function calls are instances of the call instruction, so these
// are all subclasses of the CallInst class.  Note that none of these classes
// has state or virtual methods, which is an important part of this gross/neat
// hack working.
//
// In some cases, arguments to intrinsics need to be generic and are defined as
// type pointer to empty struct { }*.  To access the real item of interest the
// cast instruction needs to be stripped away.
//
//===----------------------------------------------------------------------===//

#include "llvm/IR/IntrinsicInst.h"
#include "llvm/IR/Operator.h"
#include "llvm/ADT/StringSwitch.h"
#include "llvm/IR/Constants.h"
#include "llvm/IR/DebugInfoMetadata.h"
#include "llvm/IR/GlobalVariable.h"
#include "llvm/IR/Metadata.h"
#include "llvm/IR/Module.h"
#include "llvm/Support/raw_ostream.h"
using namespace llvm;

//===----------------------------------------------------------------------===//
/// DbgVariableIntrinsic - This is the common base class for debug info
/// intrinsics for variables.
///

Value *DbgVariableIntrinsic::getVariableLocation(bool AllowNullOp) const {
  Value *Op = getArgOperand(0);
  if (AllowNullOp && !Op)
    return nullptr;

  auto *MD = cast<MetadataAsValue>(Op)->getMetadata();
  if (auto *V = dyn_cast<ValueAsMetadata>(MD))
    return V->getValue();

  // When the value goes to null, it gets replaced by an empty MDNode.
  assert(!cast<MDNode>(MD)->getNumOperands() && "Expected an empty MDNode");
  return nullptr;
}

Optional<uint64_t> DbgVariableIntrinsic::getFragmentSizeInBits() const {
  if (auto Fragment = getExpression()->getFragmentInfo())
    return Fragment->SizeInBits;
  return getVariable()->getSizeInBits();
}

int llvm::Intrinsic::lookupLLVMIntrinsicByName(ArrayRef<const char *> NameTable,
                                               StringRef Name) {
  assert(Name.startswith("llvm."));

  // Do successive binary searches of the dotted name components. For
  // "llvm.gc.experimental.statepoint.p1i8.p1i32", we will find the range of
  // intrinsics starting with "llvm.gc", then "llvm.gc.experimental", then
  // "llvm.gc.experimental.statepoint", and then we will stop as the range is
  // size 1. During the search, we can skip the prefix that we already know is
  // identical. By using strncmp we consider names with differing suffixes to
  // be part of the equal range.
  size_t CmpStart = 0;
  size_t CmpEnd = 4; // Skip the "llvm" component.
  const char *const *Low = NameTable.begin();
  const char *const *High = NameTable.end();
  const char *const *LastLow = Low;
  while (CmpEnd < Name.size() && High - Low > 0) {
    CmpStart = CmpEnd;
    CmpEnd = Name.find('.', CmpStart + 1);
    CmpEnd = CmpEnd == StringRef::npos ? Name.size() : CmpEnd;
    auto Cmp = [CmpStart, CmpEnd](const char *LHS, const char *RHS) {
      return strncmp(LHS + CmpStart, RHS + CmpStart, CmpEnd - CmpStart) < 0;
    };
    LastLow = Low;
    std::tie(Low, High) = std::equal_range(Low, High, Name.data(), Cmp);
  }
  if (High - Low > 0)
    LastLow = Low;

  if (LastLow == NameTable.end())
    return -1;
  StringRef NameFound = *LastLow;
  if (Name == NameFound ||
      (Name.startswith(NameFound) && Name[NameFound.size()] == '.'))
    return LastLow - NameTable.begin();
  return -1;
}

Value *InstrProfIncrementInst::getStep() const {
  if (InstrProfIncrementInstStep::classof(this)) {
    return const_cast<Value *>(getArgOperand(4));
  }
  const Module *M = getModule();
  LLVMContext &Context = M->getContext();
  return ConstantInt::get(Type::getInt64Ty(Context), 1);
}

ConstrainedFPIntrinsic::RoundingMode
ConstrainedFPIntrinsic::getRoundingMode() const {
  unsigned NumOperands = getNumArgOperands();
  Metadata *MD =
      dyn_cast<MetadataAsValue>(getArgOperand(NumOperands - 2))->getMetadata();
  if (!MD || !isa<MDString>(MD))
    return rmInvalid;
  StringRef RoundingArg = cast<MDString>(MD)->getString();

  // For dynamic rounding mode, we use round to nearest but we will set the
  // 'exact' SDNodeFlag so that the value will not be rounded.
  return StringSwitch<RoundingMode>(RoundingArg)
    .Case("round.dynamic",    rmDynamic)
    .Case("round.tonearest",  rmToNearest)
    .Case("round.downward",   rmDownward)
    .Case("round.upward",     rmUpward)
    .Case("round.towardzero", rmTowardZero)
    .Default(rmInvalid);
}

ConstrainedFPIntrinsic::ExceptionBehavior
ConstrainedFPIntrinsic::getExceptionBehavior() const {
  unsigned NumOperands = getNumArgOperands();
  Metadata *MD =
      dyn_cast<MetadataAsValue>(getArgOperand(NumOperands - 1))->getMetadata();
  if (!MD || !isa<MDString>(MD))
    return ebInvalid;
  StringRef ExceptionArg = cast<MDString>(MD)->getString();
  return StringSwitch<ExceptionBehavior>(ExceptionArg)
    .Case("fpexcept.ignore",  ebIgnore)
    .Case("fpexcept.maytrap", ebMayTrap)
    .Case("fpexcept.strict",  ebStrict)
    .Default(ebInvalid);
}

CmpInst::Predicate
VPIntrinsic::getCmpPredicate() const {
  return static_cast<CmpInst::Predicate>(cast<ConstantInt>(getArgOperand(4))->getZExtValue());
}

bool VPIntrinsic::isUnaryOp() const {
  switch (getIntrinsicID()) {
    default:
      return false;
    case Intrinsic::vp_fneg:
      return true;
  }
}

Value*
VPIntrinsic::getMask() const {
  if (isBinaryOp()) { return getArgOperand(2); }
  else if (isTernaryOp()) { return getArgOperand(3); }
  else if (isUnaryOp()) { return getArgOperand(1); }
  else return nullptr;
}

Value*
VPIntrinsic::getVectorLength() const {
  if (isBinaryOp()) { return getArgOperand(3); }
  else if (isTernaryOp()) { return getArgOperand(4); }
  else if (isUnaryOp()) { return getArgOperand(2); }
  else return nullptr;
}

bool VPIntrinsic::isReductionOp() const {
  switch (getIntrinsicID()) {
    default:
      return false;

    case Intrinsic::vp_reduce_and:
    case Intrinsic::vp_reduce_or:
    case Intrinsic::vp_reduce_xor:

    case Intrinsic::vp_reduce_add:
    case Intrinsic::vp_reduce_mul:
    case Intrinsic::vp_reduce_fadd:
    case Intrinsic::vp_reduce_fmul:

    case Intrinsic::vp_reduce_fmin:
    case Intrinsic::vp_reduce_fmax:
    case Intrinsic::vp_reduce_smin:
    case Intrinsic::vp_reduce_smax:
    case Intrinsic::vp_reduce_umin:
    case Intrinsic::vp_reduce_umax:

      return true;
  }
}


bool VPIntrinsic::isBinaryOp() const {
  switch (getIntrinsicID()) {
    default:
      return false;

    case Intrinsic::vp_and:
    case Intrinsic::vp_or:
    case Intrinsic::vp_xor:
    case Intrinsic::vp_ashr:
    case Intrinsic::vp_lshr:
    case Intrinsic::vp_shl:

    case Intrinsic::vp_fadd:
    case Intrinsic::vp_fsub:
    case Intrinsic::vp_fmul:
    case Intrinsic::vp_fdiv:
    case Intrinsic::vp_frem:

    case Intrinsic::vp_reduce_or:
    case Intrinsic::vp_reduce_xor:
    case Intrinsic::vp_reduce_add:
    case Intrinsic::vp_reduce_mul:
    case Intrinsic::vp_reduce_smax:
    case Intrinsic::vp_reduce_smin:
    case Intrinsic::vp_reduce_umax:
    case Intrinsic::vp_reduce_umin:

    case Intrinsic::vp_reduce_fadd:
    case Intrinsic::vp_reduce_fmul:
    case Intrinsic::vp_reduce_fmax:
    case Intrinsic::vp_reduce_fmin:

    case Intrinsic::vp_add:
    case Intrinsic::vp_sub:
    case Intrinsic::vp_mul:
    case Intrinsic::vp_udiv:
    case Intrinsic::vp_sdiv:
    case Intrinsic::vp_urem:
    case Intrinsic::vp_srem:
      return true;
  }
}

bool VPIntrinsic::isTernaryOp() const {
  switch (getIntrinsicID()) {
    default:
      return false;
    case Intrinsic::vp_fma:
    case Intrinsic::vp_select:
      return true;
  }
}

VPIntrinsic::VPIntrinsicDesc
VPIntrinsic::GetVPIntrinsicDesc(unsigned OC) {
  switch (OC) {
    // fp unary
    case Instruction::FNeg: return VPIntrinsicDesc{ Intrinsic::vp_fneg, TypeTokenVec{VPTypeToken::Vector}, 1, 2}; break;

    // fp binary
    case Instruction::FAdd: return VPIntrinsicDesc{ Intrinsic::vp_fadd, TypeTokenVec{VPTypeToken::Vector}, 2, 3}; break;
    case Instruction::FSub: return VPIntrinsicDesc{ Intrinsic::vp_fsub, TypeTokenVec{VPTypeToken::Vector}, 2, 3}; break;
    case Instruction::FMul: return VPIntrinsicDesc{ Intrinsic::vp_fmul, TypeTokenVec{VPTypeToken::Vector}, 2, 3}; break;
    case Instruction::FDiv: return VPIntrinsicDesc{ Intrinsic::vp_fdiv, TypeTokenVec{VPTypeToken::Vector}, 2, 3}; break;
    case Instruction::FRem: return VPIntrinsicDesc{ Intrinsic::vp_frem, TypeTokenVec{VPTypeToken::Vector}, 2, 3}; break;

    // sign-oblivious int
    case Instruction::Add:  return VPIntrinsicDesc{ Intrinsic::vp_add, TypeTokenVec{VPTypeToken::Vector}, 2, 3}; break;
    case Instruction::Sub:  return VPIntrinsicDesc{ Intrinsic::vp_sub, TypeTokenVec{VPTypeToken::Vector}, 2, 3}; break;
    case Instruction::Mul:  return VPIntrinsicDesc{ Intrinsic::vp_mul, TypeTokenVec{VPTypeToken::Vector}, 2, 3}; break;

    // signed/unsigned int
    case Instruction::SDiv: return VPIntrinsicDesc{ Intrinsic::vp_sdiv, TypeTokenVec{VPTypeToken::Vector}, 2, 3}; break;
    case Instruction::UDiv: return VPIntrinsicDesc{ Intrinsic::vp_udiv, TypeTokenVec{VPTypeToken::Vector}, 2, 3}; break;
    case Instruction::SRem: return VPIntrinsicDesc{ Intrinsic::vp_srem, TypeTokenVec{VPTypeToken::Vector}, 2, 3}; break;
    case Instruction::URem: return VPIntrinsicDesc{ Intrinsic::vp_urem, TypeTokenVec{VPTypeToken::Vector}, 2, 3}; break;

    // logical
    case Instruction::Or:   return VPIntrinsicDesc{ Intrinsic::vp_or,  TypeTokenVec{VPTypeToken::Vector}, 2, 3}; break;
    case Instruction::And:  return VPIntrinsicDesc{ Intrinsic::vp_and, TypeTokenVec{VPTypeToken::Vector}, 2, 3}; break;
    case Instruction::Xor:  return VPIntrinsicDesc{ Intrinsic::vp_xor, TypeTokenVec{VPTypeToken::Vector}, 2, 3}; break;

    case Instruction::LShr: return VPIntrinsicDesc{ Intrinsic::vp_lshr, TypeTokenVec{VPTypeToken::Vector}, 2, 3}; break;
    case Instruction::AShr: return VPIntrinsicDesc{ Intrinsic::vp_ashr, TypeTokenVec{VPTypeToken::Vector}, 2, 3}; break;
    case Instruction::Shl:  return VPIntrinsicDesc{ Intrinsic::vp_shl,  TypeTokenVec{VPTypeToken::Vector}, 2, 3}; break;

    // comparison
    case Instruction::ICmp:
    case Instruction::FCmp:
      return VPIntrinsicDesc{ Intrinsic::vp_cmp, TypeTokenVec{VPTypeToken::Mask, VPTypeToken::Vector}, 2, 3}; break;

  default:
    return VPIntrinsicDesc{Intrinsic::not_intrinsic, TypeTokenVec(), -1, -1};
  }
}

VPIntrinsic::ShortTypeVec
VPIntrinsic::EncodeTypeTokens(VPIntrinsic::TypeTokenVec TTVec, Type & VectorTy, Type & ScalarTy) {
  ShortTypeVec STV;

  for (auto Token : TTVec) {
    switch (Token) {
    default:
      llvm_unreachable("unsupported token"); // unsupported VPTypeToken

    case VPIntrinsic::VPTypeToken::Scalar: STV.push_back(&ScalarTy); break;
    case VPIntrinsic::VPTypeToken::Vector: STV.push_back(&VectorTy); break;
    case VPIntrinsic::VPTypeToken::Mask:
      auto NumElems = VectorTy.getVectorNumElements();
      auto MaskTy = VectorType::get(Type::getInt1Ty(VectorTy.getContext()), NumElems);
      STV.push_back(MaskTy); break;
    }
  }

  return STV;
}


bool ConstrainedFPIntrinsic::isUnaryOp() const {
  switch (getIntrinsicID()) {
    default:
      return false;
    case Intrinsic::experimental_constrained_sqrt:
    case Intrinsic::experimental_constrained_sin:
    case Intrinsic::experimental_constrained_cos:
    case Intrinsic::experimental_constrained_exp:
    case Intrinsic::experimental_constrained_exp2:
    case Intrinsic::experimental_constrained_log:
    case Intrinsic::experimental_constrained_log10:
    case Intrinsic::experimental_constrained_log2:
    case Intrinsic::experimental_constrained_rint:
    case Intrinsic::experimental_constrained_nearbyint:
    case Intrinsic::experimental_constrained_ceil:
    case Intrinsic::experimental_constrained_floor:
    case Intrinsic::experimental_constrained_round:
    case Intrinsic::experimental_constrained_trunc:
      return true;
  }
}

bool ConstrainedFPIntrinsic::isTernaryOp() const {
  switch (getIntrinsicID()) {
    default:
      return false;
    case Intrinsic::experimental_constrained_fma:
      return true;
  }
}

Instruction::BinaryOps WithOverflowInst::getBinaryOp() const {
  switch (getIntrinsicID()) {
    case Intrinsic::uadd_with_overflow:
    case Intrinsic::sadd_with_overflow:
      return Instruction::Add;
    case Intrinsic::usub_with_overflow:
    case Intrinsic::ssub_with_overflow:
      return Instruction::Sub;
    case Intrinsic::umul_with_overflow:
    case Intrinsic::smul_with_overflow:
      return Instruction::Mul;
    default:
      llvm_unreachable("Invalid intrinsic");
  }
}

bool WithOverflowInst::isSigned() const {
  switch (getIntrinsicID()) {
    case Intrinsic::sadd_with_overflow:
    case Intrinsic::ssub_with_overflow:
    case Intrinsic::smul_with_overflow:
      return true;
    default:
      return false;
  }
}

unsigned WithOverflowInst::getNoWrapKind() const {
  if (isSigned())
    return OverflowingBinaryOperator::NoSignedWrap;
  else
    return OverflowingBinaryOperator::NoUnsignedWrap;
}
