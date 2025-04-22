use Test;
plan 4;

use PDF;
use PDF::IO::Crypt::PDF;
use PDF::COS::Name;
use PDF::COS::Stream;
sub prefix:</>($s) { PDF::COS::Name.COERCE($s) };

my $xml = '<Test/>';
my PDF::COS::Stream:D() $metadata = %(:dict{:Type(/'Metadata'), :Subtype(/'XML')}, :decoded($xml));

for False, True -> $aes {
    for False, True -> $EncryptMetadata {
        subtest (:$EncryptMetadata, :$aes).raku, {
            my PDF $pdf .= new;
            $pdf<Root><Type> = /'Catalog';
            $pdf<Root><Metadata> = $metadata;
            $pdf.encrypt: :owner-pass<test>, :$EncryptMetadata, :$aes;
            is-deeply $pdf.crypt.EncryptMetadata, $EncryptMetadata;
            is-deeply $pdf.crypt.type, ($aes ?? 'AESV2' !! 'V2').List;
            given $pdf.ast<cos><body>[0]<objects>.first(* ~~ :ind-obj[UInt, UInt, :stream]) {
                my $encoded = .<ind-obj>[2]<stream><encoded>;
                if $EncryptMetadata {
                    isnt $encoded, $xml, 'metadata is encrypted';
                }
                else {
                    is $encoded, $xml, 'metadata is not encrypted';
                }
            }
        }
    }
}
