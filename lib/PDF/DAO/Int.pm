use v6;
use PDF::DAO;

role PDF::DAO::Int
    is PDF::DAO {

    method flag-is-set(UInt $flag-num) returns Bool {
	my Int $i = self;
	if $i < 0 {
	    # assume two's compliment for negative nasks
	    my $sign-bit = 1;
	    $sign-bit *= 2
		while $sign-bit <= -$i;
	    $i += $sign-bit
	}
	
	my $bit := 1 +< ($flag-num - 1);
	? ($i +& $bit);
    }

    method content { :int(self+0) };
}

