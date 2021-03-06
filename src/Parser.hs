module Parser where

import Text.ParserCombinators.Parsec
import Data.List
import Control.Applicative hiding ((<|>), many, optional)

type Name = String

data Expr =
  Bool Bool
  | Number Double
  | String String
  | Symbol Name
  | Var Name
  | If Expr Expr Expr
  | Let Name Expr (Maybe Expr)
  | Apply Expr Expr
  | Lambda [Name] Expr
  deriving (Show)

keywords = ["if", "then", "else", "True", "False", "let", "def", "sig"]
keySyms = ["->", "=>", ":", "|", "=", ";", "\\"]
lexeme p = p <* spaces
schar = lexeme . char

keyword k = lexeme . try $
  string k <* notFollowedBy alphaNum

keysim k = lexeme . try $
  string k <* notFollowedBy (oneOf "><=+-*/^~!%@&$")

checkParse p = lexeme . try $ do
  s <- p
  if s `elem` (keywords ++ keySyms)
    then unexpected $ "reserved word " ++ show s
    else return s

pBool :: Parser Bool
pBool = (True <$ keyword "True") <|> (False <$ keyword "False")

pDouble :: Parser Double
pDouble = lexeme $ do
  ds <- many1 digit
  option (read ds) $ do
    char '.'
    ds' <- many1 digit
    return $ read (ds ++ "." ++ ds')

pString :: Parser String
pString = lexeme . between (char '"') (char '"') . many1 $ noneOf "\""

pVariable :: Parser String
pVariable = checkParse $ many1 letter

pSymbol :: Parser String
pSymbol = checkParse $ many1 $ oneOf "><=+-*/^~!%@&$"

pParens :: Parser Expr
pParens = between (schar '(') (schar ')') pExpr

pTerm :: Parser Expr
pTerm = choice [ Number   <$> pDouble,
                 String   <$> pString,
                 Var <$> pVariable,
                 Symbol   <$> pSymbol,
                 pParens,
                 pLambda ]

pApply :: Parser Expr
pApply = chainl1 pTerm $ pure Apply

pIf :: Parser Expr
pIf = If <$ keyword "if"   <*> pExpr
         <* keyword "then" <*> pExpr
         <* keyword "else" <*> pExpr

pLambda :: Parser Expr
pLambda = Lambda <$ keysim "\\" <*> many pVariable
                 <* keysim "=>" <*> pExpr

pLet :: Parser Expr
pLet = Let <$ keyword "let" <*> pVariable
           <* keysim "=" <*> pExpr
           <* keysim ";" <*> optionMaybe pExpr

pExpr :: Parser Expr
pExpr = choice [pIf, pApply, pLet, pTerm]

grab s = case parse (spaces *> pExpr <* eof) "" s of
  Right val -> val
  Left err -> error $ show err

--test parser = parse (spaces *> parser <* eof) ""
