use v6;
use PDF;
use Test;

# simple COS example that implements a hypothetical JAR archive
# - root contains language versioning, and root classes
# - simple tree of Subclasses
# - each class may contain
#   -- Object for compiled object code
#   -- Source input source file

use PDF;

class COS::JAR
    is PDF {

    use PDF::COS::Tie;
    use PDF::COS::Tie::Hash;
    use PDF::COS::Tie::Array;
    use PDF::COS::Name;
    use PDF::COS::Stream;

    role Class does PDF::COS::Tie::Hash {
        has PDF::COS::Name $.Name is entry;
        has Class @.Subclasses is entry(:indirect);
        has PDF::COS::Stream $.Source is entry;
        has PDF::COS::Stream $.Object is entry;
    }

    role Manifest does PDF::COS::Tie::Hash {
        has PDF::COS::Name $.Language is entry;
        has Str $.Version is entry;
        has Class @.Classes is entry(:indirect);
    }

    has Manifest $.Root is entry(:indirect);
    method type {'JAR'}

    method open(|c) {
        my $jar = callsame;

	die "JAR file has wrong type: " ~ $jar.reader.type
	    unless $jar.reader.type eq 'JAR';

        $jar;
    }
}

# ensure consistant document ID generation
srand(123456);

my $jar = COS::JAR.new;
$jar.Root = { :Language<LOLCODE>, :Version("1.2"), :Classes[] };
does-ok $jar.Root, COS::JAR::Manifest;
is $jar.Root.Language, 'LOLCODE', 'accessor';
is $jar.Root.Version, '1.2', 'accessor';

my $decoded = q:to<--ENUFF-->;
HAI 1.2
CAN HAS STDIO?
VISIBLE "HAI WORLD!"
KTHXBYE
--ENUFF--

my $Source = PDF::COS.coerce: :stream{ :$decoded, :dict{ :Filter<FlateDecode> } };

$jar.Root.Classes.push: { :Name( :name<MAIN> ), :$Source };

lives-ok {$jar.save-as: "t/lol.cjar"}, 'save as cos';
lives-ok {$jar.save-as: "t/lol.cjar.json"}, 'save as json';

lives-ok {$jar = $jar.open("t/lol.cjar");}, "open";

does-ok $jar, COS::JAR;
is $jar.type, 'JAR', 'read type';
is $jar.Root.Language, 'LOLCODE', 'read accessor';

done-testing;



