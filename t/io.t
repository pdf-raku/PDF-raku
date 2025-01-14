use v6;
use Test;
plan 37;

use PDF::IO;

my IO $ioh = "t/helloworld.pdf".IO;
my Blob $blob = $ioh.slurp(:bin);
my Str $str = $blob.decode('latin-1');

my PDF::IO() $in-ioh = $ioh;
isa-ok $in-ioh, 'PDF::IO::Handle';

my PDF::IO() $in-blob = $blob;
isa-ok $in-blob, 'PDF::IO::Blob';
is  $in-blob.byte-str(1, 5), 'PDF-1';
is $in-blob.encoding, 'latin-1';

my PDF::IO() $in-str = $str;
isa-ok $in-str, 'PDF::IO::Str';

for :$in-ioh, :$in-blob, :$in-str {
    my ($test, $input) = .kv;

    isa-ok $input.COERCE($input), PDF::IO;
    is $input.codes, $str.codes, "$test .codes";
    next if $input.isa('PDF::IO::Blob');

    is $input.read(4).decode("latin-1"), "%PDF", "$test read";
    lives-ok {$input.seek(1, SeekFromCurrent);}, "$test seek";
    is $input.read(3).decode("latin-1"), "1.4", "$test read";
    is $input.byte-str(1, 5), 'PDF-1', "$test head byte-str";
    nok $input.eof, "$test not at eof yet";
    $input.read(9999);
    ok $input.eof, "$test now at eof";
    is $input.byte-str(*-4), '%EOF', "$test tail byte-str";
    lives-ok {$input.seek(1, SeekFromBeginning);}, "$test seek from beginning";
    is $input.read(3).decode("latin-1"), "PDF", "$test read from beginning";
    lives-ok {$input.seek(-4, SeekFromEnd);}, "$test seek from end";
    is $input.read(1).decode("latin-1"), "%", "$test read from end";
    is-deeply $input.slurp.decode('latin-1'), 'EOF', "$test slurp";
    lives-ok { $input.close }, "$test close";
}

done-testing;
