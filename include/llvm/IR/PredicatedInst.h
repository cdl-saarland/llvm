//===-- llvm/PredicatedInst.h - Predication utility subclass --*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file defines various classes for working with Predicated Instructions.
// Predicated instructions are either regular instructions or calls to
// Explicit Vector Length (EVL) intrinsics that have a mask and an explicit
// vector length argument.
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_IR_PREDICATEDINST_H
#define LLVM_IR_PREDICATEDINST_H

#include "llvm/ADT/None.h"
#include "llvm/ADT/Optional.h"
#include "llvm/IR/Constants.h"
#include "llvm/IR/Instruction.h"
#include "llvm/IR/Type.h"
#include "llvm/IR/Value.h"
#include "llvm/Support/Casting.h"
#include "llvm/IR/IntrinsicInst.h"
#include "llvm/IR/Operator.h"
#include "llvm/IR/MatcherCast.h"

#include <cstddef>

namespace llvm {

class BasicBlock;

class PredicatedInstruction : public User {
public:
  // The PredicatedInstruction class is intended to be used as a utility, and is never itself
  // instantiated.
  PredicatedInstruction() = delete;
  ~PredicatedInstruction() = delete;

  void copyIRFlags(const Value * V, bool IncludeWrapFlags) {
    cast<Instruction>(this)->copyIRFlags(V, IncludeWrapFlags);
  }

  BasicBlock* getParent() { return cast<Instruction>(this)->getParent(); }
  const BasicBlock* getParent() const { return cast<const Instruction>(this)->getParent(); }

  void *operator new(size_t s) = delete;

  Value* getMask() const {
    auto thisEVL = dyn_cast<EVLIntrinsic>(this);
    if (!thisEVL) return nullptr;
    return thisEVL->getMask();
  }

  Value* getVectorLength() const {
    auto thisEVL = dyn_cast<EVLIntrinsic>(this);
    if (!thisEVL) return nullptr;
    return thisEVL->getVectorLength();
  }

  unsigned getOpcode() const {
    auto * EVLInst = dyn_cast<EVLIntrinsic>(this);
    if (EVLInst)
      return EVLInst->getFunctionalOpcode();
    return cast<Instruction>(this)->getOpcode();
  }

#if 0
  operator Instruction() { return cast<Value>(this); }
  operator const Value() const { return cast<const Value>(this); }
#endif

  static bool classof(const Instruction * I) { return isa<Instruction>(I); }
  static bool classof(const ConstantExpr * CE) { return false; }
  static bool classof(const Value *V) { return isa<Instruction>(V); }
};

class PredicatedOperator : public User {
public:
  // The PredicatedOperator class is intended to be used as a utility, and is never itself
  // instantiated.
  PredicatedOperator() = delete;
  ~PredicatedOperator() = delete;

  void *operator new(size_t s) = delete;

#if 0
  operator Value*() { return cast<Value>(this); }
  operator const Value*() const { return cast<const Value>(this); }
#endif

  /// Return the opcode for this Instruction or ConstantExpr.
  unsigned getOpcode() const {
    auto * EVLInst = dyn_cast<EVLIntrinsic>(this);
    if (EVLInst)
      return EVLInst->getFunctionalOpcode();
    if (const Instruction *I = dyn_cast<Instruction>(this))
      return I->getOpcode();
    return cast<ConstantExpr>(this)->getOpcode();
  }

  Value* getMask() const {
    auto thisEVL = dyn_cast<EVLIntrinsic>(this);
    if (!thisEVL) return nullptr;
    return thisEVL->getMask();
  }

  Value* getVectorLength() const {
    auto thisEVL = dyn_cast<EVLIntrinsic>(this);
    if (!thisEVL) return nullptr;
    return thisEVL->getVectorLength();
  }

  void copyIRFlags(const Value * V, bool IncludeWrapFlags = true);
  FastMathFlags getFastMathFlags() const {
    auto * I = dyn_cast<Instruction>(this);
    if (I) return I->getFastMathFlags();
    else return FastMathFlags();
  }

  static bool classof(const Instruction * I) { return isa<EVLIntrinsic>(I) || isa<Operator>(I); }
  static bool classof(const ConstantExpr * CE) { return isa<Operator>(CE); }
  static bool classof(const Value *V) { return isa<EVLIntrinsic>(V) || isa<Operator>(V); }
};

class PredicatedBinaryOperator : public PredicatedOperator {
public:
  // The PredicatedBinaryOperator class is intended to be used as a utility, and is never itself
  // instantiated.
  PredicatedBinaryOperator() = delete;
  ~PredicatedBinaryOperator() = delete;

  using BinaryOps = Instruction::BinaryOps;

  void *operator new(size_t s) = delete;

