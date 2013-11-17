-- This file is part of jwt - JSON Web Token
-- Copyright (C) 2013  Fraser Tweedale
--
-- jwt is free software: you can redistribute it and/or modify
-- it under the terms of the GNU Affero General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU Affero General Public License for more details.
--
-- You should have received a copy of the GNU Affero General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.

{-# LANGUAGE OverloadedStrings #-}

import Data.Maybe

import Data.Aeson
import Data.HashMap.Strict
import Data.Time
import System.Locale
import Test.Hspec

import Crypto.JOSE.Compact

import Crypto.JWT


intDate :: String -> Maybe IntDate
intDate = fmap IntDate . parseTime defaultTimeLocale "%F %T"

exampleClaimsSet :: ClaimsSet
exampleClaimsSet = emptyClaimsSet {
  claimIss = Just (Arbitrary "joe")
  , claimExp = intDate "2011-03-22 18:43:00"
  , unregisteredClaims = fromList [("http://example.com/is_root", Bool True)]
  }

main :: IO ()
main = hspec $ do
  describe "JWT Claims Set" $ do
    it "parses from JSON correctly" $
      let
        claimsJSON = "\
          \{\"iss\":\"joe\",\r\n\
          \ \"exp\":1300819380,\r\n\
          \ \"http://example.com/is_root\":true}"
      in
        decode claimsJSON `shouldBe` Just exampleClaimsSet

    it "formats to a parsable and equal value" $
      decode (encode exampleClaimsSet) `shouldBe` Just exampleClaimsSet

  describe "StringOrURI" $
    it "parses from JSON correctly" $ do
      decode "[\"foo\"]" `shouldBe` Just [Arbitrary "foo"]
      decode "[\"http://example.com\"]" `shouldBe`
        fmap OrURI (decode "[\"http://example.com\"]")
      decode "[\":\"]" `shouldBe` (Nothing :: Maybe [StringOrURI])
      decode "[12345]" `shouldBe` (Nothing :: Maybe [StringOrURI])

  describe "IntDate" $
    it "parses from JSON correctly" $ do
      decode "[0]"          `shouldBe` fmap (:[]) (intDate "1970-01-01 00:00:00")
      decode "[1382245921]" `shouldBe` fmap (:[]) (intDate "2013-10-20 05:12:01")
      decode "[\"notnum\"]"       `shouldBe` (Nothing :: Maybe [IntDate])

  describe "§6.1.  Example Plaintext JWT" $
    it "can be decoded and validated" $
      let
        exampleJWT = "eyJhbGciOiJub25lIn0\
          \.\
          \eyJpc3MiOiJqb2UiLA0KICJleHAiOjEzMDA4MTkzODAsDQogImh0dHA6Ly9leGFt\
          \cGxlLmNvbS9pc19yb290Ijp0cnVlfQ\
          \."
        jwt = decodeCompact exampleJWT
        k = fromJust $ decode "{\"kty\":\"oct\",\"k\":\"\"}"
      in do
        fmap jwtClaimsSet jwt `shouldBe` Right exampleClaimsSet
        fmap (validateJWT k) jwt `shouldBe` Right True
