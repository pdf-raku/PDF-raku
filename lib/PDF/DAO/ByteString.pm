use v6;
use PDF::DAO;

role PDF::DAO::ByteString
    is PDF::DAO {
    has Str $.type is rw;

    method content { $!type => self~'' };
}

