; NOTE: Assertions have been autogenerated by utils/update_llc_test_checks.py
; RUN: llc -mtriple=x86_64-- < %s -pre-RA-sched=list-ilp    | FileCheck %s --check-prefix=ILP
; RUN: llc -mtriple=x86_64-- < %s -pre-RA-sched=list-hybrid | FileCheck %s --check-prefix=HYBRID
; RUN: llc -mtriple=x86_64-- < %s -pre-RA-sched=list-burr   | FileCheck %s --check-prefix=BURR
; RUN: llc -mtriple=x86_64-- < %s -pre-RA-sched=source      | FileCheck %s --check-prefix=SRC
; FIXME: Fix machine verifier issues and remove -verify-machineinstrs=0. PR39452.
; RUN: llc -mtriple=x86_64-- < %s -pre-RA-sched=linearize -verify-machineinstrs=0 | FileCheck %s --check-prefix=LIN

; PR22304 https://llvm.org/bugs/show_bug.cgi?id=22304
; Tests checking backtracking in source scheduler. llc used to crash on them.

define i256 @test1(i256 %a) nounwind {
; ILP-LABEL: test1:
; ILP:       # %bb.0:
; ILP-NEXT:    pushq %r14
; ILP-NEXT:    pushq %rbx
; ILP-NEXT:    movq %rdi, %rax
; ILP-NEXT:    xorl %r8d, %r8d
; ILP-NEXT:    addb %sil, %sil
; ILP-NEXT:    addb $2, %sil
; ILP-NEXT:    orb $1, %sil
; ILP-NEXT:    movl $1, %r10d
; ILP-NEXT:    xorl %r14d, %r14d
; ILP-NEXT:    movl %esi, %ecx
; ILP-NEXT:    shldq %cl, %r10, %r14
; ILP-NEXT:    movl $1, %edx
; ILP-NEXT:    shlq %cl, %rdx
; ILP-NEXT:    movb $-128, %r11b
; ILP-NEXT:    subb %sil, %r11b
; ILP-NEXT:    leal -128(%rsi), %r9d
; ILP-NEXT:    xorl %edi, %edi
; ILP-NEXT:    movl %r9d, %ecx
; ILP-NEXT:    shldq %cl, %r10, %rdi
; ILP-NEXT:    movl $1, %ebx
; ILP-NEXT:    shlq %cl, %rbx
; ILP-NEXT:    movl %r11d, %ecx
; ILP-NEXT:    shrdq %cl, %r8, %r10
; ILP-NEXT:    testb $64, %sil
; ILP-NEXT:    cmovneq %rdx, %r14
; ILP-NEXT:    cmovneq %r8, %rdx
; ILP-NEXT:    testb $64, %r11b
; ILP-NEXT:    cmovneq %r8, %r10
; ILP-NEXT:    testb $64, %r9b
; ILP-NEXT:    cmovneq %rbx, %rdi
; ILP-NEXT:    cmovneq %r8, %rbx
; ILP-NEXT:    testb %sil, %sil
; ILP-NEXT:    cmovsq %r8, %r14
; ILP-NEXT:    cmovsq %r8, %rdx
; ILP-NEXT:    movq %r14, 8(%rax)
; ILP-NEXT:    movq %rdx, (%rax)
; ILP-NEXT:    cmovnsq %r8, %rdi
; ILP-NEXT:    cmoveq %r8, %rdi
; ILP-NEXT:    movq %rdi, 24(%rax)
; ILP-NEXT:    cmovnsq %r10, %rbx
; ILP-NEXT:    cmoveq %r8, %rbx
; ILP-NEXT:    movq %rbx, 16(%rax)
; ILP-NEXT:    popq %rbx
; ILP-NEXT:    popq %r14
; ILP-NEXT:    retq
;
; HYBRID-LABEL: test1:
; HYBRID:       # %bb.0:
; HYBRID-NEXT:    movq %rdi, %rax
; HYBRID-NEXT:    addb %sil, %sil
; HYBRID-NEXT:    addb $2, %sil
; HYBRID-NEXT:    orb $1, %sil
; HYBRID-NEXT:    movb $-128, %cl
; HYBRID-NEXT:    subb %sil, %cl
; HYBRID-NEXT:    xorl %r8d, %r8d
; HYBRID-NEXT:    movl $1, %r11d
; HYBRID-NEXT:    movl $1, %r9d
; HYBRID-NEXT:    shrdq %cl, %r8, %r9
; HYBRID-NEXT:    testb $64, %cl
; HYBRID-NEXT:    cmovneq %r8, %r9
; HYBRID-NEXT:    xorl %r10d, %r10d
; HYBRID-NEXT:    movl %esi, %ecx
; HYBRID-NEXT:    shldq %cl, %r11, %r10
; HYBRID-NEXT:    leal -128(%rsi), %ecx
; HYBRID-NEXT:    xorl %edi, %edi
; HYBRID-NEXT:    shldq %cl, %r11, %rdi
; HYBRID-NEXT:    movl $1, %edx
; HYBRID-NEXT:    shlq %cl, %rdx
; HYBRID-NEXT:    testb $64, %cl
; HYBRID-NEXT:    cmovneq %rdx, %rdi
; HYBRID-NEXT:    cmovneq %r8, %rdx
; HYBRID-NEXT:    movl %esi, %ecx
; HYBRID-NEXT:    shlq %cl, %r11
; HYBRID-NEXT:    testb $64, %sil
; HYBRID-NEXT:    cmovneq %r11, %r10
; HYBRID-NEXT:    cmovneq %r8, %r11
; HYBRID-NEXT:    testb %sil, %sil
; HYBRID-NEXT:    cmovsq %r8, %r10
; HYBRID-NEXT:    movq %r10, 8(%rax)
; HYBRID-NEXT:    cmovsq %r8, %r11
; HYBRID-NEXT:    movq %r11, (%rax)
; HYBRID-NEXT:    cmovnsq %r8, %rdi
; HYBRID-NEXT:    cmoveq %r8, %rdi
; HYBRID-NEXT:    movq %rdi, 24(%rax)
; HYBRID-NEXT:    cmovnsq %r9, %rdx
; HYBRID-NEXT:    cmoveq %r8, %rdx
; HYBRID-NEXT:    movq %rdx, 16(%rax)
; HYBRID-NEXT:    retq
;
; BURR-LABEL: test1:
; BURR:       # %bb.0:
; BURR-NEXT:    movq %rdi, %rax
; BURR-NEXT:    addb %sil, %sil
; BURR-NEXT:    addb $2, %sil
; BURR-NEXT:    orb $1, %sil
; BURR-NEXT:    movb $-128, %cl
; BURR-NEXT:    subb %sil, %cl
; BURR-NEXT:    xorl %r8d, %r8d
; BURR-NEXT:    movl $1, %r11d
; BURR-NEXT:    movl $1, %r9d
; BURR-NEXT:    shrdq %cl, %r8, %r9
; BURR-NEXT:    testb $64, %cl
; BURR-NEXT:    cmovneq %r8, %r9
; BURR-NEXT:    xorl %r10d, %r10d
; BURR-NEXT:    movl %esi, %ecx
; BURR-NEXT:    shldq %cl, %r11, %r10
; BURR-NEXT:    leal -128(%rsi), %ecx
; BURR-NEXT:    xorl %edi, %edi
; BURR-NEXT:    shldq %cl, %r11, %rdi
; BURR-NEXT:    movl $1, %edx
; BURR-NEXT:    shlq %cl, %rdx
; BURR-NEXT:    testb $64, %cl
; BURR-NEXT:    cmovneq %rdx, %rdi
; BURR-NEXT:    cmovneq %r8, %rdx
; BURR-NEXT:    movl %esi, %ecx
; BURR-NEXT:    shlq %cl, %r11
; BURR-NEXT:    testb $64, %sil
; BURR-NEXT:    cmovneq %r11, %r10
; BURR-NEXT:    cmovneq %r8, %r11
; BURR-NEXT:    testb %sil, %sil
; BURR-NEXT:    cmovsq %r8, %r10
; BURR-NEXT:    movq %r10, 8(%rax)
; BURR-NEXT:    cmovsq %r8, %r11
; BURR-NEXT:    movq %r11, (%rax)
; BURR-NEXT:    cmovnsq %r8, %rdi
; BURR-NEXT:    cmoveq %r8, %rdi
; BURR-NEXT:    movq %rdi, 24(%rax)
; BURR-NEXT:    cmovnsq %r9, %rdx
; BURR-NEXT:    cmoveq %r8, %rdx
; BURR-NEXT:    movq %rdx, 16(%rax)
; BURR-NEXT:    retq
;
; SRC-LABEL: test1:
; SRC:       # %bb.0:
; SRC-NEXT:    pushq %rbx
; SRC-NEXT:    movq %rdi, %rax
; SRC-NEXT:    addb %sil, %sil
; SRC-NEXT:    addb $2, %sil
; SRC-NEXT:    orb $1, %sil
; SRC-NEXT:    movb $-128, %cl
; SRC-NEXT:    subb %sil, %cl
; SRC-NEXT:    xorl %r8d, %r8d
; SRC-NEXT:    movl $1, %edi
; SRC-NEXT:    movl $1, %r10d
; SRC-NEXT:    shrdq %cl, %r8, %r10
; SRC-NEXT:    testb $64, %cl
; SRC-NEXT:    cmovneq %r8, %r10
; SRC-NEXT:    leal -128(%rsi), %r9d
; SRC-NEXT:    xorl %edx, %edx
; SRC-NEXT:    movl %r9d, %ecx
; SRC-NEXT:    shldq %cl, %rdi, %rdx
; SRC-NEXT:    xorl %r11d, %r11d
; SRC-NEXT:    movl %esi, %ecx
; SRC-NEXT:    shldq %cl, %rdi, %r11
; SRC-NEXT:    movl $1, %ebx
; SRC-NEXT:    shlq %cl, %rbx
; SRC-NEXT:    testb $64, %sil
; SRC-NEXT:    cmovneq %rbx, %r11
; SRC-NEXT:    cmovneq %r8, %rbx
; SRC-NEXT:    movl %r9d, %ecx
; SRC-NEXT:    shlq %cl, %rdi
; SRC-NEXT:    testb $64, %r9b
; SRC-NEXT:    cmovneq %rdi, %rdx
; SRC-NEXT:    cmovneq %r8, %rdi
; SRC-NEXT:    testb %sil, %sil
; SRC-NEXT:    cmovnsq %r10, %rdi
; SRC-NEXT:    cmoveq %r8, %rdi
; SRC-NEXT:    cmovnsq %r8, %rdx
; SRC-NEXT:    cmoveq %r8, %rdx
; SRC-NEXT:    cmovsq %r8, %r11
; SRC-NEXT:    cmovsq %r8, %rbx
; SRC-NEXT:    movq %r11, 8(%rax)
; SRC-NEXT:    movq %rbx, (%rax)
; SRC-NEXT:    movq %rdx, 24(%rax)
; SRC-NEXT:    movq %rdi, 16(%rax)
; SRC-NEXT:    popq %rbx
; SRC-NEXT:    retq
;
; LIN-LABEL: test1:
; LIN:       # %bb.0:
; LIN-NEXT:    movq %rdi, %rax
; LIN-NEXT:    xorl %r9d, %r9d
; LIN-NEXT:    movl $1, %r8d
; LIN-NEXT:    addb %sil, %sil
; LIN-NEXT:    addb $2, %sil
; LIN-NEXT:    orb $1, %sil
; LIN-NEXT:    movl $1, %edx
; LIN-NEXT:    movl %esi, %ecx
; LIN-NEXT:    shlq %cl, %rdx
; LIN-NEXT:    testb $64, %sil
; LIN-NEXT:    movq %rdx, %rcx
; LIN-NEXT:    cmovneq %r9, %rcx
; LIN-NEXT:    testb %sil, %sil
; LIN-NEXT:    cmovsq %r9, %rcx
; LIN-NEXT:    movq %rcx, (%rdi)
; LIN-NEXT:    xorl %edi, %edi
; LIN-NEXT:    movl %esi, %ecx
; LIN-NEXT:    shldq %cl, %r8, %rdi
; LIN-NEXT:    cmovneq %rdx, %rdi
; LIN-NEXT:    cmovsq %r9, %rdi
; LIN-NEXT:    movq %rdi, 8(%rax)
; LIN-NEXT:    leal -128(%rsi), %r10d
; LIN-NEXT:    movl $1, %edx
; LIN-NEXT:    movl %r10d, %ecx
; LIN-NEXT:    shlq %cl, %rdx
; LIN-NEXT:    testb $64, %r10b
; LIN-NEXT:    movq %rdx, %rdi
; LIN-NEXT:    cmovneq %r9, %rdi
; LIN-NEXT:    movb $-128, %cl
; LIN-NEXT:    subb %sil, %cl
; LIN-NEXT:    movl $1, %esi
; LIN-NEXT:    shrdq %cl, %r9, %rsi
; LIN-NEXT:    testb $64, %cl
; LIN-NEXT:    cmovneq %r9, %rsi
; LIN-NEXT:    cmovsq %rdi, %rsi
; LIN-NEXT:    cmoveq %r9, %rsi
; LIN-NEXT:    movq %rsi, 16(%rax)
; LIN-NEXT:    xorl %esi, %esi
; LIN-NEXT:    movl %r10d, %ecx
; LIN-NEXT:    shldq %cl, %r8, %rsi
; LIN-NEXT:    cmovneq %rdx, %rsi
; LIN-NEXT:    cmovnsq %r9, %rsi
; LIN-NEXT:    cmoveq %r9, %rsi
; LIN-NEXT:    movq %rsi, 24(%rax)
; LIN-NEXT:    retq
  %b = add i256 %a, 1
  %m = shl i256 %b, 1
  %p = add i256 %m, 1
  %v = lshr i256 %b, %p
  %t = trunc i256 %v to i1
  %c = shl i256 1, %p
  %f = select i1 %t, i256 undef, i256 %c
  ret i256 %f
}

