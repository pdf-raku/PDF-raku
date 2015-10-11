use v6;
use PDF::Object;

role PDF::Object::Int
    is PDF::Object {

    method flag-is-set(UInt $flag-num) returns Bool {
	my $i := self;
	my $bit := 1 +< ($flag-num - 1);
	? ($i +& $bit);
    }

    method content { :int(self+0) };
}

