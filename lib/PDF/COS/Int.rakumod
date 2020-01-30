use v6;
use PDF::COS;

role PDF::COS::Int
    does PDF::COS {

    method flag-is-set(uint $flag-num) returns Bool {
	my uint $i = self;
	my \bit = 1 +< ($flag-num - 1);
	? ($i +& bit);
    }

    method content { :int(self+0) };
}

