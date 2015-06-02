use v6;
use Test;

use PDF::Reader;
use PDF::Writer;
use PDF::Object;
use PDF::Storage::Serializer;
use PDF::Grammar::Test :is-json-equiv;

sub prefix:</>($name){ PDF::Object.compose(:$name) };

my $reader = PDF::Reader.new();

't/pdf/pdf.in'.IO.copy('t/pdf/pdf-updated.out');
$reader.open( 't/pdf/pdf-updated.out', :a );

my $root = $reader.root;
my $root-obj = $root.object;

{
    my $Pages = $root-obj<Pages>;
    my $Resources = $Pages<Kids>[0]<Resources>;
    my $MediaBox = $Pages<Kids>[0]<MediaBox>;
    my $new-page = { :Type(/'Page'), :$MediaBox, :$Resources };
    my $contents = PDF::Object.compose( :stream{ :decoded("BT /F1 16 Tf  88 250 Td (and they all lived happily ever after!) Tj ET" ) } );
    $new-page<Contents> = $contents;
    $Pages<Kids>.push: $new-page;
    $Pages<Count>++;
}

my $updated-objects = $reader.get-updates;
{
    temp $reader.auto-deref = False;
    is-json-equiv [ @$updated-objects ], [ { :Count(2),
                                     :Kids[ { :ind-ref[ 4, 0 ] },
                                            { :Type<Page>,
                                              :MediaBox[ 0, 0, 420, 595 ],
                                              :Resources{ :Font{ F1 => :ind-ref[ 7, 0 ] },
                                                           ProcSet =>  :ind-ref[ 6, 0 ] },
                                              :Contents{ :Length(70) },
                                             }
                                         ],
                                     :Type<Pages> } ], "updated objects";
}

my $serializer = PDF::Storage::Serializer.new;

my $body = $serializer.body( $reader, :updates );
is-deeply $body<trailer><dict><Root>, (:ind-ref[1, 0]), 'body trailer dict - Root';
is-deeply $body<trailer><dict><Size>, (:int(11)), 'body trailer dict - Size';
is-deeply $body<trailer><dict><Prev>, (:int(578)), 'body trailer dict - Prev';
$updated-objects = $body<objects>;
is +$updated-objects, 3, 'number of updates';
is-json-equiv $updated-objects[0], (
    :ind-obj[3, 0, :dict{ Kids => :array[ :ind-ref[4, 0], :ind-ref[9, 0]],
                          Count => :int(2),
                          Type => :name<Pages>,
                         }]), 'altered /Pages';

is-json-equiv $updated-objects[1], (
    :ind-obj[9, 0, :dict{ MediaBox => :array[ :int(0), :int(0), :int(420), :int(595)],
                          Contents => :ind-ref[10, 0],
                          Resources => :dict{ Font => :dict{ F1 => :ind-ref[7, 0]},
                                              ProcSet => :ind-ref[6, 0]},
                          Parent => :ind-ref[3, 0],
                          Type => :name<Page>,
                         }]), 'inserted page';

is-json-equiv $updated-objects[2], (
    :ind-obj[10, 0, :stream{ :encoded("BT /F1 16 Tf  88 250 Td (and they all lived happily ever after!) Tj ET"),
                             :dict{Length => :int(70) },
                            }]), 'inserted content';

my $offset = $reader.input.chars + 1;
my $prev = $body<trailer><dict><Prev>.value;
my $writer = PDF::Writer.new( :$root, :$offset, :$prev );
my $new-body = "\n" ~ $writer.write( :$body );

# todo append to reader input
##$reader.input.append( $new-body );
't/pdf/pdf-updated.out'.IO.open(:a).write( $new-body.encode('latin-1') );

# ensure that reader has remained lazy. should not have loaded unreferenced objects
ok $reader.ind-obj( 3, 0, :!eager ), 'referenced object loaded (Pages)';
nok $reader.ind-obj( 5, 0, :!eager ), 'unreferenced object not loaded (Page 1 content)';

# now re-read the pdf. Will also test our ability to read a PDF
# with multiple segments

$reader = Mu;

$reader = PDF::Reader.new();
$reader.open( 't/pdf/pdf-updated.out', :a );

my $ast = $reader.ast;
is +$ast<pdf><body><objects>, 10, 'read-back has 10 objects';
is $ast<pdf><body><objects>[9], ( :ind-obj[10, 0, :stream{ :dict{ Length => :int(70)},
                                                           :encoded("BT /F1 16 Tf  88 250 Td (and they all lived happily ever after!) Tj ET")},
                              ]), 'inserted content';

# do a full rewrite of the updated PDF. Output should be cleaned up, with a single body and
# cleansed of old object versions.
$writer = PDF::Writer.new( :$root );
ok 't/pdf/pdf-updated-and-rewritten.out'.IO.spurt( $writer.write( $ast ), :enc<latin-1> ), 're-read + rewrite of updated PDF';

done;
