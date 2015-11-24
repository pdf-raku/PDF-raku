use v6;
use PDF::DAO;

class PDF::DAO::Null
    does PDF::DAO
    is Any {
    method defined { False }
    method content { :null(Any) };
}

