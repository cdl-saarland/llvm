#ifndef LLVM_IR_EVLBUILDER_H
#define LLVM_IR_EVLBUILDER_H

#include <llvm/IR/IRBuilder.h>
#include <llvm/IR/Value.h>
#include <llvm/IR/Instruction.h>

namespace llvm {

enum class EVLTypeToken : int8_t {
  Scalar = 1, // scalar operand type
  Vector = 2, // vectorized operand type
  Mask = 3    // vector mask type
};

using TypeTokenVec = SmallVector<EVLTypeToken, 4>;
using ShortTypeVec = SmallVector<Type*, 4>;
using ShortValueVec = SmallVector<Value*, 4>;

struct
EVLIntrinsicDesc {
  Intrinsic::ID ID; // LLVM Intrinsic ID.
  TypeTokenVec typeTokens; // Type Parmeters for the LLVM Intrinsic.
  int MaskPos; // Parameter index of the Mask parameter.
  int EVLPos; // Parameter index of the EVL parameter.
};

using ValArray = ArrayRef<Value*>;

class EVLBuilder {
  IRBuilder<> & Builder;
  // Explicit mask parameter
  Value * Mask;
  // Explicit vector length parameter
  Value * ExplicitVectorLength;
  // Compile-time vector length
  int StaticVectorLength;

  // get a vlaid mask/evl argument for the current predication contet
  Value& GetMaskForType(VectorType & VecTy);
  Value& GetEVLForType(VectorType & VecTy);

public:
  EVLBuilder(IRBuilder<> & _builder)
  : Builder(_builder)
  , Mask(nullptr)
  , ExplicitVectorLength(nullptr)
  , StaticVectorLength(-1)
  {}

  Module & getModule() const;

  // The cannonical vector type for this \p ElementTy
  VectorType& getVectorType(Type &ElementTy);

  // Predication context tracker
  EVLBuilder& setMask(Value * _Mask) { Mask = _Mask;  return *this; }
  EVLBuilder& setEVL(Value * _ExplicitVectorLength) { ExplicitVectorLength = _ExplicitVectorLength; return *this; }
  EVLBuilder& setStaticVL(int VLen) { StaticVectorLength = VLen; return *this; }

  EVLIntrinsicDesc GetEVLIntrinsicDesc(unsigned OC);

  // Create a map-vectorized copy of the instruction \p Inst with the underlying IRBuilder instance.
  // This operation may return nullptr if the instruction could not be vectorized.
  Value* CreateVectorCopy(Instruction & Inst, ValArray VecOpArray);

  Value& CreateGEP(ValArray VecOpArray);

  Value& CreateFAdd(ValArray VecOpArray);
  Value& CreateFDiv(ValArray VecOpArray);
  Value& CreateFMul(ValArray VecOpArray);
  Value& CreateFSub(ValArray VecOpArray);

  // Memory
  Value& CreateContiguousStore(Value & Val, Value & Pointer);
  Value& CreateContiguousLoad(Value & Pointer);
  Value& CreateScatter(Value & Val, Value & PointerVec);
  Value& CreateGather(Value & PointerVec);
};


} // namespace llvm

#endif // LLVM_IR_EVLBUILDER_H
