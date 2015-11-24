use v6;
use PDF::DAO;

role PDF::DAO::ByteString
    does PDF::DAO {
    has Str $.type is rw;

    method content { $!type => self~'' };
}

