use v6;
use PDF::DAO;

role PDF::DAO::Name
    is PDF::DAO {

    method content {
        :name(self~'')
    };
}

