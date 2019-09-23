module Codec.Archive.Zip.Conduit.Types where

import           Control.Exception (Exception(..))
import           Data.ByteString (ByteString)
import qualified Data.ByteString.Lazy as BSL
import qualified Data.Conduit as C
import           Data.Conduit.Binary (sourceLbs)
import           Data.String (IsString(..))
import           Data.Time.LocalTime (LocalTime)
import           Data.Typeable (Typeable)
import           Data.Word (Word64)

import           Data.Semigroup as Semigroup

-- |Errors thrown during zip file processing
newtype ZipError = ZipError String
  deriving (Show, Typeable)

instance IsString ZipError where
  fromString = ZipError

instance Exception ZipError where
  displayException (ZipError e) = "ZipError: " ++ e

-- |Summary information at the end of a zip stream.
data ZipInfo = ZipInfo
  { zipComment :: ByteString
  } deriving (Eq, Show)

-- |(The beginning of) a single entry in a zip stream, which may be any file or directory.
-- As per zip file conventions, directory names should end with a slash and have no data, but this library does not ensure that.
data ZipEntry = ZipEntry
  { zipEntryName       :: ByteString -- ^File name (in posix format, no leading slashes), with a trailing slash for directories
  , zipEntryNameIsUTF8 :: Bool -- ^True if 'zipEntryName' is encoded as UTF-8
  , zipEntryTime       :: LocalTime -- ^Modification time
  , zipEntrySize       :: Maybe Word64 -- ^Size of file data (if known); checked on zipping and also used as hint to enable zip64
  } deriving (Eq, Show)

-- |The data contents for a 'ZipEntry'. For empty entries (e.g., directories), use 'mempty'.
data ZipData m
  = ZipDataByteString BSL.ByteString -- ^A known ByteString, which will be fully evaluated (not streamed)
  | ZipDataSource (C.Source m ByteString) -- ^A byte stream producer, streamed (and compressed) directly into the zip

instance Monad m => Semigroup.Semigroup (ZipData m) where
  ZipDataByteString a <> ZipDataByteString b = ZipDataByteString $ a <> b
  a <> b = ZipDataSource $ sourceZipData a <> sourceZipData b

instance Monad m => Monoid (ZipData m) where
  mempty = ZipDataByteString BSL.empty
  mappend = (<>)

-- |Normalize any 'ZipData' to a simple source
sourceZipData :: Monad m => ZipData m -> C.Source m ByteString
sourceZipData (ZipDataByteString b) = sourceLbs b
sourceZipData (ZipDataSource s) = s

-- |Convert between unpacked (as 'Codec.Archive.Zip.Conduit.UnZip.unZipStream' produces) and packed (as 'Codec.Archive.Zip.Conduit.Zip.zipStream' consumes) representations.
-- This is mainly for testing purposes, or if you really want to re-zip a stream on the fly for some reason.
-- Note that each 'ZipData' must be consumed completely before the next entry can be produced.
-- packZipEntries :: C.Conduit (Either ZipEntry BS.ByteString) m (ZipEntry, ZipData m)
