use v6;

use PDF::Reader;
use PDF::Object;

role PDF::Reader::Tied {

    has PDF::Reader $.reader is rw;
    has Int $.obj-num is rw;
    has Int $.gen-num is rw;
    has %!anon-ties;

    multi method deref(Pair $ind-ref! is rw where .key eq 'ind-ref') {

        my $obj-num = $ind-ref.value[0];
        my $gen-num = $ind-ref.value[1];

        my $result = $.reader.tied( $obj-num, $gen-num );
    }

    multi method deref($value where Hash | Array ) {

        my $id = $value.WHERE;
        return %!anon-ties{$id}
            if %!anon-ties{$id}:exists;

        %!anon-ties{$id} := do given $value {
            when Array {
                # direct array object
                require ::('PDF::Reader::Tied::Array');
                my $tied-array = $value but ::('PDF::Reader::Tied::Array'); 
                $tied-array.reader = $.reader;
                $tied-array;
            }
            when Hash {
                # direct dict object
                require ::('PDF::Reader::Tied::Hash');
                my $tied-hash = $value but ::('PDF::Reader::Tied::Hash'); 
                $tied-hash.reader = $.reader;
                $tied-hash;
            }
            default {
                die "unhandled: {.perl}";
            }
        }
    }

}
