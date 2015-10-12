use v6;
use PDF::DAO;

role PDF::DAO::Bool
    is PDF::DAO {
    method content { :bool(?self) };
}

