import Data.Char
import System.IO
import Control.Exception

import LExp
import LTypes
import qualified Lambek

import Parser
import PySupport

-- "standardize" the capitalization of a word by making the first
-- letter uppercase and the following letters lowercase.
-- (This will make it easier to look up words in the lexicon.)
stdize :: String -> String
stdize [] = []
stdize (c:cs) = toUpper c : map toLower cs

-- Replace free lexical variables with their Python meanings and translate
-- lambda abstraction/application into Python syntax.  Variables absent from
-- the environment are bound by a surrounding lambda expression.
toPython :: [(Var, PythonCode)] -> LExp -> String
toPython env expression =
  case expression of
    V x -> case lookup x env of
      Just code -> "(" ++ text code ++ ")"
      Nothing -> x
    A f x -> "(" ++ toPython env f ++ ")(" ++ toPython env x ++ ")"
    L x body -> "(lambda " ++ x ++ ": " ++ toPython env body ++ ")"

showSense :: PythonHandle -> (LExp, [(Var, PythonCode)]) -> IO ()
showSense phandle (proof, meanings) = do
  result <- runPythonCode phandle (PCode (toPython meanings proof))
  putStrLn $ "Sense [" ++ prettyLExp proof ++ "]: " ++ result

-- read-eval-print-loop
repl :: Lexicon PythonCode -> PythonHandle -> IO ()
repl elx phandle = do
  -- print the prompt
  putStr "> "
  eof <- isEOF
  if eof
    then putStrLn ""
    else do
      -- get a line of input and look up all its possible derivations
      line <- getLine
      let ws = map stdize $ words line
          senses = Lambek.derivations elx ws
      case senses of
        [] -> putStrLn "That is not a well-formed sentence"
        [sense] -> showSense phandle sense
        _ -> do
          putStrLn "That sentence is ambiguous"
          mapM_ (showSense phandle) senses
      repl elx phandle
      
main :: IO ()
main = do
  -- send console output immediately to the user
  hSetBuffering stdout NoBuffering
  -- input a lexicon file
  elx <- getLex
  -- input a database of facts
  db <- getDB
  -- launch a Python interpreter
  phandle <- launchPython db
  -- start the read-eval-print loop
  putStrLn "Starting chat..."
  repl elx phandle
  where
    getDB :: IO PythonCode
    getDB = do
      putStr "Facts about the world: "
      dname <- getLine
      mdb <- try (readFile dname) :: IO (Either IOError String)
      case mdb of
        Left err -> putStrLn ("Error loading file " ++ show err) >> getDB
        Right db -> return (PCode db)
      
    getLex :: IO (Lexicon PythonCode)
    getLex = do
      putStr "Lexicon file: "
      lname <- getLine
      res <- parseFile lexicon lname
      case res of
        Left err -> putStrLn ("Error loading file " ++ show err) >> getLex
        Right (Left err) -> putStrLn ("parse error at " ++ lname ++ ":" ++ show err) >> getLex
        Right (Right parsedLexicon) -> return parsedLexicon
