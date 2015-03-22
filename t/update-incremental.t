use v6;
use Test;

use PDF::Reader;
use PDF::Writer;
use PDF::Object;

sub prefix:</>($name){ PDF::Object.compose(:$name) };

my $reader = PDF::Reader.new(:debug);

$reader.open( 't/pdf/pdf.in' );

my $root-obj = $reader.root.object;

my $Pages = $root-obj<Pages>;
my $Resources = $Pages<Kids>[0]<Resources>;
my $new-page = { :Type(/'Page'), :MediaBox[0, 0, 420, 595], :$Resources };
my $contents = PDF::Object.compose( :stream{ :decoded("BT /F1 24 Tf  100 250 Td (and they all lived happily ever after!) Tj ET" ), :dict{ :Length(46) } } );
$new-page<Contents> = $contents;
$Pages<Kids>.push: $new-page;
$Pages<Count> = $Pages<Count>++;

my $updates = $reader.get-objects( :updates-only);

is_deeply [ @$updates ], [ :ind-obj[3, 0, :dict{Count => :int(1),
                                           Kids => :array[ :ind-ref[4, 0],
                                                           :dict{ MediaBox => :array[ :int(0), :int(0), :int(420), :int(595)], 
                                                                  Resources => :dict{Font => :dict{F1 => :ind-ref[7, 0]},
                                                                                     ProcSet => :ind-ref[6, 0]},
                                                                  Contents => :stream{:encoded("BT /F1 24 Tf  100 250 Td (and they all lived happily ever after!) Tj ET"),
                                                                                      :dict{Length => :int(71)}},
                                                                  Type => :name<Page>}],
                                           Type => :name<Pages>,
                               }]], "update ast";
done;
