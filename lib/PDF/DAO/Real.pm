use v6;
use PDF::DAO;

role PDF::DAO::Real
    does PDF::DAO {
     method content { :real(self + 0) };
}

