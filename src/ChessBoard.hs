module ChessBoard (
    Board -- Don't expose the constructor!
  , MoveResult
  , MoveRecord
  , MoveRecords
  , BoardSquare
  , initBoard
  , pieceAt
  , removePieceAt
  , move
  , boardToList ) where

import Data.List (intercalate)
import Data.Vector (Vector,toList,fromList,(!),(//))
import qualified Data.Vector as V
import ChessBoard.Position
import ChessBoard.Pieces

data Board = Board (Vector(Vector BoardSquare)) deriving (Eq)

-- | Left if the move was invalid, otherwise return success of the new board
-- and the piece / board square that was captured
type MoveResult  = Either String (Board,BoardSquare)

-- | A square of the chess board may contain a piece, or it may not.
type BoardSquare = Maybe PlayerPiece

type MoveRecord = (PieceNum, Position, Position)
type MoveRecords = [MoveRecord]

-- | Prints the board out in an text based grid
instance Show Board where
  show board = (unlines ((borderLine : boardStr) ++ [borderLine,bottomLegend]))
    where
      l                    = boardToList board
      boardStr             = zipWith showLine (reverse [1..8]) $ reverse l
      showSquare Nothing   = "  "
      showSquare (Just pp) = show pp
      borderLine           = "  " ++ (replicate 41 '-' )

      showLine :: Integer -> [BoardSquare] -> String
      showLine i pps       =
        (intercalate " | " $ (show i) : (map showSquare pps) ) ++ " |"
      bottomLegend         =
        (intercalate " |  " $ ( " " : map (:[]) ['A'..'H'] ) ) ++ " |"

-- | Create a board initialised to the standard start of game layout.
initBoard :: Board
initBoard = Board $ fromList $ map fromList $ concat [
  [ whiteRearLine, whiteFrontLine ]
  , (replicate 4 emptyLine)
  , [ blackFrontLine, blackRearLine]
  ]
  where
    whiteFrontLine   = frontLine White
    whiteRearLine    = rearLine White
    blackFrontLine   = frontLine Black
    blackRearLine    = rearLine Black
    emptyLine        = replicate 8 Nothing
    pieceIds player  = if player == White then [1..16] else [17..32]
    frontLine player = [Just $ PlayerPiece piece_id player Pawn | i <- [0..7], let piece_id = pieceIds player !! i]
    rearLine  player = [Just $ PlayerPiece piece_id player piece | (piece, i) <- zip [
      Rook
      ,Knight
      ,Bishop
      ,Queen
      ,King
      ,Bishop
      ,Knight
      ,Rook
      ] [0..7], let piece_id = pieceIds player !! (i + 8)]

-- | Query the piece at this position. There may not be a piece, of course.
pieceAt :: Board -> Position -> BoardSquare
pieceAt board pos = pieceAtCoord board $ posToCoord pos

-- | Remove the piece at the specified spot. Returns the new board state.
removePieceAt :: Board -> Position -> Board
removePieceAt (Board v) pos = let
  (x,y) = posToCoord pos
  in Board $ v // [ (x,((v ! x) // [(y,Nothing)]))]

{- |
Move from start position to end position. You will get a left under any of
these conditions:
  * There is no piece at the start position.
  * The start and the end are the same position
  * The move will capture a piece of the same team ( this isn't specified in the
    spec but seems pretty sensible to restrict )
Otherwise you will get a Right containing a new board and an optional piece
that was captured.
-}
move ::
  Board
  -> Position -- ^ Start position
  -> Position -- ^ End position
  -> MoveResult
move board start end = let
  startC = posToCoord start
  endC   = posToCoord end
  in
   move' board startC endC (pieceAtCoord board startC) (pieceAtCoord board endC)


-- | This takes a board and converts it to a list. Allows testing code and
-- clients the ability to deconstruct a board without accessing the constructor.
boardToList :: Board -> [[BoardSquare]]
boardToList (Board l) = toList $ V.map toList l

--------------------------------------------------------------------------------
-- Private Functions Below. Not for export since they deal with coords and break
-- the position abstraction.
--------------------------------------------------------------------------------

move' :: Board -> Coord -> Coord -> BoardSquare -> BoardSquare -> MoveResult
move' _ _ _ Nothing _           = Left "No piece at starting position!"
move' b sC eC (Just p1) Nothing = Right ((newBoard b sC eC p1),Nothing)

-- This function is really ugly. Must be a better way...
move' b sC eC (Just pp1@(PlayerPiece _ p1 _)) (Just pp2@(PlayerPiece _ p2 _)) =
  if pp1 == pp2
  then Left "Must move to a different position!"
  else
    if p1 == p2
    then Left "You probably don't want to capture your own piece!"
    else Right ((newBoard b sC eC pp1),Just(pp2))

newBoard :: Board -> Coord -> Coord -> PlayerPiece -> Board
newBoard (Board v) (sx,sy) (ex,ey) piece = Board $
  if sx == ex
  then v // [ (sx,( (v ! sx) // [(sy,Nothing),(ey,(Just piece))]))]
  else v // [
    (sx,(v ! sx) // [(sy,Nothing)])
    , (ex,(v ! ex) // [(ey,(Just piece))])
    ]

pieceAtCoord :: Board -> Coord -> BoardSquare
pieceAtCoord (Board b) (xCoord,yCoord) = b ! xCoord ! yCoord
