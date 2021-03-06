{-# LANGUAGE FlexibleContexts #-}
-- | Variation of "Futhark.CodeGen.ImpCode" that contains the notion
-- of a kernel invocation.
module Futhark.CodeGen.ImpCode.Kernels
  ( Program
  , Function
  , FunctionT (Function)
  , Code
  , KernelCode
  , KernelConst (..)
  , KernelConstExp
  , HostOp (..)
  , KernelOp (..)
  , Fence (..)
  , AtomicOp (..)
  , Kernel (..)
  , KernelUse (..)
  , module Futhark.CodeGen.ImpCode
  , module Futhark.Representation.Kernels.Sizes
  -- * Utility functions
  , atomicBinOp
  )
  where

import Futhark.CodeGen.ImpCode hiding (Function, Code)
import qualified Futhark.CodeGen.ImpCode as Imp
import Futhark.Representation.Kernels.Sizes
import Futhark.Representation.AST.Attributes.Names
import Futhark.Representation.AST.Pretty ()
import Futhark.Util.Pretty

type Program = Imp.Definitions HostOp
type Function = Imp.Function HostOp
-- | Host-level code that can call kernels.
type Code = Imp.Code HostOp
-- | Code inside a kernel.
type KernelCode = Imp.Code KernelOp

-- | A run-time constant related to kernels.
newtype KernelConst = SizeConst Name
                    deriving (Eq, Ord, Show)

-- | An expression whose variables are kernel constants.
type KernelConstExp = PrimExp KernelConst

data HostOp = CallKernel Kernel
            | GetSize VName Name SizeClass
            | CmpSizeLe VName Name SizeClass Imp.Exp
            | GetSizeMax VName SizeClass
            deriving (Show)

-- | A generic kernel containing arbitrary kernel code.
data Kernel = Kernel
              { kernelBody :: Imp.Code KernelOp

              , kernelUses :: [KernelUse]
                -- ^ The host variables referenced by the kernel.

              , kernelNumGroups :: [Imp.Exp]
              , kernelGroupSize :: [Imp.Exp]
              , kernelName :: Name
               -- ^ A short descriptive and _unique_ name - should be
               -- alphanumeric and without spaces.

              , kernelFailureTolerant :: Bool
                -- ^ If true, this kernel does not need for check
                -- whether we are in a failing state, as it can cope.
                -- Intuitively, it means that the kernel does not
                -- depend on any non-scalar parameters to make control
                -- flow decisions.  Replication, transpose, and copy
                -- kernels are examples of this.
              }
            deriving (Show)

data KernelUse = ScalarUse VName PrimType
               | MemoryUse VName
               | ConstUse VName KernelConstExp
                 deriving (Eq, Show)

-- | Get an atomic operator corresponding to a binary operator.
atomicBinOp :: BinOp -> Maybe (VName -> VName -> Count Elements Imp.Exp -> Exp -> AtomicOp)
atomicBinOp = flip lookup [ (Add Int32, AtomicAdd)
                          , (SMax Int32, AtomicSMax)
                          , (SMin Int32, AtomicSMin)
                          , (UMax Int32, AtomicUMax)
                          , (UMin Int32, AtomicUMin)
                          , (And Int32, AtomicAnd)
                          , (Or Int32, AtomicOr)
                          , (Xor Int32, AtomicXor)
                          ]

instance Pretty KernelConst where
  ppr (SizeConst key) = text "get_size" <> parens (ppr key)

instance Pretty KernelUse where
  ppr (ScalarUse name t) =
    oneLine $ text "scalar_copy" <> parens (commasep [ppr name, ppr t])
  ppr (MemoryUse name) =
    oneLine $ text "mem_copy" <> parens (commasep [ppr name])
  ppr (ConstUse name e) =
    oneLine $ text "const" <> parens (commasep [ppr name, ppr e])

instance Pretty HostOp where
  ppr (GetSize dest key size_class) =
    ppr dest <+> text "<-" <+>
    text "get_size" <> parens (commasep [ppr key, ppr size_class])
  ppr (GetSizeMax dest size_class) =
    ppr dest <+> text "<-" <+> text "get_size_max" <> parens (ppr size_class)
  ppr (CmpSizeLe dest name size_class x) =
    ppr dest <+> text "<-" <+>
    text "get_size" <> parens (commasep [ppr name, ppr size_class]) <+>
    text "<" <+> ppr x
  ppr (CallKernel c) =
    ppr c

instance FreeIn HostOp where
  freeIn' (CallKernel c) =
    freeIn' c
  freeIn' (CmpSizeLe dest _ _ x) =
    freeIn' dest <> freeIn' x
  freeIn' (GetSizeMax dest _) =
    freeIn' dest
  freeIn' (GetSize dest _ _) =
    freeIn' dest

instance FreeIn Kernel where
  freeIn' kernel = freeIn' (kernelBody kernel) <>
                   freeIn' [kernelNumGroups kernel, kernelGroupSize kernel]

instance Pretty Kernel where
  ppr kernel =
    text "kernel" <+> brace
    (text "groups" <+> brace (ppr $ kernelNumGroups kernel) </>
     text "group_size" <+> brace (ppr $ kernelGroupSize kernel) </>
     text "uses" <+> brace (commasep $ map ppr $ kernelUses kernel) </>
     text "failure_tolerant" <+> ppr (kernelFailureTolerant kernel) </>
     text "body" <+> brace (ppr $ kernelBody kernel))

-- | When we do a barrier or fence, is it at the local or global
-- level?
data Fence = FenceLocal | FenceGlobal
           deriving (Show)

data KernelOp = GetGroupId VName Int
              | GetLocalId VName Int
              | GetLocalSize VName Int
              | GetGlobalSize VName Int
              | GetGlobalId VName Int
              | GetLockstepWidth VName
              | Atomic Space AtomicOp
              | Barrier Fence
              | MemFence Fence
              | LocalAlloc VName (Count Bytes Imp.Exp)
              | ErrorSync Fence
                -- ^ Perform a barrier and also check whether any
                -- threads have failed an assertion.  Make sure all
                -- threads would reach all 'ErrorSync's if any of them
                -- do.  A failing assertion will jump to the next
                -- following 'ErrorSync', so make sure it's not inside
                -- control flow or similar.
              deriving (Show)

-- Atomic operations return the value stored before the update.
-- This value is stored in the first VName.
data AtomicOp = AtomicAdd VName VName (Count Elements Imp.Exp) Exp
              | AtomicSMax VName VName (Count Elements Imp.Exp) Exp
              | AtomicSMin VName VName (Count Elements Imp.Exp) Exp
              | AtomicUMax VName VName (Count Elements Imp.Exp) Exp
              | AtomicUMin VName VName (Count Elements Imp.Exp) Exp
              | AtomicAnd VName VName (Count Elements Imp.Exp) Exp
              | AtomicOr VName VName (Count Elements Imp.Exp) Exp
              | AtomicXor VName VName (Count Elements Imp.Exp) Exp
              | AtomicCmpXchg VName VName (Count Elements Imp.Exp) Exp Exp
              | AtomicXchg VName VName (Count Elements Imp.Exp) Exp
              deriving (Show)

instance FreeIn AtomicOp where
  freeIn' (AtomicAdd _ arr i x) = freeIn' arr <> freeIn' i <> freeIn' x
  freeIn' (AtomicSMax _ arr i x) = freeIn' arr <> freeIn' i <> freeIn' x
  freeIn' (AtomicSMin _ arr i x) = freeIn' arr <> freeIn' i <> freeIn' x
  freeIn' (AtomicUMax _ arr i x) = freeIn' arr <> freeIn' i <> freeIn' x
  freeIn' (AtomicUMin _ arr i x) = freeIn' arr <> freeIn' i <> freeIn' x
  freeIn' (AtomicAnd _ arr i x) = freeIn' arr <> freeIn' i <> freeIn' x
  freeIn' (AtomicOr _ arr i x) = freeIn' arr <> freeIn' i <> freeIn' x
  freeIn' (AtomicXor _ arr i x) = freeIn' arr <> freeIn' i <> freeIn' x
  freeIn' (AtomicCmpXchg _ arr i x y) = freeIn' arr <> freeIn' i <> freeIn' x <> freeIn' y
  freeIn' (AtomicXchg _ arr i x) = freeIn' arr <> freeIn' i <> freeIn' x

instance Pretty KernelOp where
  ppr (GetGroupId dest i) =
    ppr dest <+> text "<-" <+>
    text "get_group_id" <> parens (ppr i)
  ppr (GetLocalId dest i) =
    ppr dest <+> text "<-" <+>
    text "get_local_id" <> parens (ppr i)
  ppr (GetLocalSize dest i) =
    ppr dest <+> text "<-" <+>
    text "get_local_size" <> parens (ppr i)
  ppr (GetGlobalSize dest i) =
    ppr dest <+> text "<-" <+>
    text "get_global_size" <> parens (ppr i)
  ppr (GetGlobalId dest i) =
    ppr dest <+> text "<-" <+>
    text "get_global_id" <> parens (ppr i)
  ppr (GetLockstepWidth dest) =
    ppr dest <+> text "<-" <+>
    text "get_lockstep_width()"
  ppr (Barrier FenceLocal) =
    text "local_barrier()"
  ppr (Barrier FenceGlobal) =
    text "global_barrier()"
  ppr (MemFence FenceLocal) =
    text "mem_fence_local()"
  ppr (MemFence FenceGlobal) =
    text "mem_fence_global()"
  ppr (LocalAlloc name size) =
    ppr name <+> equals <+> text "local_alloc" <> parens (ppr size)
  ppr (ErrorSync FenceLocal) =
    text "error_sync_local()"
  ppr (ErrorSync FenceGlobal) =
    text "error_sync_global()"
  ppr (Atomic _ (AtomicAdd old arr ind x)) =
    ppr old <+> text "<-" <+> text "atomic_add" <>
    parens (commasep [ppr arr <> brackets (ppr ind), ppr x])
  ppr (Atomic _ (AtomicSMax old arr ind x)) =
    ppr old <+> text "<-" <+> text "atomic_smax" <>
    parens (commasep [ppr arr <> brackets (ppr ind), ppr x])
  ppr (Atomic _ (AtomicSMin old arr ind x)) =
    ppr old <+> text "<-" <+> text "atomic_smin" <>
    parens (commasep [ppr arr <> brackets (ppr ind), ppr x])
  ppr (Atomic _ (AtomicUMax old arr ind x)) =
    ppr old <+> text "<-" <+> text "atomic_umax" <>
    parens (commasep [ppr arr <> brackets (ppr ind), ppr x])
  ppr (Atomic _ (AtomicUMin old arr ind x)) =
    ppr old <+> text "<-" <+> text "atomic_umin" <>
    parens (commasep [ppr arr <> brackets (ppr ind), ppr x])
  ppr (Atomic _ (AtomicAnd old arr ind x)) =
    ppr old <+> text "<-" <+> text "atomic_and" <>
    parens (commasep [ppr arr <> brackets (ppr ind), ppr x])
  ppr (Atomic _ (AtomicOr old arr ind x)) =
    ppr old <+> text "<-" <+> text "atomic_or" <>
    parens (commasep [ppr arr <> brackets (ppr ind), ppr x])
  ppr (Atomic _ (AtomicXor old arr ind x)) =
    ppr old <+> text "<-" <+> text "atomic_xor" <>
    parens (commasep [ppr arr <> brackets (ppr ind), ppr x])
  ppr (Atomic _ (AtomicCmpXchg old arr ind x y)) =
    ppr old <+> text "<-" <+> text "atomic_cmp_xchg" <>
    parens (commasep [ppr arr <> brackets (ppr ind), ppr x, ppr y])
  ppr (Atomic _ (AtomicXchg old arr ind x)) =
    ppr old <+> text "<-" <+> text "atomic_xchg" <>
    parens (commasep [ppr arr <> brackets (ppr ind), ppr x])

instance FreeIn KernelOp where
  freeIn' (Atomic _ op) = freeIn' op
  freeIn' _ = mempty

brace :: Doc -> Doc
brace body = text " {" </> indent 2 body </> text "}"
