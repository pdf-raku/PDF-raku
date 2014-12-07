use v6;

class PDF::Writer {

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

    multi method write(Int :$integer!) {sprintf "%d", $integer}

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
                        default {die "illegal non-latin character in string: \\x" ~ .ord.base(16)}
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
        return ($int == $number ?? $int !! $number);
    }

    multi method write( Hash :$trailer! ) {
        [~] "trailer\n",
        $.writeX( :dict( $trailer<dict> ), :keys<Size Root>),
        "startxref\n",
        $.writeX( :integer( $trailer<byte-offset>) );
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
                ?? $node => %params{$node}
                !! $ast.flat;

            $.write( |%params );
        }
        else {
            warn "dunno how to write-obj: {$ast.perl}";
            '';
        }

    }

}
