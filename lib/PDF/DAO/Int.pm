use v6;
use PDF::DAO;

role PDF::DAO::Int
    does PDF::DAO {

    method flag-is-set(uint $flag-num) returns Bool {
	my uint $i = self;
	my \bit = 1 +< ($flag-num - 1);
	? ($i +& bit);
    }

    method content { :int(self+0) };
}