define i256 @test2(i256 %a) nounwind {
; ILP-LABEL: test2:
; ILP:       # %bb.0:
; ILP-NEXT:    movq %rdi, %rax
; ILP-NEXT:    xorl %edi, %edi
; ILP-NEXT:    movq %rsi, %r11
; ILP-NEXT:    negq %r11
; ILP-NEXT:    movl $0, %r10d
; ILP-NEXT:    sbbq %rdx, %r10
; ILP-NEXT:    movl $0, %r9d
; ILP-NEXT:    sbbq %rcx, %r9
; ILP-NEXT:    sbbq %r8, %rdi
; ILP-NEXT:    andq %rcx, %r9
; ILP-NEXT:    bsrq %r9, %rcx
; ILP-NEXT:    xorq $63, %rcx
; ILP-NEXT:    andq %r8, %rdi
; ILP-NEXT:    bsrq %rdi, %r8
; ILP-NEXT:    andq %rdx, %r10
; ILP-NEXT:    bsrq %r10, %rdx
; ILP-NEXT:    xorq $63, %r8
; ILP-NEXT:    addq $64, %rcx
; ILP-NEXT:    testq %rdi, %rdi
; ILP-NEXT:    movq $0, 24(%rax)
; ILP-NEXT:    movq $0, 16(%rax)
; ILP-NEXT:    movq $0, 8(%rax)
; ILP-NEXT:    cmovneq %r8, %rcx
; ILP-NEXT:    xorq $63, %rdx
; ILP-NEXT:    andq %rsi, %r11
; ILP-NEXT:    movl $127, %r8d
; ILP-NEXT:    bsrq %r11, %rsi
; ILP-NEXT:    cmoveq %r8, %rsi
; ILP-NEXT:    xorq $63, %rsi
; ILP-NEXT:    addq $64, %rsi
; ILP-NEXT:    testq %r10, %r10
; ILP-NEXT:    cmovneq %rdx, %rsi
; ILP-NEXT:    subq $-128, %rsi
; ILP-NEXT:    orq %r9, %rdi
; ILP-NEXT:    cmovneq %rcx, %rsi
; ILP-NEXT:    movq %rsi, (%rax)
; ILP-NEXT:    retq
;
; HYBRID-LABEL: test2:
; HYBRID:       # %bb.0:
; HYBRID-NEXT:    movq %rdi, %rax
; HYBRID-NEXT:    xorl %r9d, %r9d
; HYBRID-NEXT:    movq %rsi, %r11
; HYBRID-NEXT:    negq %r11
; HYBRID-NEXT:    movl $0, %r10d
; HYBRID-NEXT:    sbbq %rdx, %r10
; HYBRID-NEXT:    movl $0, %edi
; HYBRID-NEXT:    sbbq %rcx, %rdi
; HYBRID-NEXT:    sbbq %r8, %r9
; HYBRID-NEXT:    andq %r8, %r9
; HYBRID-NEXT:    bsrq %r9, %r8
; HYBRID-NEXT:    xorq $63, %r8
; HYBRID-NEXT:    andq %rcx, %rdi
; HYBRID-NEXT:    bsrq %rdi, %rcx
; HYBRID-NEXT:    xorq $63, %rcx
; HYBRID-NEXT:    addq $64, %rcx
; HYBRID-NEXT:    testq %r9, %r9
; HYBRID-NEXT:    cmovneq %r8, %rcx
; HYBRID-NEXT:    andq %rdx, %r10
; HYBRID-NEXT:    bsrq %r10, %rdx
; HYBRID-NEXT:    xorq $63, %rdx
; HYBRID-NEXT:    andq %rsi, %r11
; HYBRID-NEXT:    movl $127, %r8d
; HYBRID-NEXT:    bsrq %r11, %rsi
; HYBRID-NEXT:    cmoveq %r8, %rsi
; HYBRID-NEXT:    xorq $63, %rsi
; HYBRID-NEXT:    addq $64, %rsi
; HYBRID-NEXT:    testq %r10, %r10
; HYBRID-NEXT:    cmovneq %rdx, %rsi
; HYBRID-NEXT:    subq $-128, %rsi
; HYBRID-NEXT:    orq %r9, %rdi
; HYBRID-NEXT:    cmovneq %rcx, %rsi
; HYBRID-NEXT:    movq %rsi, (%rax)
; HYBRID-NEXT:    movq $0, 24(%rax)
; HYBRID-NEXT:    movq $0, 16(%rax)
; HYBRID-NEXT:    movq $0, 8(%rax)
; HYBRID-NEXT:    retq
;
; BURR-LABEL: test2:
; BURR:       # %bb.0:
; BURR-NEXT:    movq %rdi, %rax
; BURR-NEXT:    xorl %r9d, %r9d
; BURR-NEXT:    movq %rsi, %r11
; BURR-NEXT:    negq %r11
; BURR-NEXT:    movl $0, %r10d
; BURR-NEXT:    sbbq %rdx, %r10
; BURR-NEXT:    movl $0, %edi
; BURR-NEXT:    sbbq %rcx, %rdi
; BURR-NEXT:    sbbq %r8, %r9
; BURR-NEXT:    andq %r8, %r9
; BURR-NEXT:    bsrq %r9, %r8
; BURR-NEXT:    xorq $63, %r8
; BURR-NEXT:    andq %rcx, %rdi
; BURR-NEXT:    bsrq %rdi, %rcx
; BURR-NEXT:    xorq $63, %rcx
; BURR-NEXT:    addq $64, %rcx
; BURR-NEXT:    testq %r9, %r9
; BURR-NEXT:    cmovneq %r8, %rcx
; BURR-NEXT:    andq %rdx, %r10
; BURR-NEXT:    bsrq %r10, %rdx
; BURR-NEXT:    xorq $63, %rdx
; BURR-NEXT:    andq %rsi, %r11
; BURR-NEXT:    movl $127, %r8d
; BURR-NEXT:    bsrq %r11, %rsi
; BURR-NEXT:    cmoveq %r8, %rsi
; BURR-NEXT:    xorq $63, %rsi
; BURR-NEXT:    addq $64, %rsi
; BURR-NEXT:    testq %r10, %r10
; BURR-NEXT:    cmovneq %rdx, %rsi
; BURR-NEXT:    subq $-128, %rsi
; BURR-NEXT:    orq %r9, %rdi
; BURR-NEXT:    cmovneq %rcx, %rsi
; BURR-NEXT:    movq %rsi, (%rax)
; BURR-NEXT:    movq $0, 24(%rax)
; BURR-NEXT:    movq $0, 16(%rax)
; BURR-NEXT:    movq $0, 8(%rax)
; BURR-NEXT:    retq
;
; SRC-LABEL: test2:
; SRC:       # %bb.0:
; SRC-NEXT:    movq %rdi, %rax
; SRC-NEXT:    xorl %edi, %edi
; SRC-NEXT:    movq %rsi, %r11
; SRC-NEXT:    negq %r11
; SRC-NEXT:    movl $0, %r10d
; SRC-NEXT:    sbbq %rdx, %r10
; SRC-NEXT:    movl $0, %r9d
; SRC-NEXT:    sbbq %rcx, %r9
; SRC-NEXT:    sbbq %r8, %rdi
; SRC-NEXT:    andq %rdx, %r10
; SRC-NEXT:    andq %rcx, %r9
; SRC-NEXT:    andq %r8, %rdi
; SRC-NEXT:    andq %rsi, %r11
; SRC-NEXT:    bsrq %rdi, %rcx
; SRC-NEXT:    xorq $63, %rcx
; SRC-NEXT:    bsrq %r9, %rdx
; SRC-NEXT:    xorq $63, %rdx
; SRC-NEXT:    addq $64, %rdx
; SRC-NEXT:    testq %rdi, %rdi
; SRC-NEXT:    cmovneq %rcx, %rdx
; SRC-NEXT:    bsrq %r10, %rcx
; SRC-NEXT:    xorq $63, %rcx
; SRC-NEXT:    bsrq %r11, %r8
; SRC-NEXT:    movl $127, %esi
; SRC-NEXT:    cmovneq %r8, %rsi
; SRC-NEXT:    xorq $63, %rsi
; SRC-NEXT:    addq $64, %rsi
; SRC-NEXT:    testq %r10, %r10
; SRC-NEXT:    cmovneq %rcx, %rsi
; SRC-NEXT:    subq $-128, %rsi
; SRC-NEXT:    orq %r9, %rdi
; SRC-NEXT:    cmovneq %rdx, %rsi
; SRC-NEXT:    movq %rsi, (%rax)
; SRC-NEXT:    movq $0, 24(%rax)
; SRC-NEXT:    movq $0, 16(%rax)
; SRC-NEXT:    movq $0, 8(%rax)
; SRC-NEXT:    retq
;
; LIN-LABEL: test2:
; LIN:       # %bb.0:
; LIN-NEXT:    movq %rdi, %rax
; LIN-NEXT:    movq %rsi, %rdi
; LIN-NEXT:    negq %rdi
; LIN-NEXT:    andq %rsi, %rdi
; LIN-NEXT:    bsrq %rdi, %rsi
; LIN-NEXT:    movl $127, %edi
; LIN-NEXT:    cmovneq %rsi, %rdi
; LIN-NEXT:    xorq $63, %rdi
; LIN-NEXT:    addq $64, %rdi
; LIN-NEXT:    xorl %r9d, %r9d
; LIN-NEXT:    movl $0, %esi
; LIN-NEXT:    sbbq %rdx, %rsi
; LIN-NEXT:    andq %rdx, %rsi
; LIN-NEXT:    bsrq %rsi, %rdx
; LIN-NEXT:    xorq $63, %rdx
; LIN-NEXT:    testq %rsi, %rsi
; LIN-NEXT:    cmoveq %rdi, %rdx
; LIN-NEXT:    subq $-128, %rdx
; LIN-NEXT:    movl $0, %esi
; LIN-NEXT:    sbbq %rcx, %rsi
; LIN-NEXT:    andq %rcx, %rsi
; LIN-NEXT:    bsrq %rsi, %rcx
; LIN-NEXT:    xorq $63, %rcx
; LIN-NEXT:    addq $64, %rcx
; LIN-NEXT:    sbbq %r8, %r9
; LIN-NEXT:    andq %r8, %r9
; LIN-NEXT:    bsrq %r9, %rdi
; LIN-NEXT:    xorq $63, %rdi
; LIN-NEXT:    testq %r9, %r9
; LIN-NEXT:    cmoveq %rcx, %rdi
; LIN-NEXT:    orq %rsi, %r9
; LIN-NEXT:    cmoveq %rdx, %rdi
; LIN-NEXT:    movq %rdi, (%rax)
; LIN-NEXT:    movq $0, 8(%rax)
; LIN-NEXT:    movq $0, 16(%rax)
; LIN-NEXT:    movq $0, 24(%rax)
; LIN-NEXT:    retq
  %b = sub i256 0, %a
  %c = and i256 %b, %a
  %d = call i256 @llvm.ctlz.i256(i256 %c, i1 false)
  ret i256 %d
}