  static bool classof(const Instruction * I) {
    if (isa<BinaryOperator>(I)) return true;
    auto EVLInst = dyn_cast<EVLIntrinsic>(I);
    return EVLInst && EVLInst->isBinaryOp();
  }
  static bool classof(const ConstantExpr * CE) { return isa<BinaryOperator>(CE); }
  static bool classof(const Value *V) {
    auto * I = dyn_cast<Instruction>(V);
    if (I && classof(I)) return true;
    auto * CE = dyn_cast<ConstantExpr>(V);
    return CE && classof(CE);
  }

  /// Construct a predicated binary instruction, given the opcode and the two
  /// operands.
  static Instruction* Create(Module * Mod,
                                   Value *Mask, Value *VectorLen,
                                   Instruction::BinaryOps Opc,
                                   Value *V1, Value *V2,
                                   const Twine &Name,
                                   BasicBlock * InsertAtEnd,
                                   Instruction * InsertBefore);

  static Instruction* Create(Module *Mod,
                                          Value *Mask, Value *VectorLen,
                                          BinaryOps Opc,
                                          Value *V1, Value *V2,
                                          const Twine &Name = Twine(),
                                          Instruction *InsertBefore = nullptr) {
    return Create(Mod, Mask, VectorLen, Opc, V1, V2, Name, nullptr, InsertBefore);
  }

  static Instruction* Create(Module *Mod,
                                          Value *Mask, Value *VectorLen,
                                          BinaryOps Opc,
                                          Value *V1, Value *V2,
                                          const Twine &Name,
                                          BasicBlock *InsertAtEnd) {
    return Create(Mod, Mask, VectorLen, Opc, V1, V2, Name, InsertAtEnd, nullptr);
  }

  static Instruction* CreateWithCopiedFlags(Module *Mod,
                                                         Value *Mask, Value* VectorLen,
                                                         BinaryOps Opc,
                                                         Value *V1, Value *V2,
                                                         Instruction *CopyBO,
                                                         const Twine &Name = "") {
    Instruction *BO = Create(Mod, Mask, VectorLen, Opc, V1, V2, Name, nullptr, nullptr);
    BO->copyIRFlags(CopyBO);
    return BO;
  }
};

class PredicatedICmpInst : public PredicatedBinaryOperator {
public:
  // The Operator class is intended to be used as a utility, and is never itself
  // instantiated.
  PredicatedICmpInst() = delete;
  ~PredicatedICmpInst() = delete;

  void *operator new(size_t s) = delete;

  static bool classof(const Instruction * I) {
    if (isa<ICmpInst>(I)) return true;
    auto EVLInst = dyn_cast<EVLIntrinsic>(I);
    return EVLInst && EVLInst->getFunctionalOpcode() == Instruction::ICmp;
  }
  static bool classof(const ConstantExpr * CE) { return CE->getOpcode() == Instruction::ICmp; }
  static bool classof(const Value *V) {
    auto * I = dyn_cast<Instruction>(V);
    if (I && classof(I)) return true;
    auto * CE = dyn_cast<ConstantExpr>(V);
    return CE && classof(CE);
  }

  ICmpInst::Predicate getPredicate() const {
    auto * ICInst = dyn_cast<const ICmpInst>(this);
    if (ICInst) return ICInst->getPredicate();
    auto * CE = dyn_cast<const ConstantExpr>(this);
    if (CE) return static_cast<ICmpInst::Predicate>(CE->getPredicate());
    return static_cast<ICmpInst::Predicate>(cast<EVLIntrinsic>(this)->getCmpPredicate());
  }
};


class PredicatedFCmpInst : public PredicatedBinaryOperator {
public:
  // The Operator class is intended to be used as a utility, and is never itself
  // instantiated.
  PredicatedFCmpInst() = delete;
  ~PredicatedFCmpInst() = delete;

  void *operator new(size_t s) = delete;

  static bool classof(const Instruction * I) {
    if (isa<FCmpInst>(I)) return true;
    auto EVLInst = dyn_cast<EVLIntrinsic>(I);
    return EVLInst && EVLInst->getFunctionalOpcode() == Instruction::FCmp;
  }
  static bool classof(const ConstantExpr * CE) { return CE->getOpcode() == Instruction::FCmp; }
  static bool classof(const Value *V) {
    auto * I = dyn_cast<Instruction>(V);
    if (I && classof(I)) return true;
    return isa<ConstantExpr>(V);
  }

