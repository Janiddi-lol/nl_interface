{-# OPTIONS_GHC -fwarn-incomplete-patterns #-}

module Lambek where

import LExp
import LTypes

-- All ways of splitting a list into a prefix and a suffix.  Empty
-- prefixes and suffixes are required by the left rules.
splits :: [a] -> [([a], [a])]
splits xs = [splitAt i xs | i <- [0 .. length xs]]

-- All ways of selecting one element as a focus while retaining the
-- elements on its left and right.
focuses :: [a] -> [([a], a, [a])]
focuses [] = []
focuses (x:xs) =
  ([], x, xs) : [(x:left, y, right) | (left, y, right) <- focuses xs]

-- Decide whether gamma entails b, first applying invertible rules to b.
dec_rinv :: [LTp] -> LTp -> Bool
dec_rinv gamma b =
  case b of
    DivL a b' -> dec_rinv (a : gamma) b'
    DivR b' a -> dec_rinv (gamma ++ [a]) b'
    Atm p -> any (\(gammaL, a, gammaR) -> dec_lfoc gammaL a gammaR p)
                 (focuses gamma)

-- Decide an atomic goal while focusing on one type in the context.
dec_lfoc :: [LTp] -> LTp -> [LTp] -> Atm -> Bool
dec_lfoc gammaL a gammaR p =
  case a of
    Atm q -> null gammaL && null gammaR && q == p
    DivL a' b ->
      any (\(gammaL1, gammaL2) ->
             dec_rinv gammaL2 a' && dec_lfoc gammaL1 b gammaR p)
          (splits gammaL)
    DivR b a' ->
      any (\(gammaR1, gammaR2) ->
             dec_rinv gammaR1 a' && dec_lfoc gammaL b gammaR2 p)
          (splits gammaR)

isGrammatical :: Lexicon sem -> [String] -> Bool
isGrammatical lexicon ws =
  any (\gamma -> dec_rinv gamma (stp lexicon)) typeAssignments
  where
    typesFor w = [a | (w', a, _) <- items lexicon, w == w']
    typeAssignments = sequence [typesFor w | w <- ws]

-- Return all proof terms for an unfocused sequent.  Context entries carry
-- variables so that a proof records which occurrence of a word it uses.
der_rinv :: [(Var, LTp)] -> LTp -> [LExp]
der_rinv gamma b =
  case b of
    DivL a b' ->
      let x = fresh [V y | (y, _) <- gamma]
      in [L x e | e <- der_rinv ((x, a) : gamma) b']
    DivR b' a ->
      let x = fresh [V y | (y, _) <- gamma]
      in [L x e | e <- der_rinv (gamma ++ [(x, a)]) b']
    Atm p ->
      [foldl A (V x) args |
        (gammaL, (x, a), gammaR) <- focuses gamma,
        args <- der_lfoc gammaL a gammaR p]

-- A focused derivation returns the arguments that must be applied to the
-- focused variable.  The atomic axiom creates the empty argument list.
der_lfoc :: [(Var, LTp)] -> LTp -> [(Var, LTp)] -> Atm -> [[LExp]]
der_lfoc gammaL a gammaR p =
  case a of
    Atm q
      | null gammaL && null gammaR && q == p -> [[]]
      | otherwise -> []
    DivL a' b ->
      [e : args |
        (gammaL1, gammaL2) <- splits gammaL,
        e <- der_rinv gammaL2 a',
        args <- der_lfoc gammaL1 b gammaR p]
    DivR b a' ->
      [e : args |
        (gammaR1, gammaR2) <- splits gammaR,
        e <- der_rinv gammaR1 a',
        args <- der_lfoc gammaL b gammaR2 p]

-- Enumerate lexical choices and return every derivation together with the
-- semantic value selected for each word occurrence.
derivations :: Lexicon sem -> [String] -> [(LExp, [(Var, sem)])]
derivations lexicon ws = do
  chosen <- sequence [entriesFor w | w <- ws]
  let labelled = zipWith label [1 :: Int ..] chosen
      typedContext = [(x, a) | (x, a, _) <- labelled]
      meanings = [(x, sem) | (x, _, sem) <- labelled]
  proof <- der_rinv typedContext (stp lexicon)
  return (proof, meanings)
  where
    entriesFor w = [(w', a, sem) | (w', a, sem) <- items lexicon, w == w']
    label i (w, a, sem) = (w ++ "_" ++ show i, a, sem)
