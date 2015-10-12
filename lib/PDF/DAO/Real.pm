use v6;
use PDF::DAO;

role PDF::DAO::Real
    is PDF::DAO {
     method content { :real(self + 0) };
}

