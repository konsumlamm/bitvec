{-# LANGUAGE CPP        #-}
{-# LANGUAGE RankNTypes #-}

#ifndef BITVEC_THREADSAFE
module Tests.SetOps where
#else
module Tests.SetOpsTS where
#endif

import Support ()

import Control.Monad
import Control.Monad.ST
import Data.Bit
import Data.Bits
import qualified Data.Vector.Unboxed as U
import qualified Data.Vector.Unboxed.Mutable as MU
import Test.Tasty
import Test.Tasty.QuickCheck hiding ((.&.))

setOpTests :: TestTree
setOpTests = testGroup
  "Set operations"
  [ testProperty "generalize"               prop_generalize
  , testProperty "zipBits"                  prop_zipBits
  , testProperty "zipInPlace"               prop_zipInPlace

  , testProperty "invertBits"               prop_invertBits
  , testProperty "invertBitsWords"          prop_invertBitsWords
  , testProperty "invertBits middle"        prop_invertBits_middle
  , testProperty "invertBitsLong middle"    prop_invertBitsLong_middle

  , testProperty "invertInPlace"            prop_invertInPlace
  , testProperty "invertInPlaceWords"       prop_invertInPlaceWords
  , testProperty "invertInPlace middle"     prop_invertInPlace_middle
  , testProperty "invertInPlaceLong middle" prop_invertInPlaceLong_middle

  , testProperty "reverseBits"               prop_reverseBits
  , testProperty "reverseBitsWords"          prop_reverseBitsWords
  , testProperty "reverseBits middle"        prop_reverseBits_middle
  , testProperty "reverseBitsLong middle"    prop_reverseBitsLong_middle

  , testProperty "reverseInPlace"            prop_reverseInPlace
  , testProperty "reverseInPlaceWords"       prop_reverseInPlaceWords
  , testProperty "reverseInPlace middle"     prop_reverseInPlace_middle
  , testProperty "reverseInPlaceLong middle" prop_reverseInPlaceLong_middle

  , testProperty "selectBits"                prop_selectBits_def
  , testProperty "excludeBits"               prop_excludeBits_def
  , testProperty "countBits"                 prop_countBits_def
  ]

prop_generalize :: Fun (Bit, Bit) Bit -> Bit -> Bit -> Property
prop_generalize fun x y = curry (applyFun fun) x y === generalize (curry (applyFun fun)) x y

prop_union_def :: U.Vector Bit -> U.Vector Bit -> Property
prop_union_def xs ys =
  xs .|. ys === U.zipWith (.|.) xs ys

prop_intersection_def :: U.Vector Bit -> U.Vector Bit -> Property
prop_intersection_def xs ys =
  xs .&. ys === U.zipWith (.&.) xs ys

prop_difference_def :: U.Vector Bit -> U.Vector Bit -> Property
prop_difference_def xs ys =
  zipBits diff xs ys === U.zipWith diff xs ys
  where
    diff x y = x .&. complement y

prop_symDiff_def :: U.Vector Bit -> U.Vector Bit -> Property
prop_symDiff_def xs ys =
  xs `xor` ys === U.zipWith xor xs ys

prop_zipBits :: Fun (Bit, Bit) Bit -> U.Vector Bit -> U.Vector Bit -> Property
prop_zipBits fun xs ys =
  U.zipWith f xs ys === zipBits (generalize f) xs ys
  where
    f = curry $ applyFun fun

prop_zipInPlace :: Fun (Bit, Bit) Bit -> U.Vector Bit -> U.Vector Bit -> Property
prop_zipInPlace fun xs ys =
  U.zipWith f xs ys === U.take (min (U.length xs) (U.length ys)) (U.modify (zipInPlace (generalize f) xs) ys)
  where
    f = curry $ applyFun fun

prop_invertBits :: U.Vector Bit -> Property
prop_invertBits xs =
  U.map complement xs === invertBits xs

prop_invertBitsWords :: U.Vector Word -> Property
prop_invertBitsWords = prop_invertBits . castFromWords

prop_invertBits_middle :: NonNegative Int -> NonNegative Int -> NonNegative Int -> Property
prop_invertBits_middle (NonNegative from) (NonNegative len) (NonNegative excess) =
  U.map complement xs === invertBits xs
  where
    totalLen = from + len + excess
    vec = U.generate totalLen (Bit . odd)
    xs = U.slice from len vec

prop_invertBitsLong_middle :: NonNegative Int -> NonNegative Int -> NonNegative Int -> Property
prop_invertBitsLong_middle (NonNegative x) (NonNegative y) (NonNegative z) =
  prop_invertBits_middle (NonNegative $ x * 31) (NonNegative $ y * 37) (NonNegative $ z * 29)

prop_invertInPlace :: U.Vector Bit -> Property
prop_invertInPlace xs =
  U.map complement xs === U.modify invertInPlace xs

prop_invertInPlaceWords :: U.Vector Word -> Property
prop_invertInPlaceWords = prop_invertInPlace . castFromWords

prop_invertInPlace_middle :: NonNegative Int -> NonNegative Int -> NonNegative Int -> Property
prop_invertInPlace_middle (NonNegative from) (NonNegative len) (NonNegative excess) = runST $ do
  let totalLen = from + len + excess
  vec <- MU.new totalLen
  forM_ [0 .. totalLen - 1] $ \i ->
    MU.write vec i (Bit (odd i))
  ref <- U.freeze vec

  let middle = MU.slice from len vec
  invertInPlace middle
  wec <- U.unsafeFreeze vec

  let refLeft   = U.take from ref
      wecLeft   = U.take from wec
      refRight  = U.drop (from + len) ref
      wecRight  = U.drop (from + len) wec
      refMiddle = U.map complement (U.take len (U.drop from ref))
      wecMiddle = U.take len (U.drop from wec)
  pure $ refLeft === wecLeft .&&. refRight === wecRight .&&. refMiddle === wecMiddle

prop_invertInPlaceLong_middle :: NonNegative Int -> NonNegative Int -> NonNegative Int -> Property
prop_invertInPlaceLong_middle (NonNegative x) (NonNegative y) (NonNegative z) =
  prop_invertInPlace_middle (NonNegative $ x * 31) (NonNegative $ y * 37) (NonNegative $ z * 29)

prop_reverseBits :: U.Vector Bit -> Property
prop_reverseBits xs =
  U.reverse xs === reverseBits xs

prop_reverseBitsWords :: U.Vector Word -> Property
prop_reverseBitsWords = prop_reverseBits . castFromWords

prop_reverseBits_middle :: NonNegative Int -> NonNegative Int -> NonNegative Int -> Property
prop_reverseBits_middle (NonNegative from) (NonNegative len) (NonNegative excess) =
  U.reverse xs === reverseBits xs
  where
    totalLen = from + len + excess
    vec = U.generate totalLen (Bit . odd)
    xs = U.slice from len vec

prop_reverseBitsLong_middle :: NonNegative Int -> NonNegative Int -> NonNegative Int -> Property
prop_reverseBitsLong_middle (NonNegative x) (NonNegative y) (NonNegative z) =
  prop_reverseBits_middle (NonNegative $ x * 31) (NonNegative $ y * 37) (NonNegative $ z * 29)

prop_reverseInPlace :: U.Vector Bit -> Property
prop_reverseInPlace xs =
  U.reverse xs === U.modify reverseInPlace xs

prop_reverseInPlaceWords :: U.Vector Word -> Property
prop_reverseInPlaceWords = prop_reverseInPlace . castFromWords

prop_reverseInPlace_middle :: NonNegative Int -> NonNegative Int -> NonNegative Int -> Property
prop_reverseInPlace_middle (NonNegative from) (NonNegative len) (NonNegative excess) = runST $ do
  let totalLen = from + len + excess
  vec <- MU.new totalLen
  forM_ [0 .. totalLen - 1] $ \i ->
    MU.write vec i (Bit (odd i))
  ref <- U.freeze vec

  let middle = MU.slice from len vec
  reverseInPlace middle
  wec <- U.unsafeFreeze vec

  let refLeft   = U.take from ref
      wecLeft   = U.take from wec
      refRight  = U.drop (from + len) ref
      wecRight  = U.drop (from + len) wec
      refMiddle = U.reverse (U.take len (U.drop from ref))
      wecMiddle = U.take len (U.drop from wec)
  pure $ refLeft === wecLeft .&&. refRight === wecRight .&&. refMiddle === wecMiddle

prop_reverseInPlaceLong_middle :: NonNegative Int -> NonNegative Int -> NonNegative Int -> Property
prop_reverseInPlaceLong_middle (NonNegative x) (NonNegative y) (NonNegative z) =
  prop_reverseInPlace_middle (NonNegative $ x * 31) (NonNegative $ y * 37) (NonNegative $ z * 29)

select :: U.Unbox a => U.Vector Bit -> U.Vector a -> U.Vector a
select mask ws = U.map snd (U.filter (unBit . fst) (U.zip mask ws))

exclude :: U.Unbox a => U.Vector Bit -> U.Vector a -> U.Vector a
exclude mask ws = U.map snd (U.filter (not . unBit . fst) (U.zip mask ws))

prop_selectBits_def :: U.Vector Bit -> U.Vector Bit -> Property
prop_selectBits_def xs ys = selectBits xs ys === select xs ys

prop_excludeBits_def :: U.Vector Bit -> U.Vector Bit -> Property
prop_excludeBits_def xs ys = excludeBits xs ys === exclude xs ys

prop_countBits_def :: U.Vector Bit -> Property
prop_countBits_def xs = countBits xs === U.length (selectBits xs xs)

-------------------------------------------------------------------------------

generalize :: (Bit -> Bit -> Bit) -> (forall a. Bits a => a -> a -> a)
generalize f = case (f (Bit False) (Bit False), f (Bit False) (Bit True), f (Bit True) (Bit False), f (Bit True) (Bit True)) of
  (Bit False, Bit False, Bit False, Bit False) -> \_ _ -> zeroBits
  (Bit False, Bit False, Bit False, Bit True)  -> \x y -> x .&. y
  (Bit False, Bit False, Bit True,  Bit False) -> \x y -> x .&. complement y
  (Bit False, Bit False, Bit True,  Bit True)  -> \x _ -> x

  (Bit False, Bit True,  Bit False, Bit False) -> \x y -> complement x .&. y
  (Bit False, Bit True,  Bit False, Bit True)  -> \_ y -> y
  (Bit False, Bit True,  Bit True,  Bit False) -> \x y -> x `xor` y
  (Bit False, Bit True,  Bit True,  Bit True)  -> \x y -> x .|. y

  (Bit True,  Bit False, Bit False, Bit False) -> \x y -> complement (x .|. y)
  (Bit True,  Bit False, Bit False, Bit True)  -> \x y -> complement (x `xor` y)
  (Bit True,  Bit False, Bit True,  Bit False) -> \_ y -> complement y
  (Bit True,  Bit False, Bit True,  Bit True)  -> \x y -> x .|. complement y

  (Bit True,  Bit True,  Bit False, Bit False) -> \x _ -> complement x
  (Bit True,  Bit True,  Bit False, Bit True)  -> \x y -> complement x .|. y
  (Bit True,  Bit True,  Bit True,  Bit False) -> \x y -> complement (x .&. y)
  (Bit True,  Bit True,  Bit True,  Bit True)  -> \_ _ -> complement zeroBits
