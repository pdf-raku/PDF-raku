use v6;
use PDF::DAO;

role PDF::DAO::Bool {
    method content { :bool(?self) };
}

