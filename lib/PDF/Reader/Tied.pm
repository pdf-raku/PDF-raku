use v6;

use PDF::Reader;
use PDF::Object;

role PDF::Reader::Tied {

    has PDF::Reader $.reader is rw;
    has Int $.obj-num is rw;
    has Int $.gen-num is rw;

    multi method tied(Pair $ind-ref! where .key eq 'ind-ref') {

        my $obj-num = $ind-ref.value[0];
        my $gen-num = $ind-ref.value[1];

        my $result = $.reader.tied( $obj-num, $gen-num );
    }

    multi method tied($value) is default {

        my $result = do given $value {
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
                $value;
            }
        }

        $result;
    }

}
