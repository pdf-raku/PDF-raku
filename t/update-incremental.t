use v6;
use Test;

use PDF::Reader;
use PDF::Writer;
use PDF::Object;
use PDF::Grammar::Test :is-json-equiv;

sub prefix:</>($name){ PDF::Object.compose(:$name) };

my $reader = PDF::Reader.new(:debug);

$reader.open( 't/pdf/pdf.in' );

my $root-obj = $reader.root.object;

my $Pages = $root-obj<Pages>;
my $Resources = $Pages<Kids>[0]<Resources>;
my $MediaBox = $Pages<Kids>[0]<MediaBox>;
my $new-page = { :Type(/'Page'), :$MediaBox, :$Resources };
my $contents = PDF::Object.compose( :stream{ :decoded("BT /F1 24 Tf  100 250 Td (and they all lived happily ever after!) Tj ET" ) } );
$new-page<Contents> = $contents;
$Pages<Kids>.push: $new-page;
$Pages<Count>++;

my $updates = $reader.get-updates;

todo "dodgey is-json-equiv() ?";
is-json-equiv [ @$updates ], [ { :Count(2),
                                 :Kids[ { :ind-ref[ 4, 0 ] },
                                        { :Type<Page>, :MediaBox[ 0, 0, 420, 595 ], :Resources{ :Font{ F1 => :ind-ref[ 7, 0 ]  },
                                                                                                ProcSet =>  :ind-ref[ 6, 0 ] },
                                          :Contents{ :Length(71) } }
                                     ],
                                 :Type<Pages> } ], "update ast";

# work in progress on implementation and tests,
# tba serilization and writing stages, todo:
# - based on https://blog.idrsolutions.com/2013/06/how-to-edit-pdf-files/, it seems that the updated
#   objects can be re-appended and reindexed without the need to increment generation numbers, manage
#   free lists, or cascade the updates back to the root Catalog (phew)
# - the objects that need updating are: Pages
# - new Stream and Page objects need to be written, object numbers: First+1, First+2 
# - updated Pages needs to be written
# - new incrmental index with entries for Pages, new Page and new Content. First = First+2

use PDF::Storage::Serializer;

my $serializer = ::('PDF::Storage::Serializer').new;

# only renumber new objects, starting from the highest input number + 1 (size)
$serializer.size = $reader.size;
$serializer.renumber = False;
# avoid automatical object traversal
temp $reader.tied = False;

for $updates.list -> $object {
    # reference count new objects
    $serializer.analyse( $object );
}

for $updates.list -> $object {
    $serializer.freeze( $object, :indirect )
}

my $updated-objects = $serializer.ind-objs;
is-json-equiv $updated-objects, [
    :ind-obj[3, 0, :dict{ Kids => :array[ :ind-ref[4, 0], :ind-ref[9, 0]],
                          Count => :int(2),
                          Type => :name<Pages>,
                         }],
    :ind-obj[9, 0, :dict{ MediaBox => :array[ :int(0), :int(0), :int(420), :int(595)],
                          Contents => :ind-ref[10, 0],
                          Resources => :dict{ Font => :dict{ F1 => :ind-ref[7, 0]},
                                              ProcSet => :ind-ref[6, 0]},
                          Type => :name<Page>,
                         }],
    :ind-obj[10, 0, :stream{ :encoded("BT /F1 24 Tf  100 250 Td (and they all lived happily ever after!) Tj ET"),
                             :dict{Length => :int(71) },
                            }],
    ], "serialized updates";

done;
