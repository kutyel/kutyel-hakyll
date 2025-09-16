import Language.Haskell.HLint (hlint)
import System.Exit (exitFailure, exitSuccess)

main :: IO ()
main = do
  hints <- hlint [ "src", "--color" ]
  if null hints then exitSuccess else exitFailure
