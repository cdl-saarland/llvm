//===-- llvm/PredicatedInst.h - Predication utility subclass --*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file defines various classes for working with Instructions and
// ConstantExprs.
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_IR_OPERATOR_H
#define LLVM_IR_OPERATOR_H

#include "llvm/ADT/None.h"
#include "llvm/ADT/Optional.h"
#include "llvm/IR/Constants.h"
#include "llvm/IR/Instruction.h"
#include "llvm/IR/Type.h"
#include "llvm/IR/Value.h"
#include "llvm/Support/Casting.h"
#include "llvm/IR/IntrinsicInst.h"
#include <cstddef>

namespace llvm {

class PredicatedInstruction : public User {
public:
  // The PredicatedInstruction class is intended to be used as a utility, and is never itself
  // instantiated.
  PredicatedInstruction() = delete;
  ~PredicatedInstruction() = delete;

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

  static bool classof(const Instruction * I) { return isa<Instruction>(I); }
  static bool classof(const ConstantExpr * CE) { return false; }
  static bool classof(const Value *V) { return isa<ConstantExpr>(V) || isa<Instruction>(V): }
};

class PredicatedOperator : public User {
public:
  // The PredicatedOperator class is intended to be used as a utility, and is never itself
  // instantiated.
  PredicatedOperator() = delete;
  ~PredicatedOperator() = delete;

  void *operator new(size_t s) = delete;

  /// Return the opcode for this Instruction or ConstantExpr.
  unsigned getOpcode() const {
    auto * EVLInst = dyn_cast<EVLIntrinsic>(I);
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

  static bool classof(const Instruction * I) { return isa<EVLIntrinsic>(I) || isa<Operator>(I); }
  static bool classof(const ConstantExpr * CE) { return isa<Operator>(CE); }
  static bool classof(const Value *V) { return isa<EVLIntrinsic>(V) || isa<Operator>(V): }
};

class PredicatedBinaryOperator : public PredicatedOperator {
public:
  // The PredicatedBinaryOperator class is intended to be used as a utility, and is never itself
  // instantiated.
  PredicatedBinaryOperator() = delete;
  ~PredicatedBinaryOperator() = delete;

  void *operator new(size_t s) = delete;

  static bool classof(const Instruction * I) {
    if (isa<BinaryOperator>(I)) return true;
    auto EVLInst = dyn_cast<EVLInstrinsic>(I);
    return EVLInst && EVLInst->isBinaryOp();
  }
  static bool classof(const ConstantExpr * CE) { return isa<BinaryOperator>(CE); }
  static bool classof(const Value *V) {
    auto * I = dyn_cast<Instruction>(V);
    if (I && classof(I)) return true;
    return isa<ConstantExpr>(V);
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
    auto EVLInst = dyn_cast<EVLInstrinsic>(I);
    return EVLInst && EVLInst->gisBinaryOp();
  }
  static bool classof(const ConstantExpr * CE) { return isa<BinaryOperator>(CE); }
  static bool classof(const Value *V) {
    auto * I = dyn_cast<Instruction>(V);
    if (I && classof(I)) return true;
    return isa<ConstantExpr>(V);
  }
}


class PredicatedFCmpInst : public PredicatedBinaryOperator {
public:
  // The Operator class is intended to be used as a utility, and is never itself
  // instantiated.
  PredicatedFCmpInst() = delete;
  ~PredicatedFCmpInst() = delete;

  void *operator new(size_t s) = delete;
}

}
