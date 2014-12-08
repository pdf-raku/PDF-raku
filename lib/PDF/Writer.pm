use v6;

class PDF::Writer {

    has Str $.input;

    use PDF::Grammar;

    multi method write( Array :$array! ) {
        ('[', $array.map({ $.write-obj($_) }), ']').join: ' ';
    }

    multi method write(Hash :$dict!, :@keys = $dict.keys.sort) {

        ('<<',
         @keys.map( -> $key {
             [~] $.write( :name($key)), ' ', $.write-obj( $dict{$key} ),
                    }),
         '>>').join: ' ';

    }

    multi method write( Any :$false! ) { 'false' }

    multi method write( Str :$hex-char! ) {
        sprintf '#%02X', $hex-char.ord
    }

    multi method write( Str :$hex-string! ) {
        [~] '<', $hex-string.comb.map({ 
            my $ord = .ord;
            die "illegal non-latin character in string: U+" ~ $ord.base(16)
                if $ord > 0xFF;
            sprintf '%02X', $ord;
        }), '>';
    }

    multi method write(Array :$ind-obj! ) {
        my ($obj-num, $gen-num, @objects) = @$ind-obj;

        (sprintf('%d %d obj', $obj-num, $gen-num),
         @objects.map({ $.write-obj($_) }),
         'endobj',
        ).join: "\n";
    }

    multi method write(Array :$ind-ref!) {
        ($ind-ref[0], $ind-ref[1], 'R').join: ' ';
    }

    multi method write(Int :$int!) {sprintf "%d", $int}

    BEGIN my %escapes = "\b" => 'b', "\f" => 'f', "\n" => 'n', "\r" => 'r', "\t" => 't'
        , "\n" => 'n', '(' => '(', ')' => ')', '\\' => '\\';

    multi method write( Str :$literal-string! ) {

        [~] '(',
            $literal-string.comb.map({
                %escapes{$_}:exists
                    ?? '\\' ~ %escapes{$_}
                    !! do {
                        when $_ ge ' ' && $_ le '~' { $_ }
                        when $_ ge "\o0" && $_ le "\o377" { sprintf "\\%03o", .ord }
                        default {die "illegal non-latin character in string: U+" ~ .ord.base(16)}
                    }
            }),
           ')';
    }

    multi method write( Str :$name! ) {
        [~] '/', $name.comb.map( {
            when '#' { '##' }
            when /<PDF::Grammar::name-reg-char>/ { $_ }
            default {
                sprintf '\\%x', .ord;
            }
        } )
    }

    multi method write( Any :$null! ) { 'null' }

    multi method write( Numeric :$number! ) {
        my $int = $number.Int;
        return ~($int == $number ?? $int !! $number);
    }

    multi method write( Numeric :$real! ) {
        ~$real
    }

    multi method write( Hash :$stream! ) {

        my $start = $stream<start>;
        my $end = $stream<end>;

        [~] (($stream<dict>.defined ?? $.write-obj( $stream, :node<dict>) !! ''),
             "\nstream\n",
             $.input.substr($start - 1, $end - $start) ~ "\n",
             "endstream\n");
    }

    multi method write( Hash :$trailer! ) {
        [~] "trailer\n",
        $.write( :dict( $trailer<dict> ), :keys<Size Root>),
        "\nstartxref\n",
        $.write( :int( $trailer<offset>) ),
        "\n";
    }

    multi method write( Any :$true! ) { 'true' }

    multi method write( *@args, *%opts ) is default {

        die "unexpected arguments: {[@args].perl}"
            if @args;
        
        die "unable to handle struct: {%opts.perl}"
    }

    # helper methods

    method write-obj($ast, :$node) {

        if $ast.isa(Hash) || $ast.isa(Pair) {
            # it's a token represented by a type/value pair
            my %params = $node.defined
                ?? $node => $ast{$node}
                !! $ast.flat;

            $.write( |%params );
        }
        else {
            warn "dunno how to write-obj: {$ast.perl}";
            '';
        }

    }

}
