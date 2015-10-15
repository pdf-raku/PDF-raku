use v6;
use Test;
use PDF::Storage::Input;

my $ioh = "t/helloworld.pdf".IO;

my $in-ioh = PDF::Storage::Input.coerce( $ioh );
my Str $str = $ioh.slurp( :enc<latin-1> );
my $in-str = PDF::Storage::Input.coerce( $str );

for :$in-ioh, :$in-str {
    my ($test, $input) = .kv;
    is $input.chars, $str.chars, "$test .chars";
    is $input.substr(1, 5), 'PDF-1', "$test head substr";
    is $input.substr(*-4), '%EOF', "$test tail substr";

    my %stream = :start<1>, :end<6>;
    is $input.stream-data( :%stream ), 'PDF-1.', "$test .stream-data";
}

done-testing;