define i256 @test3(i256 %n) nounwind {
; ILP-LABEL: test3:
; ILP:       # %bb.0:
; ILP-NEXT:    movq %rdi, %rax
; ILP-NEXT:    xorl %r10d, %r10d
; ILP-NEXT:    movq %rsi, %r9
; ILP-NEXT:    negq %r9
; ILP-NEXT:    movl $0, %r11d
; ILP-NEXT:    sbbq %rdx, %r11
; ILP-NEXT:    movl $0, %edi
; ILP-NEXT:    sbbq %rcx, %rdi
; ILP-NEXT:    sbbq %r8, %r10
; ILP-NEXT:    notq %rcx
; ILP-NEXT:    andq %rdi, %rcx
; ILP-NEXT:    bsrq %rcx, %rdi
; ILP-NEXT:    notq %rdx
; ILP-NEXT:    andq %r11, %rdx
; ILP-NEXT:    xorq $63, %rdi
; ILP-NEXT:    notq %r8
; ILP-NEXT:    andq %r10, %r8
; ILP-NEXT:    bsrq %r8, %r10
; ILP-NEXT:    xorq $63, %r10
; ILP-NEXT:    addq $64, %rdi
; ILP-NEXT:    bsrq %rdx, %r11
; ILP-NEXT:    notq %rsi
; ILP-NEXT:    testq %r8, %r8
; ILP-NEXT:    movq $0, 24(%rax)
; ILP-NEXT:    movq $0, 16(%rax)
; ILP-NEXT:    movq $0, 8(%rax)
; ILP-NEXT:    cmovneq %r10, %rdi
; ILP-NEXT:    xorq $63, %r11
; ILP-NEXT:    andq %r9, %rsi
; ILP-NEXT:    movl $127, %r9d
; ILP-NEXT:    bsrq %rsi, %rsi
; ILP-NEXT:    cmoveq %r9, %rsi
; ILP-NEXT:    xorq $63, %rsi
; ILP-NEXT:    addq $64, %rsi
; ILP-NEXT:    testq %rdx, %rdx
; ILP-NEXT:    cmovneq %r11, %rsi
; ILP-NEXT:    subq $-128, %rsi
; ILP-NEXT:    orq %rcx, %r8
; ILP-NEXT:    cmovneq %rdi, %rsi
; ILP-NEXT:    movq %rsi, (%rax)
; ILP-NEXT:    retq
;
; HYBRID-LABEL: test3:
; HYBRID:       # %bb.0:
; HYBRID-NEXT:    pushq %rbx
; HYBRID-NEXT:    movq %rdi, %rax
; HYBRID-NEXT:    xorl %edi, %edi
; HYBRID-NEXT:    movq %rsi, %r9
; HYBRID-NEXT:    negq %r9
; HYBRID-NEXT:    movl $0, %r10d
; HYBRID-NEXT:    sbbq %rdx, %r10
; HYBRID-NEXT:    movl $0, %r11d
; HYBRID-NEXT:    sbbq %rcx, %r11
; HYBRID-NEXT:    sbbq %r8, %rdi
; HYBRID-NEXT:    notq %r8
; HYBRID-NEXT:    andq %rdi, %r8
; HYBRID-NEXT:    bsrq %r8, %rbx
; HYBRID-NEXT:    xorq $63, %rbx
; HYBRID-NEXT:    notq %rcx
; HYBRID-NEXT:    andq %r11, %rcx
; HYBRID-NEXT:    bsrq %rcx, %rdi
; HYBRID-NEXT:    xorq $63, %rdi
; HYBRID-NEXT:    addq $64, %rdi
; HYBRID-NEXT:    testq %r8, %r8
; HYBRID-NEXT:    cmovneq %rbx, %rdi
; HYBRID-NEXT:    notq %rdx
; HYBRID-NEXT:    andq %r10, %rdx
; HYBRID-NEXT:    bsrq %rdx, %rbx
; HYBRID-NEXT:    xorq $63, %rbx
; HYBRID-NEXT:    notq %rsi
; HYBRID-NEXT:    andq %r9, %rsi
; HYBRID-NEXT:    movl $127, %r9d
; HYBRID-NEXT:    bsrq %rsi, %rsi
; HYBRID-NEXT:    cmoveq %r9, %rsi
; HYBRID-NEXT:    xorq $63, %rsi
; HYBRID-NEXT:    addq $64, %rsi
; HYBRID-NEXT:    testq %rdx, %rdx
; HYBRID-NEXT:    cmovneq %rbx, %rsi
; HYBRID-NEXT:    subq $-128, %rsi
; HYBRID-NEXT:    orq %r8, %rcx
; HYBRID-NEXT:    cmovneq %rdi, %rsi
; HYBRID-NEXT:    movq %rsi, (%rax)
; HYBRID-NEXT:    movq $0, 24(%rax)
; HYBRID-NEXT:    movq $0, 16(%rax)
; HYBRID-NEXT:    movq $0, 8(%rax)
; HYBRID-NEXT:    popq %rbx
; HYBRID-NEXT:    retq
;
; BURR-LABEL: test3:
; BURR:       # %bb.0:
; BURR-NEXT:    pushq %rbx
; BURR-NEXT:    movq %rdi, %rax
; BURR-NEXT:    xorl %edi, %edi
; BURR-NEXT:    movq %rsi, %r9
; BURR-NEXT:    negq %r9
; BURR-NEXT:    movl $0, %r10d
; BURR-NEXT:    sbbq %rdx, %r10
; BURR-NEXT:    movl $0, %r11d
; BURR-NEXT:    sbbq %rcx, %r11
; BURR-NEXT:    sbbq %r8, %rdi
; BURR-NEXT:    notq %r8
; BURR-NEXT:    andq %rdi, %r8
; BURR-NEXT:    bsrq %r8, %rbx
; BURR-NEXT:    xorq $63, %rbx
; BURR-NEXT:    notq %rcx
; BURR-NEXT:    andq %r11, %rcx
; BURR-NEXT:    bsrq %rcx, %rdi
; BURR-NEXT:    xorq $63, %rdi
; BURR-NEXT:    addq $64, %rdi
; BURR-NEXT:    testq %r8, %r8
; BURR-NEXT:    cmovneq %rbx, %rdi
; BURR-NEXT:    notq %rdx
; BURR-NEXT:    andq %r10, %rdx
; BURR-NEXT:    bsrq %rdx, %rbx
; BURR-NEXT:    xorq $63, %rbx
; BURR-NEXT:    notq %rsi
; BURR-NEXT:    andq %r9, %rsi
; BURR-NEXT:    movl $127, %r9d
; BURR-NEXT:    bsrq %rsi, %rsi
; BURR-NEXT:    cmoveq %r9, %rsi
; BURR-NEXT:    xorq $63, %rsi
; BURR-NEXT:    addq $64, %rsi
; BURR-NEXT:    testq %rdx, %rdx
; BURR-NEXT:    cmovneq %rbx, %rsi
; BURR-NEXT:    subq $-128, %rsi
; BURR-NEXT:    orq %r8, %rcx
; BURR-NEXT:    cmovneq %rdi, %rsi
; BURR-NEXT:    movq %rsi, (%rax)
; BURR-NEXT:    movq $0, 24(%rax)
; BURR-NEXT:    movq $0, 16(%rax)
; BURR-NEXT:    movq $0, 8(%rax)
; BURR-NEXT:    popq %rbx
; BURR-NEXT:    retq
;
; SRC-LABEL: test3:
; SRC:       # %bb.0:
; SRC-NEXT:    movq %rdi, %rax
; SRC-NEXT:    movq %rsi, %r9
; SRC-NEXT:    notq %r9
; SRC-NEXT:    xorl %r10d, %r10d
; SRC-NEXT:    negq %rsi
; SRC-NEXT:    movl $0, %r11d
; SRC-NEXT:    sbbq %rdx, %r11
; SRC-NEXT:    notq %rdx
; SRC-NEXT:    movl $0, %edi
; SRC-NEXT:    sbbq %rcx, %rdi
; SRC-NEXT:    notq %rcx
; SRC-NEXT:    sbbq %r8, %r10
; SRC-NEXT:    notq %r8
; SRC-NEXT:    andq %r11, %rdx
; SRC-NEXT:    andq %rdi, %rcx
; SRC-NEXT:    andq %r10, %r8
; SRC-NEXT:    andq %r9, %rsi
; SRC-NEXT:    bsrq %r8, %r9
; SRC-NEXT:    xorq $63, %r9
; SRC-NEXT:    bsrq %rcx, %rdi
; SRC-NEXT:    xorq $63, %rdi
; SRC-NEXT:    addq $64, %rdi
; SRC-NEXT:    testq %r8, %r8
; SRC-NEXT:    cmovneq %r9, %rdi
; SRC-NEXT:    bsrq %rdx, %r9
; SRC-NEXT:    xorq $63, %r9
; SRC-NEXT:    bsrq %rsi, %r10
; SRC-NEXT:    movl $127, %esi
; SRC-NEXT:    cmovneq %r10, %rsi
; SRC-NEXT:    xorq $63, %rsi
; SRC-NEXT:    addq $64, %rsi
; SRC-NEXT:    testq %rdx, %rdx
; SRC-NEXT:    cmovneq %r9, %rsi
; SRC-NEXT:    subq $-128, %rsi
; SRC-NEXT:    orq %rcx, %r8
; SRC-NEXT:    cmovneq %rdi, %rsi
; SRC-NEXT:    movq %rsi, (%rax)
; SRC-NEXT:    movq $0, 24(%rax)
; SRC-NEXT:    movq $0, 16(%rax)
; SRC-NEXT:    movq $0, 8(%rax)
; SRC-NEXT:    retq
;
; LIN-LABEL: test3:
; LIN:       # %bb.0:
; LIN-NEXT:    movq %rdi, %rax
; LIN-NEXT:    movq %rsi, %rdi
; LIN-NEXT:    negq %rdi
; LIN-NEXT:    notq %rsi
; LIN-NEXT:    andq %rdi, %rsi
; LIN-NEXT:    bsrq %rsi, %rsi
; LIN-NEXT:    movl $127, %edi
; LIN-NEXT:    cmovneq %rsi, %rdi
; LIN-NEXT:    xorq $63, %rdi
; LIN-NEXT:    addq $64, %rdi
; LIN-NEXT:    xorl %r9d, %r9d
; LIN-NEXT:    movl $0, %esi
; LIN-NEXT:    sbbq %rdx, %rsi
; LIN-NEXT:    notq %rdx
; LIN-NEXT:    andq %rsi, %rdx
; LIN-NEXT:    bsrq %rdx, %rsi
; LIN-NEXT:    xorq $63, %rsi
; LIN-NEXT:    testq %rdx, %rdx
; LIN-NEXT:    cmoveq %rdi, %rsi
; LIN-NEXT:    subq $-128, %rsi
; LIN-NEXT:    movl $0, %edx
; LIN-NEXT:    sbbq %rcx, %rdx
; LIN-NEXT:    notq %rcx
; LIN-NEXT:    andq %rdx, %rcx
; LIN-NEXT:    bsrq %rcx, %rdx
; LIN-NEXT:    xorq $63, %rdx
; LIN-NEXT:    addq $64, %rdx
; LIN-NEXT:    sbbq %r8, %r9
; LIN-NEXT:    notq %r8
; LIN-NEXT:    andq %r9, %r8
; LIN-NEXT:    bsrq %r8, %rdi
; LIN-NEXT:    xorq $63, %rdi
; LIN-NEXT:    testq %r8, %r8
; LIN-NEXT:    cmoveq %rdx, %rdi
; LIN-NEXT:    orq %rcx, %r8
; LIN-NEXT:    cmoveq %rsi, %rdi
; LIN-NEXT:    movq %rdi, (%rax)
; LIN-NEXT:    movq $0, 8(%rax)
; LIN-NEXT:    movq $0, 16(%rax)
; LIN-NEXT:    movq $0, 24(%rax)
; LIN-NEXT:    retq
  %m = sub i256 -1, %n
  %x = sub i256 0, %n
  %y = and i256 %x, %m
  %z = call i256 @llvm.ctlz.i256(i256 %y, i1 false)
  ret i256 %z
}

