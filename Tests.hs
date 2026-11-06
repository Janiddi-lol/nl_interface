module Main where

import Control.Monad (unless)

import Lambek
import LTypes
import Parser

check :: String -> Bool -> IO ()
check label condition = do
  unless condition (error ("FAILED: " ++ label))
  putStrLn ("ok: " ++ label)

main :: IO ()
main = do
  let np = Atm "np"
      s = Atm "s"
  check "atomic identity" (dec_rinv [np] np)
  check "left division" (dec_rinv [np, DivL np s] s)
  check "word order matters" (not (dec_rinv [DivL np s, np] s))
  check "transitive verb" (dec_rinv [np, DivL np (DivR s np), np] s)

  parsed <- parseFile lexicon "animals.elx"
  case parsed of
    Left err -> error ("Could not read animals.elx: " ++ show err)
    Right (Left err) -> error ("Could not parse animals.elx: " ++ show err)
    Right (Right animalLexicon) -> do
      check "known grammatical sentence"
        (isGrammatical animalLexicon ["Conor", "Sleeps"])
      check "incomplete sentence"
        (not (isGrammatical animalLexicon ["Seamus", "Is", "Hungry", "And"]))
      check "unknown word"
        (not (isGrammatical animalLexicon ["Nobody", "Sleeps"]))
      check "quantified sentence"
        (isGrammatical animalLexicon ["Every", "Cat", "Sleeps"])
      check "a proof term is produced"
        (not (null (derivations animalLexicon ["Every", "Cat", "Sleeps"])))
      check "scope ambiguity is detected"
        (length (derivations animalLexicon ["Every", "Cat", "Fears", "A", "Dog"]) > 1)
