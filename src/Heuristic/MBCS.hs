module Heuristic.MBCS (mbcs) where

import           Heuristic       (InfinityPool, PartialSchedule (..), Pool (..))
import           Problem         (Cost, Ins, Problem, Schedule, Time, cu, nTask,
                                  nType, qcharge, refTime)
import           Problem.Foreign (computeObjs)

import           Control.DeepSeq (NFData (..))
import           Data.List       (minimumBy)
import           Data.Ord        (comparing)
import qualified Data.Vector     as Vec

data CPartial pl = CPar { _pool         :: pl
                        , _locations    :: Vec.Vector Ins
                        , _budget       :: Cost
                        , _usedBudget   :: Cost
                        , _remainBudget :: Cost
                        , _remainWork   :: Time
                        , _usedTime     :: Time
                        , _lastFT       :: Time
                        , _lastC        :: Time
                        , _finishTimes  :: Vec.Vector Time}

instance (NFData pl)=>NFData (CPartial pl) where
  rnf (CPar a b c d e f g h i j) =
    rnf a `seq` rnf b `seq` rnf c `seq` rnf d `seq` rnf e `seq` rnf f `seq` rnf g `seq` rnf h `seq` rnf i `seq` rnf j

instance PartialSchedule CPartial where
  locations = _locations
  finishTimes = _finishTimes
  pool = _pool

  putTask p s t i = s { _pool = pl'
                      , _locations = _locations s Vec.// [(t, i)]
                      , _usedBudget = _usedBudget s + c
                      , _remainWork = _remainWork s - refTime p t
                      , _usedTime = if _usedTime s < ft then ft else _usedTime s
                      , _lastFT = ft
                      , _lastC = c
                      , _finishTimes = _finishTimes s Vec.// [(t, ft)]}
    where (_, ft, pl') = allocIns p s t i
          c = cost pl' i - cost (_pool s) i

  sortSchedule p ss =
    let _update s = s {_remainBudget = _remainBudget s - _lastC s}
        ub_lowest = minimum . map _usedBudget $ ss
        ub_highest = maximum . map _usedBudget $ ss
        ft_best = minimum . map _lastFT $ ss
        ft_worst = maximum . map _lastFT $ ss
        c_lowest = minimum . map _lastC $ ss
        c_highest = maximum . map _lastC $ ss
        b = _budget $ head ss
        rw = _remainWork $ head ss
        rb = _remainBudget $ head ss
        rcb = minimum [qcharge p (ct, 0, rw / cu p ct)|ct<-[0..nType p-1]]
        r_e = if rb <= rcb + c_lowest  then 1 else
                if rb > rcb + c_highest then 0 else
                  exp $ (rcb + c_lowest - rb) / (c_highest - c_lowest)
        _worth_e CPar { _lastFT=ft, _lastC=c} =
          let cr = (c - c_lowest) / (c_highest - c_lowest)
              tr = (ft - ft_best) / (ft_worst - ft_best)
          in (cr * r_e + tr * (1-r_e), tr, cr)
        r_l = if b <= rcb + ub_lowest then 1 else
                if b > rcb + ub_highest then 0 else
                  (rcb + ub_highest - b) / (ub_highest - ub_lowest)
        _worth_l CPar { _usedBudget=ub, _lastFT=ft} =
          let cr = (ub - ub_lowest) / (ub_highest - ub_lowest)
              tr = (ft - ft_best) / (ft_worst - ft_best)
          in (cr * r_l + tr * (1-r_l), tr, cr)
        best_e = _update . minimumBy (comparing _worth_e) $ ss
        best_l = _update . minimumBy (comparing _worth_l) $ ss
    in [best_e, best_l]

empty::Pool pl=>Problem->Double->CPartial pl
empty p b = CPar (prepare p) (Vec.replicate (nTask p) 0) b 0 b
                 rw 0 0 0 (Vec.replicate (nTask p) 0)
  where rw = sum . map (refTime p) $ [0..nTask p-1]

mbcs::Problem->Double->Schedule
mbcs p b = let [s0, s1] = schedule p 2 $ (empty p b :: CPartial InfinityPool)
               [m0, c0] = computeObjs s0
               [m1, c1] = computeObjs s1
           in if c0 <= b && c1 <= b then
                if m0 <= m1 then s0 else s1
              else if c0 <= b then s0
                   else if c1 <= b then s1
                        else if c0 <= c1 then s0
                             else s1