declare i256 @llvm.ctlz.i256(i256, i1) nounwind readnone

define i64 @test4(i64 %a, i64 %b) nounwind {
; ILP-LABEL: test4:
; ILP:       # %bb.0:
; ILP-NEXT:    xorl %ecx, %ecx
; ILP-NEXT:    xorl %edx, %edx
; ILP-NEXT:    incq %rsi
; ILP-NEXT:    sete %dl
; ILP-NEXT:    movl $2, %eax
; ILP-NEXT:    cmpq %rdi, %rsi
; ILP-NEXT:    sbbq $0, %rdx
; ILP-NEXT:    movl $0, %edx
; ILP-NEXT:    sbbq %rdx, %rdx
; ILP-NEXT:    sbbq %rcx, %rcx
; ILP-NEXT:    setae %cl
; ILP-NEXT:    movzbl %cl, %ecx
; ILP-NEXT:    subq %rcx, %rax
; ILP-NEXT:    retq
;
; HYBRID-LABEL: test4:
; HYBRID:       # %bb.0:
; HYBRID-NEXT:    xorl %eax, %eax
; HYBRID-NEXT:    xorl %ecx, %ecx
; HYBRID-NEXT:    incq %rsi
; HYBRID-NEXT:    sete %cl
; HYBRID-NEXT:    cmpq %rdi, %rsi
; HYBRID-NEXT:    sbbq $0, %rcx
; HYBRID-NEXT:    movl $0, %ecx
; HYBRID-NEXT:    sbbq %rcx, %rcx
; HYBRID-NEXT:    sbbq %rax, %rax
; HYBRID-NEXT:    setae %al
; HYBRID-NEXT:    movzbl %al, %ecx
; HYBRID-NEXT:    movl $2, %eax
; HYBRID-NEXT:    subq %rcx, %rax
; HYBRID-NEXT:    retq
;
; BURR-LABEL: test4:
; BURR:       # %bb.0:
; BURR-NEXT:    xorl %eax, %eax
; BURR-NEXT:    xorl %ecx, %ecx
; BURR-NEXT:    incq %rsi
; BURR-NEXT:    sete %cl
; BURR-NEXT:    cmpq %rdi, %rsi
; BURR-NEXT:    sbbq $0, %rcx
; BURR-NEXT:    movl $0, %ecx
; BURR-NEXT:    sbbq %rcx, %rcx
; BURR-NEXT:    sbbq %rax, %rax
; BURR-NEXT:    setae %al
; BURR-NEXT:    movzbl %al, %ecx
; BURR-NEXT:    movl $2, %eax
; BURR-NEXT:    subq %rcx, %rax
; BURR-NEXT:    retq
;
; SRC-LABEL: test4:
; SRC:       # %bb.0:
; SRC-NEXT:    xorl %eax, %eax
; SRC-NEXT:    incq %rsi
; SRC-NEXT:    sete %al
; SRC-NEXT:    xorl %ecx, %ecx
; SRC-NEXT:    cmpq %rdi, %rsi
; SRC-NEXT:    sbbq $0, %rax
; SRC-NEXT:    movl $0, %eax
; SRC-NEXT:    sbbq %rax, %rax
; SRC-NEXT:    sbbq %rcx, %rcx
; SRC-NEXT:    setae %al
; SRC-NEXT:    movzbl %al, %ecx
; SRC-NEXT:    movl $2, %eax
; SRC-NEXT:    subq %rcx, %rax
; SRC-NEXT:    retq
;
; LIN-LABEL: test4:
; LIN:       # %bb.0:
; LIN-NEXT:    movl $2, %eax
; LIN-NEXT:    xorl %ecx, %ecx
; LIN-NEXT:    xorl %edx, %edx
; LIN-NEXT:    incq %rsi
; LIN-NEXT:    sete %dl
; LIN-NEXT:    cmpq %rdi, %rsi
; LIN-NEXT:    sbbq $0, %rdx
; LIN-NEXT:    movl $0, %edx
; LIN-NEXT:    sbbq %rdx, %rdx
; LIN-NEXT:    sbbq %rcx, %rcx
; LIN-NEXT:    setae %cl
; LIN-NEXT:    movzbl %cl, %ecx
; LIN-NEXT:    subq %rcx, %rax
; LIN-NEXT:    retq
  %r = zext i64 %b to i256
  %u = add i256 %r, 1
  %w = and i256 %u, 1461501637330902918203684832716283019655932542975
  %x = zext i64 %a to i256
  %c = icmp uge i256 %w, %x
  %y = select i1 %c, i64 0, i64 1
  %z = add i64 %y, 1
  ret i64 %z
}

