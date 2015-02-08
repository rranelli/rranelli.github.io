module Main where

import Control.Monad

type ValidationError = [String]
data Validated a = Errors (ValidationError, a)
                 | Valid a
                 deriving Show

instance Monad Validated where
  return a = Valid a
  a >>= f = case a of
             Errors (vrs, val) ->
               case f val of
                 Errors (vrs', val') -> Errors (vrs ++ vrs', val')
                 Valid val' -> Valid val'
             Valid val ->
               case f val of
                 Errors (vrs', val') -> Errors (vrs', val')
                 Valid val' -> Valid val'

predicateToValidator :: (a -> Bool) -> ValidationError -> (a -> Validated a)
predicateToValidator f verr = \x -> if f x then
                                      Valid x
                                    else
                                      Errors (verr, x)

biggerValidator :: (Ord a, Show a) => a -> a -> Validated a
biggerValidator limit value = if value < limit then
                                 Errors ([(show value) ++ " is not bigger than " ++ (show limit)], value)
                              else
                                 Valid value

biggerThan42 :: Int -> Validated Int
biggerThan42 = biggerValidator 42

smallerThan84 :: Int -> Validated Int
smallerThan84 = \x -> biggerValidator x 84

biggerThan84 :: Int -> Validated Int
biggerThan84 = biggerValidator 84

isValid :: Validated a -> Bool
isValid = \v -> case v of
                 Valid _ -> True
                 Errors _ -> False

shouldBeTrue = isValid $ (return 41) >>= smallerThan84
-- #=> true

shouldBeFalse = isValid $ (return 41) >>= biggerThan42
-- #=> false

errors = (return 41) >>= biggerThan42 >>= biggerThan84
-- #=> Errors (["41 is not bigger than 42","41 is not bigger than 84"],41)
