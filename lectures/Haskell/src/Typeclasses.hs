{-# LANGUAGE InstanceSigs #-}

module Typeclasses where

import Prelude hiding (fail, elem)
import qualified Data.Map as M
import Control.Monad hiding (fail)
import Control.Monad.Trans
import Debug.Trace

{-

Type Classes
-------------

If we let Haskell infer the type of the following function, it will not be
the one we wrote for it in the previous section, but something more general.

-}

add :: Num a => a -> a -> a
add = (+)

{-
The above type tells us that add works for any type `a`, as long as this type
implements the [Num] type class.

What is a type class?

A type class is a set of operations (functions and constants), that must be
implemented by any type that is an _instance_ of the type class. A type class
defines a common interface

Then when writing polymorphic functions, one can put constraints on
polymorphic types that they should implement a particular type class. This is
called a type class constraint. Then the function can access all the
operations of the type class.

Haskell implements overloading, which is the ability to define an operation
for more than one types, using type classes.

The Num type class defines operations like +, -, * for numeric types. Every
type that implements the type class (i.e. provides an instance of the type
class) should define these operations.

Another useful class is Eq, that defines equality and inequality.
Its definition in Haskell library is the following:


class Eq a where
    (==)        :: a -> a -> Bool
    (/=)        :: a -> a -> Bool

    x /= y      = not (x == y) -- default implementation


The definition of inequality has a default implementation that
will be used if the instance does not redefine the operation.

Most built-in datatypes in Haskell provide instances for Eq but when we are
defining our own types, we may want to provide instances of such
classes.

-}

data Tree a = Leaf | Node a (Tree a) (Tree a)

-- The type class instance for Tree a, has a type class constraint that the
-- type a must implement Eq

instance Eq a => Eq (Tree a) where
    (==) :: Eq a => Tree a -> Tree a -> Bool
    Leaf          == Leaf             = True
    Node a1 t1 t2 == Node a1' t1' t2' = a1 == a1' && t1 == t1' && t2 == t2'
    _             == _                = False

tree1 :: Tree Int
tree1 = Node 42 (Node 17 Leaf Leaf) Leaf

tree2 :: Tree Int
tree2 = Node 17 (Node 11 Leaf Leaf) Leaf

--- >>> tree1 == tree2
-- False

--- >>> tree1 == tree1
-- True

-- Haskell lets us use the keyword deriving to automatically derive some
-- instances. In Haskell 98, the only derivable classes are Eq, Ord, Enum, Ix,
-- Bounded, Read, and Show. Various language extensions extend this list.

-- For example:

data Tree' a = Leaf' | Node' a (Tree' a) (Tree' a)
  deriving (Eq, Show)

tree1' :: Tree' Int
tree1' = Node' 42 (Node' 17 Leaf' Leaf') Leaf'

tree2' :: Tree' Int
tree2' = Node' 17 (Node' 11 Leaf' Leaf') Leaf'

--- >>> tree1' == tree2'
-- False

--- >>> tree1' == tree1'
-- True

-- The Show type class provides one function show :: a -> String that converts
-- its input to a string.

-- >>> show tree1'
-- "Node' 42 (Node' 17 Leaf' Leaf') Leaf'"

-- -- These derived instances might not always be the desired ones.

-- For example, consider the following simple AST that contains information
-- about the position of the node in the source code. When we compare
-- expressions, we would like to ignore this.

-- The source code position
type Posn = (Int,Int) -- a type synonym

data Exp = Var Posn String
         | App Posn Exp Exp
         | Abs Posn String Exp
         | Num Posn Int
         | Add Posn Exp Exp
   deriving Show

instance Eq Exp where
    (==) :: Exp -> Exp -> Bool
    Var _ x     == Var _ x'      = x == x'
    App _ e1 e2 == App _ e1' e2' = e1 == e1' && e2 == e2'
    Abs _ x e   == Abs _ x' e'   = x == x' && e == e'
    Num _ n     == Num _ n'      = n == n'
    Add _ e1 e2 == Add _ e1' e2' = e1 == e1' && e2 == e2'
    _ == _ = False

-- >>> (Add (0,2) (Num (0,0) 3) (Num (0,4) 4)) == (Add (1,2) (Num (1,0) 3) (Num (1,4) 4))
-- True

-- Another common typeclass is the Ord typeclass that provides comparison
-- functions.

-- Using Ord we can write a generic quicksort function

qsort :: Ord a => [a] -> [a] -- What is Ord?
qsort [] = []
qsort (p:xs) =
  qsort [x | x <- xs, x < p] ++
  [p] ++ qsort [x | x <- xs, x >= p]


{-

To summarize, we've seen four very standard type classes in Haskell:

- Ord  : provides total orderings on data types
- Show : allows data types to be printed as strings
- Eq   : provides (in)equality operations
- Num  : provides functionality common to all kinds of numbers

Next, we will move to another very common Haskell type class: Monads.
-}

{-

Monads
------

Monads can be seen as a generic interface to various types of computations.

This interface can be used to simulate an imperative programming style in purely
functional languages by hiding a lot of . This makes it easier to write code
that manipulates state, throws errors, models nondeterminism, etc.

Monads can also be used to encapsulate truly impure code and keep it
separate from the pure language fragment (like the IO monad).

The interface that must be implemented by a monad is the following.

class Monad (m :: Type -> Type) where
  -- encapsulate a pure computation in a monadic one
  return :: a -> m a
  -- sequence two monadic computations
  (>>=)  :: m a -> (a -> m b) -> m b

Note, that the monad is not parametric on a type, but a type operator. As we
will see, this can be a List, a Maybe, or a "side-effect" type like IO.

In addition to the interface, monads should satisfy the _monad laws_:

return a >>= k = k a
m >>= return = m
m >>= (\x -> k x >>= h)  =  (m >>= k) >>= h

Note: As of 2017, Haskell require every Monad to also be an Applicative
instance, and every Applicative to also have a Functor instance. So in
the code below, we also provide these instances.

-}

-- The Maybe Monad

{- The implementation of the Maybe monad, provided by the Haskell standard library
   is the following:

instance Monad Maybe where
   return      :: a -> Maybe a
   return         =  Just

   (>>=)       :: Maybe a -> (a -> Maybe b) -> Maybe b
   Nothing  >>= _ =  Nothing
   (Just x) >>= f =  f x

-}

-- There is also a "monadic action" specific to this monad
fail :: Maybe a
fail = Nothing

-- We can use the Maybe monad to avoid boilerplate code when writing recursive
-- functions that return optional types.

-- For example we can write an interpreter for lambda calculus, which is a
-- partial function, without having to explicitly match the result to get it out
-- of the Maybe type. We can simply use monadic bind to do this.

subst :: String -> Exp -> Exp -> Exp
subst x t' t@(Var _ y)    = if x == y then t' else t
subst x t' t@(Abs p y t1) = if x == y then t else Abs p y (subst x t' t1)
subst x t' (App p t1 t2)  = App p (subst x t' t1) (subst x t' t2)
subst _ _ t@(Num _ _)     = t
subst x t' (Add p t1 t2)  = Add p (subst x t' t1) (subst x t' t2)

psn :: Posn
psn = (0,0)

exp1 :: Exp
exp1 = subst "x" (Abs psn "z" (Var psn "z")) (App psn (Var psn "x") (Add psn (Num psn 1) (Num psn 2)))

-- >>> exp1
-- App (0,0) (Abs (0,0) "z" (Var (0,0) "z")) (Add (0,0) (Num (0,0) 1) (Num (0,0) 2))

eval :: Exp -> Maybe Exp
eval (Var _ _) = fail
eval (Abs p x t) = return (Abs p x t)
eval (App _ t1 t2) =
  eval t1 >>= (\v ->
    case v of
      Abs _ x t ->
        eval t2 >>= (\v2 ->
        eval (subst x v2 t))
      _ -> fail)
eval (Num p n) = return (Num p n)
eval (Add p t1 t2) =
  eval t1 >>= (\v1 ->
  eval t2 >>= (\v2 ->
  case (v1, v2) of
    (Num _ n1, Num _ n2) -> return $ Num p (n1 + n2)
    _ -> Nothing))

-- >>> eval exp1
-- Just (Num (0,0) 3)

{--

Do notation
-----------

This already feels all lot like sequencing imperative code. Haskell provides a
"do notation" to makes this sequencing feel even more natural.

A monadic bind operation

m >>= \x -> m'

in do notation becomes

x <- m;
m'

This notation, which resembles an imperative program, must be written inside a
do block. The following example demonstrates this.
-}


-- eval with do notation

eval' :: Exp -> Maybe Exp
eval' (Var _ _) = fail
eval' (Abs p x t) = return (Abs p x t)
eval' (App _ t1 t2) = do
  v <- eval' t1;
  case v of
    Abs _ x t -> do
      v2 <- eval' t2;
      eval (subst x v2 t)
    _ -> fail
eval' (Num p n) = return (Num p n)
eval' (Add p t1 t2) = do
  v1 <- eval' t1;
  v2 <- eval' t2;
  case (v1, v2) of
    (Num _ n1, Num _ n2) -> return $ Num p (n1 + n2)
    _ -> fail



{-

Generic Monad Functions
------------------------

There are several monadic combinators that let us manipulate and sequence monadic computation.
Some examples are:

-- Map each element of a structure to a monadic action, evaluate these actions from left to
-- right, and collect the results.
mapM :: (Traversable t, Monad m) => (a -> m b) -> t a -> m (t b)

-- Evaluate each monadic action in the structure from left to right, and collect the results.
sequence :: (Traversable t, Monad m) => t (m a) -> m (t a)

-- Lift a pure function to a monadic one
liftM :: Monad m => (a1 -> r) -> m a1 -> m r

-- Lift a pure function with two arguments to a monadic one
liftM2 :: Monad m => (a1 -> a2 -> r) -> m a1 -> m a2 -> m r

You can find more monadic combinators here: https://hackage.haskell.org/package/base/docs/Control-Monad.html
-}

{-

The Reader Monad
----------------

The Reader monad (also called the Environment monad) encapsulates a computation
that reads values from a shared environment. Essentially a Reader monad, is a
function from the environment to the result type. The computation can ask for
the value of the environment and execute subcomputations in a modified
environment.

-}

newtype Reader env a = Reader { runReader :: env -> a }

instance Functor (Reader env) where
  fmap f r = Reader (f . runReader r)

instance Applicative (Reader env) where
  pure x                   = Reader (\_ -> x)
  Reader fe <*> Reader ae  = Reader (\e -> fe e (ae e))

instance Monad (Reader env) where
  -- by default, return is defined as the pure method of the Applicative type class

  (>>=) :: Reader env a -> (a -> Reader env b) -> Reader env b
  x >>= f  = Reader $ \e -> let x' = runReader x e in runReader (f x') e

-- Return the value of the environment
ask :: Reader env env
ask = Reader (\e -> e)

-- Execute the computation provided as a second argument in a modified
-- environment
local :: (env -> env) -> Reader env a -> Reader env a
local f (Reader m) = Reader (m . f)


-- For example, we can write the substitution function in a reader monad, to
-- avoid explicitly passing the variable and expression to be substituted.

substR :: Exp -> Reader (String, Exp) Exp
substR t@(Var _ y) = do
   (x, t') <- ask
   if x == y then return t' else return t
substR t@(Abs p y t1) = do
  (x, _) <- ask
  if x == y then return t
  else liftM (Abs p y) (substR t1)
substR (App p t1 t2)  = liftM2 (App p) (substR t1) (substR t2)
substR t@(Num _ _)    = return t
substR (Add p t1 t2)  = liftM2 (Add p) (substR t1) (substR t2)


subst' :: String -> Exp -> Exp -> Exp
subst' x t' t = runReader (substR t) (x,t')

-- We can also write an environment based evaluator as a computation in a Reader
-- monad.

type Env = M.Map String Value

-- The type of values
data Value = VClo Env String Exp | VNum Int

evalEnv :: Exp -> Reader Env Value
evalEnv (Var _ x) = do
  env <- ask
  case M.lookup x env of
    Just v -> return v
    _ -> error "Unbound variable"
evalEnv (Abs _ x t) = do
  env <- ask
  return (VClo env x t)
evalEnv (App _ t1 t2) = do
  v <- evalEnv t1;
  case v of
    VClo cenv x t -> do
      v2 <- evalEnv t2;
       -- evaluate t in the closure environment update with the argument value
      local (\_ -> M.insert x v2 cenv) (evalEnv t)
    _ -> error "Value must be a closure"
evalEnv (Num _ n) = return $ VNum n
evalEnv (Add _ t1 t2) = do
  v1 <- evalEnv t1;
  v2 <- evalEnv t2;
  case (v1, v2) of
    (VNum n1, VNum n2) -> return $ VNum (n1 + n2)
    _ -> error "Values must be numbers"


-- >>> subst' "x" (Abs psn "z" (Var psn "z")) (App psn (Var psn "x") (Add psn (Num psn 1) (Num psn 2)))
-- App (0,0) (Abs (0,0) "z" (Var (0,0) "z")) (Add (0,0) (Num (0,0) 1) (Num (0,0) 2))



{-

The State Monad
----------------

The State monad encapsulates computations that read and write from a shared
state. Essentially a state monad is a computation that is written in state
passing style, i.e., state -> (state, a) for some result type a, and hides th
explicit state threading under the monadic operations.

-}


newtype State state a = State { runState :: state -> (state, a) }

instance Functor (State state) where
  fmap f st = State (\s -> let (s', a) = runState st s in (s', f a))

instance Applicative (State state) where
  pure x                 = State (\s -> (s,x))
  State fs <*> State as  = State (\s ->
      let (s', f) = fs s in
      let (s'', a) = as s' in (s'', f a))

instance Monad (State state) where
  (>>=) :: State state a -> (a -> State state b) -> State state b
  x >>= f = State $ \s -> let (s', x') = runState x s in runState (f x') s'

get :: State state state
get = State (\s -> (s,s))

put :: state -> State state ()
put s = State (\_ -> (s,()))


-- Example: Fibonacci as a stateful function, various versions

type FibState = State (Integer, Integer) ()


fibState :: Integer -> FibState
fibState 0 = return ()
fibState n = do
  fibState (n-1)
  (cur, prev) <- get
  put (cur + prev, cur)

computeFib :: Integer -> Integer
computeFib n = fst . fst $ runState (fibState n) (0,1)

-- Or, in point-free style:
-- computeFib' = fst . fst . flip runState (0,1) . fibState

-- We can also write this as a "for loop"

fibFor :: Integer -> State (Integer, Integer) ()
fibFor n =
  forM_ [1..n] (\_ -> do
    (cur, prev) <- get
    put (cur+prev, cur))


computeFib' :: Integer -> Integer
computeFib' n = fst . fst $ runState (fibFor n) (0,1)

-- Or, in point-free style:
-- computeFib' = fst . fst . flip runState (0,1) . fibFor

-- >>> computeFib 9
-- 34

-- >>> computeFib' 9
-- 34

fibNFor :: Integer -> Integer
fibNFor n = snd . flip runState (0,1) $ do

  forM_ [0..(n-1)] $ \_ -> do
    (curr,prev) <- get
    put (curr+prev,curr)

  (curr,_) <- get
  return curr

-- >>> fibNFor 9
-- 34

{- Monad Transformers -}

-- Often it is useful to combine two monads together. For example, in the
-- environment based interpreter we might want to use a Maybe monad inside the
-- state in order to do error handling.

-- One option is to build a new type, encapsulating a computation with type
-- `state -> (state, Maybe a)` and make it and instance of Monad.

-- One other option, is to make monad definitions parametric an another
-- underlying monad, and make them add functionality on top of it. These
-- constructions are called monad transformers.

-- The simple non-transformer versions can be then be obtain by using the Id
-- (identity) monad as the base monad.


-- State transformers

newtype StateT s m a = StateT { runStateT :: s -> m (s, a) }

instance Monad m => Monad (StateT state m) where
  return :: a -> StateT state m a
  return x = StateT (\s -> return (s,x))

  (>>=) :: StateT state m a -> (a -> StateT state m b) -> StateT state m b
  x >>= f = StateT $ \s -> do
    (s', x') <- runStateT x s
    runStateT (f x') s'

instance (Monad m) => Applicative (StateT s m) where
  pure = return
  (<*>) :: Monad m => StateT s m (a -> b) -> StateT s m a -> StateT s m b
  (<*>) = ap

instance (Monad m) => Functor (StateT s m) where
  fmap = liftM


instance MonadTrans (StateT s) where
  lift :: (Monad m) => m a -> StateT s m a
  lift ma = StateT $ \s -> do
    r <- ma
    return (s, r)

getT :: Monad m => StateT state m state
getT = StateT (\s -> return (s,s))

putT ::  Monad m => state -> StateT state m ()
putT s = StateT (\_ -> return (s,()))

-- Reader transformers

newtype ReaderT env m a = ReaderT { runReaderT :: env -> m a }

instance Monad m => Monad (ReaderT env m) where
  return :: a -> ReaderT env m a
  return x = ReaderT $ \_ -> return x
  (>>=) :: ReaderT env m a -> (a -> ReaderT env m b) -> ReaderT env m b
  (ReaderT r) >>= f = ReaderT $ \env -> do
    x <- r env
    runReaderT (f x) env

instance Functor m => Functor (ReaderT env m) where
  fmap :: Functor m => (a -> b) -> ReaderT env m a -> ReaderT env m b
  fmap f (ReaderT r) = ReaderT $ \env -> fmap f (r env)

instance Applicative m => Applicative (ReaderT env m) where
  pure :: Applicative m => a -> ReaderT env m a
  pure x = ReaderT $ \_ -> pure x
  (<*>) :: Applicative m => ReaderT env m (a -> b) -> ReaderT env m a -> ReaderT env m b
  (ReaderT rf) <*> (ReaderT rx) = ReaderT $ \env -> rf env <*> rx env


instance MonadTrans (ReaderT env) where
  lift :: Monad m => m a -> ReaderT env m a
  lift ma = ReaderT $ \_ -> ma


askT :: Monad m => ReaderT env m env
askT = ReaderT return

localT :: (env -> env) -> ReaderT env m a -> ReaderT env m a
localT f (ReaderT g) = ReaderT $ \env -> g (f env)

-- Maybe transformers

newtype MaybeT m a = MaybeT { runMaybeT :: m (Maybe a) }

instance Functor m => Functor (MaybeT m) where
    fmap f (MaybeT mma) = MaybeT (fmap (fmap f) mma)

instance Monad m => Applicative (MaybeT m) where
    pure x = MaybeT (pure (Just x))
    (MaybeT mmf) <*> (MaybeT mmx) = MaybeT $ do
        mf <- mmf
        mx <- mmx
        return (mf <*> mx)

instance Monad m => Monad (MaybeT m) where
    return :: a -> MaybeT m a
    return = MaybeT . return . Just

    (>>=) :: MaybeT m a -> (a -> MaybeT m b) -> MaybeT m b
    (MaybeT mmx) >>= f = MaybeT $ do
        mx <- mmx
        case mx of
            Nothing -> return Nothing
            Just x  -> runMaybeT (f x)

instance MonadTrans MaybeT where
    lift :: Monad m => m a -> MaybeT m a
    lift ma = MaybeT (Just <$> ma)



-- Example: environment-based evaluator written with monad transformers

type Eval = ReaderT Env Maybe

evalEnv' :: Exp -> Eval Value
evalEnv' (Var _ x) = do
  env <- askT
  case M.lookup x env of
    Just v -> return v
    _ -> lift fail
evalEnv' (Abs _ x t) = do
  env <- askT
  return (VClo env x t)
evalEnv' (App _ t1 t2) = do
  v <- evalEnv' t1;
  case v of
    VClo cenv x t -> do
      v2 <- evalEnv' t2;
       -- evaluate t in the closure environment update with the argument value
      localT (\_ -> M.insert x v2 cenv) (evalEnv' t)
    _ -> lift fail
evalEnv' (Num _ n) = return $ VNum n
evalEnv' (Add _ t1 t2) = do
  v1 <- evalEnv' t1;
  v2 <- evalEnv' t2;
  case (v1, v2) of
    (VNum n1, VNum n2) -> return $ VNum (n1 + n2)
    _ -> lift fail