define i256 @PR25498(i256 %a) nounwind {
; ILP-LABEL: PR25498:
; ILP:       # %bb.0:
; ILP-NEXT:    pushq %rbx
; ILP-NEXT:    movq %rdi, %rax
; ILP-NEXT:    xorl %r9d, %r9d
; ILP-NEXT:    movq %rsi, %rbx
; ILP-NEXT:    negq %rbx
; ILP-NEXT:    movl $0, %r11d
; ILP-NEXT:    sbbq %rdx, %r11
; ILP-NEXT:    movl $0, %r10d
; ILP-NEXT:    sbbq %rcx, %r10
; ILP-NEXT:    movl $0, %edi
; ILP-NEXT:    sbbq %r8, %rdi
; ILP-NEXT:    orq %r8, %rdx
; ILP-NEXT:    orq %rcx, %rsi
; ILP-NEXT:    orq %rdx, %rsi
; ILP-NEXT:    je .LBB4_1
; ILP-NEXT:  # %bb.2: # %cond.false
; ILP-NEXT:    bsrq %r11, %rdx
; ILP-NEXT:    bsrq %rdi, %rcx
; ILP-NEXT:    xorq $63, %rcx
; ILP-NEXT:    bsrq %r10, %rsi
; ILP-NEXT:    xorq $63, %rsi
; ILP-NEXT:    addq $64, %rsi
; ILP-NEXT:    testq %rdi, %rdi
; ILP-NEXT:    cmovneq %rcx, %rsi
; ILP-NEXT:    xorq $63, %rdx
; ILP-NEXT:    bsrq %rbx, %rcx
; ILP-NEXT:    xorq $63, %rcx
; ILP-NEXT:    addq $64, %rcx
; ILP-NEXT:    testq %r11, %r11
; ILP-NEXT:    cmovneq %rdx, %rcx
; ILP-NEXT:    subq $-128, %rcx
; ILP-NEXT:    xorl %r9d, %r9d
; ILP-NEXT:    orq %rdi, %r10
; ILP-NEXT:    cmovneq %rsi, %rcx
; ILP-NEXT:    jmp .LBB4_3
; ILP-NEXT:  .LBB4_1:
; ILP-NEXT:    movl $256, %ecx # imm = 0x100
; ILP-NEXT:  .LBB4_3: # %cond.end
; ILP-NEXT:    movq %rcx, (%rax)
; ILP-NEXT:    movq %r9, 8(%rax)
; ILP-NEXT:    movq %r9, 16(%rax)
; ILP-NEXT:    movq %r9, 24(%rax)
; ILP-NEXT:    popq %rbx
; ILP-NEXT:    retq
;
; HYBRID-LABEL: PR25498:
; HYBRID:       # %bb.0:
; HYBRID-NEXT:    pushq %rbx
; HYBRID-NEXT:    movq %rdi, %rax
; HYBRID-NEXT:    xorl %r9d, %r9d
; HYBRID-NEXT:    movq %rsi, %rbx
; HYBRID-NEXT:    negq %rbx
; HYBRID-NEXT:    movl $0, %r11d
; HYBRID-NEXT:    sbbq %rdx, %r11
; HYBRID-NEXT:    movl $0, %r10d
; HYBRID-NEXT:    sbbq %rcx, %r10
; HYBRID-NEXT:    movl $0, %edi
; HYBRID-NEXT:    sbbq %r8, %rdi
; HYBRID-NEXT:    orq %r8, %rdx
; HYBRID-NEXT:    orq %rcx, %rsi
; HYBRID-NEXT:    orq %rdx, %rsi
; HYBRID-NEXT:    je .LBB4_1
; HYBRID-NEXT:  # %bb.2: # %cond.false
; HYBRID-NEXT:    bsrq %rdi, %rcx
; HYBRID-NEXT:    xorq $63, %rcx
; HYBRID-NEXT:    bsrq %r10, %rdx
; HYBRID-NEXT:    xorq $63, %rdx
; HYBRID-NEXT:    addq $64, %rdx
; HYBRID-NEXT:    testq %rdi, %rdi
; HYBRID-NEXT:    cmovneq %rcx, %rdx
; HYBRID-NEXT:    bsrq %r11, %rsi
; HYBRID-NEXT:    xorq $63, %rsi
; HYBRID-NEXT:    bsrq %rbx, %rcx
; HYBRID-NEXT:    xorq $63, %rcx
; HYBRID-NEXT:    addq $64, %rcx
; HYBRID-NEXT:    testq %r11, %r11
; HYBRID-NEXT:    cmovneq %rsi, %rcx
; HYBRID-NEXT:    subq $-128, %rcx
; HYBRID-NEXT:    orq %rdi, %r10
; HYBRID-NEXT:    cmovneq %rdx, %rcx
; HYBRID-NEXT:    xorl %r9d, %r9d
; HYBRID-NEXT:    jmp .LBB4_3
; HYBRID-NEXT:  .LBB4_1:
; HYBRID-NEXT:    movl $256, %ecx # imm = 0x100
; HYBRID-NEXT:  .LBB4_3: # %cond.end
; HYBRID-NEXT:    movq %rcx, (%rax)
; HYBRID-NEXT:    movq %r9, 8(%rax)
; HYBRID-NEXT:    movq %r9, 16(%rax)
; HYBRID-NEXT:    movq %r9, 24(%rax)
; HYBRID-NEXT:    popq %rbx
; HYBRID-NEXT:    retq
;
; BURR-LABEL: PR25498:
; BURR:       # %bb.0:
; BURR-NEXT:    pushq %rbx
; BURR-NEXT:    movq %rdi, %rax
; BURR-NEXT:    xorl %r9d, %r9d
; BURR-NEXT:    movq %rsi, %rbx
; BURR-NEXT:    negq %rbx
; BURR-NEXT:    movl $0, %r11d
; BURR-NEXT:    sbbq %rdx, %r11
; BURR-NEXT:    movl $0, %r10d
; BURR-NEXT:    sbbq %rcx, %r10
; BURR-NEXT:    movl $0, %edi
; BURR-NEXT:    sbbq %r8, %rdi
; BURR-NEXT:    orq %r8, %rdx
; BURR-NEXT:    orq %rcx, %rsi
; BURR-NEXT:    orq %rdx, %rsi
; BURR-NEXT:    je .LBB4_1
; BURR-NEXT:  # %bb.2: # %cond.false
; BURR-NEXT:    bsrq %rdi, %rcx
; BURR-NEXT:    xorq $63, %rcx
; BURR-NEXT:    bsrq %r10, %rdx
; BURR-NEXT:    xorq $63, %rdx
; BURR-NEXT:    addq $64, %rdx
; BURR-NEXT:    testq %rdi, %rdi
; BURR-NEXT:    cmovneq %rcx, %rdx
; BURR-NEXT:    bsrq %r11, %rsi
; BURR-NEXT:    xorq $63, %rsi
; BURR-NEXT:    bsrq %rbx, %rcx
; BURR-NEXT:    xorq $63, %rcx
; BURR-NEXT:    addq $64, %rcx
; BURR-NEXT:    testq %r11, %r11
; BURR-NEXT:    cmovneq %rsi, %rcx
; BURR-NEXT:    subq $-128, %rcx
; BURR-NEXT:    orq %rdi, %r10
; BURR-NEXT:    cmovneq %rdx, %rcx
; BURR-NEXT:    xorl %r9d, %r9d
; BURR-NEXT:    jmp .LBB4_3
; BURR-NEXT:  .LBB4_1:
; BURR-NEXT:    movl $256, %ecx # imm = 0x100
; BURR-NEXT:  .LBB4_3: # %cond.end
; BURR-NEXT:    movq %rcx, (%rax)
; BURR-NEXT:    movq %r9, 8(%rax)
; BURR-NEXT:    movq %r9, 16(%rax)
; BURR-NEXT:    movq %r9, 24(%rax)
; BURR-NEXT:    popq %rbx
; BURR-NEXT:    retq
;
; SRC-LABEL: PR25498:
; SRC:       # %bb.0:
; SRC-NEXT:    pushq %rbx
; SRC-NEXT:    movq %rdi, %rax
; SRC-NEXT:    xorl %r9d, %r9d
; SRC-NEXT:    movq %rsi, %rbx
; SRC-NEXT:    negq %rbx
; SRC-NEXT:    movl $0, %r11d
; SRC-NEXT:    sbbq %rdx, %r11
; SRC-NEXT:    movl $0, %r10d
; SRC-NEXT:    sbbq %rcx, %r10
; SRC-NEXT:    movl $0, %edi
; SRC-NEXT:    sbbq %r8, %rdi
; SRC-NEXT:    orq %r8, %rdx
; SRC-NEXT:    orq %rcx, %rsi
; SRC-NEXT:    orq %rdx, %rsi
; SRC-NEXT:    je .LBB4_1
; SRC-NEXT:  # %bb.2: # %cond.false
; SRC-NEXT:    bsrq %rdi, %rcx
; SRC-NEXT:    xorq $63, %rcx
; SRC-NEXT:    bsrq %r10, %rdx
; SRC-NEXT:    xorq $63, %rdx
; SRC-NEXT:    addq $64, %rdx
; SRC-NEXT:    testq %rdi, %rdi
; SRC-NEXT:    cmovneq %rcx, %rdx
; SRC-NEXT:    bsrq %r11, %rsi
; SRC-NEXT:    xorq $63, %rsi
; SRC-NEXT:    bsrq %rbx, %rcx
; SRC-NEXT:    xorq $63, %rcx
; SRC-NEXT:    addq $64, %rcx
; SRC-NEXT:    testq %r11, %r11
; SRC-NEXT:    cmovneq %rsi, %rcx
; SRC-NEXT:    subq $-128, %rcx
; SRC-NEXT:    orq %rdi, %r10
; SRC-NEXT:    cmovneq %rdx, %rcx
; SRC-NEXT:    xorl %r9d, %r9d
; SRC-NEXT:    jmp .LBB4_3
; SRC-NEXT:  .LBB4_1:
; SRC-NEXT:    movl $256, %ecx # imm = 0x100
; SRC-NEXT:  .LBB4_3: # %cond.end
; SRC-NEXT:    movq %rcx, (%rax)
; SRC-NEXT:    movq %r9, 8(%rax)
; SRC-NEXT:    movq %r9, 16(%rax)
; SRC-NEXT:    movq %r9, 24(%rax)
; SRC-NEXT:    popq %rbx
; SRC-NEXT:    retq
;
; LIN-LABEL: PR25498:
; LIN:       # %bb.0:
; LIN-NEXT:    pushq %rbx
; LIN-NEXT:    movq %rdi, %rax
; LIN-NEXT:    movq %rsi, %rbx
; LIN-NEXT:    negq %rbx
; LIN-NEXT:    xorl %r9d, %r9d
; LIN-NEXT:    movl $0, %edi
; LIN-NEXT:    sbbq %rdx, %rdi
; LIN-NEXT:    movl $0, %r10d
; LIN-NEXT:    sbbq %rcx, %r10
; LIN-NEXT:    movl $0, %r11d
; LIN-NEXT:    sbbq %r8, %r11
; LIN-NEXT:    orq %rcx, %rsi
; LIN-NEXT:    orq %r8, %rdx
; LIN-NEXT:    orq %rsi, %rdx
; LIN-NEXT:    je .LBB4_1
; LIN-NEXT:  # %bb.2: # %cond.false
; LIN-NEXT:    bsrq %rbx, %rcx
; LIN-NEXT:    xorq $63, %rcx
; LIN-NEXT:    addq $64, %rcx
; LIN-NEXT:    bsrq %rdi, %rdx
; LIN-NEXT:    xorq $63, %rdx
; LIN-NEXT:    testq %rdi, %rdi
; LIN-NEXT:    cmoveq %rcx, %rdx
; LIN-NEXT:    subq $-128, %rdx
; LIN-NEXT:    bsrq %r10, %rsi
; LIN-NEXT:    xorq $63, %rsi
; LIN-NEXT:    addq $64, %rsi
; LIN-NEXT:    bsrq %r11, %rcx
; LIN-NEXT:    xorq $63, %rcx
; LIN-NEXT:    testq %r11, %r11
; LIN-NEXT:    cmoveq %rsi, %rcx
; LIN-NEXT:    orq %r11, %r10
; LIN-NEXT:    cmoveq %rdx, %rcx
; LIN-NEXT:    xorl %r9d, %r9d
; LIN-NEXT:    jmp .LBB4_3
; LIN-NEXT:  .LBB4_1:
; LIN-NEXT:    movl $256, %ecx # imm = 0x100
; LIN-NEXT:  .LBB4_3: # %cond.end
; LIN-NEXT:    movq %rcx, (%rax)
; LIN-NEXT:    movq %r9, 8(%rax)
; LIN-NEXT:    movq %r9, 16(%rax)
; LIN-NEXT:    movq %r9, 24(%rax)
; LIN-NEXT:    popq %rbx
; LIN-NEXT:    retq
  %b = sub i256 0, %a
  %cmpz = icmp eq i256 %b, 0
  br i1 %cmpz, label %cond.end, label %cond.false

cond.false:
  %d = call i256 @llvm.ctlz.i256(i256 %b, i1 true)
  br label %cond.end

cond.end:
  %ctz = phi i256 [ 256, %0 ], [ %d, %cond.false ]
  ret i256 %ctz
}

