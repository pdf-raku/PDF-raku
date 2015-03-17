use v6;

role PDF::Reader::Tied {

    has $.reader is rw;
    has Int $.obj-num is rw;
    has Int $.gen-num is rw;
    has %!anon-ties;

    #| for array lookups, typically $foo[42]
    method AT-POS(|c) is rw {
        my $result := callsame;
        $result ~~ Pair | Array | Hash
            ?? $.deref($result )
            !! $result;
    }

    #| for hash lookups, typically $foo<bar>
    method AT-KEY(|c) is rw {
        my $result := callsame;
        $result ~~ Pair | Array | Hash
            ?? $.deref($result )
            !! $result;
    }

    multi method deref(Pair $ind-ref! is rw) {
        return $ind-ref unless $ind-ref.key eq 'ind-ref';

        my $obj-num = $ind-ref.value[0];
        my $gen-num = $ind-ref.value[1];

        my $result = $.reader.tied( $obj-num, $gen-num );
    }

    multi method deref($value where Hash | Array ) {

        my $id = $value.WHERE;

        %!anon-ties{$id} //= do {
            my $tied := do given $value {
                when .can('deref') { $value }
                when Array | Hash {
                    # direct array object
                    $value but PDF::Reader::Tied; 
                }
                default {
                    die "unhandled: {.perl}";
                }
            };

            $tied.reader = $.reader;
            $tied;

        };
    }

}
