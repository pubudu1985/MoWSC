module Heuristic ( PartialSchedule (..)
                 , Pool (..), InfinityPool, FullPool
                 , timeComp
                 , getOrder) where

import Problem
import Data.Vector (Vector, (!), (//))
import qualified Data.Vector as Vec
import Data.List (sortBy, sort, group)
import qualified Data.Map.Strict as Map
import Data.Set (member, insert)
import qualified Data.Set as Set
import qualified Data.IntMap as IM
import Data.IntMap (IntMap)
import Control.DeepSeq (NFData (..))
import Data.Foldable (foldr')
import GHC.Float

class PartialSchedule ps where
  locations::ps pl->Vector Ins
  finishTimes::ps pl->Vector Time
  pool::Pool pl=>ps pl->pl

  putTask::Pool pl=>Problem->ps pl->
           Task->Ins->ps pl

  sortSchedule::Pool pl=>Problem->[ps pl]->[ps pl]

  next::Pool pl=>Problem->Task->ps pl->[ps pl]
  next p t s = map (putTask p s t) . availIns . pool $ s

  schedule::(NFData (ps pl))=>Pool pl=>Problem->
            Int->ps pl->[Schedule]
  schedule p k s0 = map (tidySchedule p pl o . Vec.toList . locations) .
                    foldr' f [s0] $ reverse o
    where o = getOrder p
          pl = pool s0
          f t ss = let ss' = ss >>= next p t
                   in if length ss' <= k then ss' else take k $ sortSchedule p ss'

-- Pool class manages an available instance pool --

class Pool a where
  availIns::a->[Ins]
  allUsed::a->[Ins]

  insType::a->Ins->InsType
  startTime::a->Ins->Time
  availTime::a->Ins->Time
  cost::a->Ins->Cost

  totalCost::a->Cost
  totalCost pl = sum . map (cost pl) $ availIns pl

  allocIns::(PartialSchedule pl)=>Problem->
            pl a->Task->Ins->(Time, Time, a)

  scheduleTask::(PartialSchedule pl)=>Problem->
                pl a->Task->Ins->(Time, Time)

  prepare::Problem->a

  newCost::Problem->a->Ins->Time->Time->Cost

  scheduleTask p s t i = (st, ft)
    where pl = pool s
          st = foldr max (availTime pl i) . map (finishTimes s !) $ (preds p t)
          ft = st + timeComp p pl t i

  newCost p pl i st ft = charge p $ Account [(insType pl i, st, ft)]


data InfinityPool = IPool { _ins :: Set.Set Ins
                          , _n :: Int
                          , _limit :: Int
                          , _startTime :: Map.Map Ins Time
                          , _availTime :: Map.Map Ins Time
                          , _costs :: Map.Map Ins Cost}

instance NFData InfinityPool where
  rnf (IPool a b c d e f) = rnf a `seq` rnf b `seq` rnf c `seq` rnf d `seq` rnf e `seq` rnf f

instance Pool InfinityPool where
  insType pl i = i `mod` _n pl
  allUsed = Set.toList . _ins
  startTime pl i = (Map.!) (_startTime pl) i
  availTime pl i = Map.findWithDefault 0 i $ _availTime pl
  cost pl i = Map.findWithDefault 0 i $ _costs pl

  availIns pl
    | Set.size (_ins pl) == _limit pl = Set.toList used
    | otherwise = Set.toList used ++ map (_newInsByType used n) [0..n-1]
    where used = _ins pl
          n = _n pl

  allocIns p s t i = (st
                     , ft
                     , if member i $ _ins pl
                       then pl { _availTime = Map.insert i ft $ _availTime pl
                               , _costs = _updateCost p pl i (startTime pl i) ft}
                       else pl { _ins = i `insert` _ins pl
                               , _startTime = Map.insert i st $ _startTime pl
                               , _availTime = Map.insert i ft $ _availTime pl
                               , _costs = _updateCost p pl i st ft})
    where (st, ft) = scheduleTask p s t i
          pl = pool s


  prepare p = IPool Set.empty (nType p) (nIns p) Map.empty Map.empty Map.empty


_newInsByType::Set.Set Ins->Int->InsType->Ins
_newInsByType s n t = if t `member` s
                      then _newInsByType s n $ t+n
                      else t

_updateCost::Problem->InfinityPool->
             Ins->Time->Time->Map.Map Ins Cost
_updateCost p pl i st ft = Map.insert i (newCost p pl i st ft) $ _costs pl

data FullPool = FPool { _nType :: Int
                      , _nTask :: Int
                      , _used :: Set.Set Ins
                      , _start :: IntMap Float
                      , _avail :: IntMap Float
                      , _fcosts :: IntMap Float}

instance NFData FullPool where
  rnf (FPool a b c d e f) = rnf a `seq` rnf b `seq` rnf c `seq` rnf d `seq` rnf e `seq` rnf f

instance Pool FullPool where
  insType pl i = i `mod` _nType pl
  allUsed = Set.toList . _used
  startTime pl i = float2Double $ (IM.!) (_start pl) i
  availTime pl i = float2Double . IM.findWithDefault 0 i $ _avail pl
  cost pl i = float2Double . IM.findWithDefault 0 i $ _fcosts pl
  availIns pl = [0.._nType pl * _nTask pl - 1]
  prepare p = FPool (nType p) (nTask p) Set.empty IM.empty IM.empty IM.empty

  allocIns p s t i =
    let (st, ft) = scheduleTask p s t i
        pl = pool s
    in (st, ft
       , if i `member` _used pl
         then let st' = startTime pl i
              in pl { _avail = IM.insert i (double2Float ft) $ _avail pl
                    , _fcosts = IM.insert i (double2Float $ newCost p pl i st' ft) $
                                _fcosts pl}
         else pl { _used = i `insert` _used pl
                 , _start = IM.insert i (double2Float st) $ _start pl
                 , _avail = IM.insert i (double2Float ft) $ _avail pl
                 , _fcosts = IM.insert i (double2Float $ newCost p pl i st ft) $
                             _fcosts pl})

-- Some helper functions --

timeComp::Pool pl=>Problem->pl->Task->Ins->Time
timeComp p pl t i = refTime p t / cu p (insType pl i)

getRank::Problem->Vector Double
getRank p = _getRank (Vec.replicate (nTask p) 0) (nTask p - 1)
  where _getRank rs t
          | t < 0 = rs
          | otherwise = let rx = _meanTimeComp p t + foldr max 0 (map (rs!) $ succs p t)
                            rs' = rs // [(t, rx)]
                        in _getRank (rs') $ t-1

getOrder::Problem->[Task]
getOrder p = sortBy compRank [0..(Vec.length rs - 1)]
  where rs = getRank p
        compRank x y = (flip compare) (rs ! x) (rs ! y)

tidySchedule::Pool pl=>Problem->pl->[Task]->[Ins]->Schedule
tidySchedule p pl order locs =
  let inss = map head . group . sort $ locs
      index = Map.fromList $ zip inss [0..]
      _t2i = map ((Map.!) index) $ locs
      _i2t = map (insType pl) inss
  in Schedule order (Vec.fromList _t2i) (Vec.fromList _i2t)

_meanTimeComp::Problem->Task->Time
_meanTimeComp p t = sum ts / (fromIntegral $ length ts)
  where ts = [refTime p t / cu p i |i<-[0,1..(nType p - 1)]]
