use v6;
use PDF::DAO;

role PDF::DAO::Int
    does PDF::DAO {

    method flag-is-set(UInt $flag-num) returns Bool {
	my Int $i = self;
	if $i < 0 {
	    my uint32 @u32 = ($i);
	    $i = @u32[0];
	}
	
	my $bit := 1 +< ($flag-num - 1);
	? ($i +& $bit);
    }

    method content { :int(self+0) };
}

