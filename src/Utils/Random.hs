{-# LANGUAGE TupleSections #-}

module Utils.Random  ( doWithProb
                     , randPos, uniRandPos
                     , chooseWithP, choose
                     , randSplit) where

import           Control.Monad.Random

import           Control.Monad        (replicateM)
import           Data.Functor         ((<$>))
import           Data.List            (sort)
import qualified Data.Vector          as Vec

doWithProb::(RandomGen g)=>Double->(a->b)->(a->b)->a->Rand g b
doWithProb p f g x = do
  r <- getRandomR (0, 1)
  return $ if r <= p then f x else g x

uniRandPos::(RandomGen g)=>Int->Int->Rand g [Int]
uniRandPos n m = posl [] n
  where posl rs 0 = return $ sort rs
        posl rs k = do p <- getRandomR (0, m-1)
                       if p `elem` rs then posl rs k
                         else posl (p:rs) (k-1)

randPos::(RandomGen g)=>Int->Int->Rand g [Int]
randPos n m = sort <$> (replicateM n $ getRandomR (0, m-1))

chooseWithP::(RandomGen g)=>Double->a->a->Rand g a
chooseWithP p a b = do
  r <- getRandomR (0, 1)
  return $ if r <= p then a else b

choose::(RandomGen g)=>a->a->Rand g a
choose a b = chooseWithP 0.5 a b

randSplit::RandomGen g=>Double->Vec.Vector a->Rand g (Vec.Vector a, Vec.Vector a)
randSplit p vs = do
  (v0, v1) <- Vec.partition snd <$>
              ( flip Vec.mapM vs $ doWithProb p (,True) (,False))
  return (Vec.map fst v0, Vec.map fst v1)