use v6;
use PDF;
use Test;

# COS is the serialization format that underlies PDF.
# simple COS example that implements a hypothetical JAR archive
# - root contains language versioning, and root classes
# - simple tree of Subclasses
# - each class may contain
#   -- array of Subclassess
#   -- Object for compiled object code
#   -- Source input source file
#   -- Author and Description 

use PDF;

class COS::JAR
    is PDF {

    use PDF::COS::Tie;
    use PDF::COS::Tie::Hash;
    use PDF::COS::Tie::Array;
    use PDF::COS::Name;
    use PDF::COS::TextString;
    use PDF::COS::Stream;

    role Class does PDF::COS::Tie::Hash {
        has PDF::COS::Name $.Name is entry;
        has Class @.Subclasses is entry(:indirect);
        has PDF::COS::Stream $.Source is entry;
        has PDF::COS::Stream $.Object is entry;
        # Unicode strings
        has PDF::COS::TextString $.Author is entry;
        has PDF::COS::TextString $.Description is entry;
    }

    role Manifest does PDF::COS::Tie::Hash {
        has PDF::COS::Name $.Language is entry;
        has Str $.Version is entry;
        has Class @.Classes is entry(:indirect);
    }

    has Manifest $.Root is entry(:indirect);
    method type {'JAR'}

    # only accept %JAR files
    method open(|c) { nextwith( :type<JAR>, |c); }
}

# ensure consistant document ID generation
my $id = $*PROGRAM-NAME.fmt('%-16.16s');

my COS::JAR $jar .= new;
$jar.Root = { :Language<LOLCODE>, :Version("1.2"), :Classes[] };
does-ok $jar.Root, COS::JAR::Manifest;
is $jar.Root.Language, 'LOLCODE', 'accessor';
is $jar.Root.Version, '1.2', 'accessor';

my $decoded = q:to<\_(ツ)_/>;
HAI 1.2
CAN HAS STDIO?
VISIBLE "HAI WORLD!"
KTHXBYE
\_(ツ)_/

my PDF::COS::Stream() $Source = { :$decoded, :dict{ :Filter<FlateDecode> } };

my $Description = "Moon phases: \x1f311\x1f313\x1f315\x1f317";

$jar.Root.Classes.push: { :Name( :name<MAIN> ), :$Source, :Author("Heydər Əliyev"), :$Description};
$jar.id = $id++;
lives-ok {$jar.save-as: "t/lolcode.cjar" }, 'save as cos';
$jar.id = $id++;
lives-ok {$jar.save-as: "tmp/lolcode.cjar.json" }, 'save as json';
dies-ok { $jar.open: "t/helloworld.pdf" }, "PDF open as JAR - fails";
lives-ok {$jar .= open: "t/lolcode.cjar" }, "open";

does-ok $jar, COS::JAR;
is $jar.type, 'JAR', 'read type';
is-deeply $jar.Root.reader, $jar.reader, 'root reader';
is $jar.Root.Language, 'LOLCODE', 'read accessor';
is $jar.Root.Classes[0].Author, "Heydər Əliyev", 'text string latinish';
is $jar.Root.Classes[0].Description, $Description, 'text string with utf-16 surrogates';

done-testing;



