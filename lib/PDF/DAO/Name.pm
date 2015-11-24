use v6;
use PDF::DAO;

role PDF::DAO::Name
    does PDF::DAO {

    method content {
        :name(self~'')
    };
}