  FCmpInst::Predicate getPredicate() const {
    auto * FCInst = dyn_cast<const FCmpInst>(this);
    if (FCInst) return FCInst->getPredicate();
    auto * CE = dyn_cast<const ConstantExpr>(this);
    if (CE) return static_cast<FCmpInst::Predicate>(CE->getPredicate());
    return static_cast<FCmpInst::Predicate>(cast<EVLIntrinsic>(this)->getCmpPredicate());
  }
};


class PredicatedSelectInst : public PredicatedOperator {
public:
  // The Operator class is intended to be used as a utility, and is never itself
  // instantiated.
  PredicatedSelectInst() = delete;
  ~PredicatedSelectInst() = delete;

  void *operator new(size_t s) = delete;

  static bool classof(const Instruction * I) {
    if (isa<SelectInst>(I)) return true;
    auto EVLInst = dyn_cast<EVLIntrinsic>(I);
    return EVLInst && EVLInst->getFunctionalOpcode() == Instruction::Select;
  }
  static bool classof(const ConstantExpr * CE) { return CE->getOpcode() == Instruction::Select; }
  static bool classof(const Value *V) {
    auto * I = dyn_cast<Instruction>(V);
    if (I && classof(I)) return true;
    auto * CE = dyn_cast<ConstantExpr>(V);
    return CE && CE->getOpcode() == Instruction::Select;
  }

  const Value *getCondition() const { return getOperand(0); }
  const Value *getTrueValue() const { return getOperand(1); }
  const Value *getFalseValue() const { return getOperand(2); }
  Value *getCondition() { return getOperand(0); }
  Value *getTrueValue() { return getOperand(1); }
  Value *getFalseValue() { return getOperand(2); }

  void setCondition(Value *V) { setOperand(0, V); }
  void setTrueValue(Value *V) { setOperand(1, V); }
  void setFalseValue(Value *V) { setOperand(2, V); }
};


namespace PatternMatch {

// PredicatedMatchContext for pattern matching
struct PredicatedContext {
  Value * Mask;
  Value * VectorLength;
  Module * Mod;

  void reset(Value * V) {
    auto * PI = dyn_cast<PredicatedInstruction>(V);
    if (!PI) {
      VectorLength = nullptr;
      Mask = nullptr;
      Mod = nullptr;
    } else {
      VectorLength = PI->getVectorLength();
      Mask = PI->getMask();
      Mod = PI->getParent()->getParent()->getParent();
    }
  }

  PredicatedContext(Value * Val)
  : Mask(nullptr)
  , VectorLength(nullptr)
  , Mod(nullptr)
  {
    reset(Val);
  }

  PredicatedContext(const PredicatedContext & PC)
  : Mask (PC.Mask)
  , VectorLength(PC.VectorLength)
  , Mod(nullptr)
  {}

  // accept a match where \p Val is in a non-leaf position in a match pattern
  bool acceptInnerNode(const Value * Val) const {
    auto PredI = dyn_cast<PredicatedInstruction>(Val);
    if (!PredI) return VectorLength == nullptr && Mask == nullptr;
    return VectorLength == PredI->getVectorLength() && Mask == PredI->getMask();
  }

  // accept a match where \p Val is bound to a free variable.
  bool acceptBoundNode(const Value * Val) const { return true; }

  // whether this context is compatiable with \p E.
  bool acceptContext(PredicatedContext PC) const {
    return PC.Mask == Mask && PC.VectorLength == VectorLength;
  }

  // merge the context \p E into this context and return whether the resulting context is valid.
  bool mergeContext(PredicatedContext PC) const { return acceptContext(PC); }

  // match \p P in a new contest for \p Val.
  template <typename Val, typename Pattern> bool reset_match(Val *V, const Pattern &P) {
    reset(V);
    return const_cast<Pattern &>(P).match_context(V, *this);
  }

  // match \p P in the current context.
  template <typename Val, typename Pattern> bool try_match(Val *V, const Pattern &P) {
    PredicatedContext SubContext(*this);
    return const_cast<Pattern &>(P).match_context(V, SubContext);
  }
};

struct PredicatedContext;
template<> struct MatcherCast<PredicatedContext, BinaryOperator> { using ActualCastType = PredicatedBinaryOperator; };
template<> struct MatcherCast<PredicatedContext, Operator>       { using ActualCastType = PredicatedOperator; };
template<> struct MatcherCast<PredicatedContext, ICmpInst>       { using ActualCastType = PredicatedICmpInst; };
template<> struct MatcherCast<PredicatedContext, FCmpInst>       { using ActualCastType = PredicatedFCmpInst; };
template<> struct MatcherCast<PredicatedContext, SelectInst>     { using ActualCastType = PredicatedSelectInst; };
template<> struct MatcherCast<PredicatedContext, Instruction>    { using ActualCastType = PredicatedInstruction; };

} // namespace PatternMatch

} // namespace llvm

#endif // LLVM_IR_PREDICATEDINST_H
