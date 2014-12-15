use v6;

class PDF::Writer {

    has Str $.input;

    use PDF::Grammar;

    multi method write( Array :$array! ) {
        ('[', $array.map({ $.write-obj($_) }), ']').join: ' ';
    }

    multi method write( Array :$body!, :$offset! is rw ) {
        $body.map({ $.write( :body($_), :$offset )}).join: "\n";
    }

    multi method write( Hash :$body!, :$offset! is rw ) {
        my $object-count = 1;
        my $object-first-num = 0;
        my @entries = %( :offset(0), :gen(65535), :status<f>, :obj(0) ).item;
        my @out;

        for $body<objects>.list -> $obj {

            if my $ind-obj = $obj<ind-obj> {
                my $obj = $ind-obj[0].Int;
                my $gen = $ind-obj[1].Int;

                $object-count++;
                # hardcode status, for now
                @entries.push: %( :$offset, :$gen, :status<n>, :$obj, :$gen ).item;
                @out.push: $.write( :$ind-obj );
            }
            elsif my $comment = $obj<comment> {
                @out.push: $.write( :$comment );
            }
            else {
                die "don't know how to serialize body component: {$obj.perl}"
            }

            $offset += @out[*-1].chars + 1;
        }

        my $xref-offset = $offset;

        @entries = @entries.sort: { $^a<obj> <=> $^b<obj> || $^a<gen> <=> $b<gen> };

        my %xref = :$object-first-num, :$object-count, :@entries;
        @out.push: $.write( :%xref );
        $offset += @out[*-1].chars + 1;

        my $trailer = $body<trailer>
            // die "body does not have a trailer";

        @out.push: $.write( :$trailer, :$xref-offset );
        $offset += @out[*-1].chars + 1;

        return @out.join: "\n";
    }

    multi method write( :$body! ) {
        my $offset = 0;
        $.write( :$body, :$offset );
    }

    multi method write( Bool :$bool! ) {
        $bool ?? 'true' !! 'false';
    }

    multi method write(List :$comment!) {
        $comment.map({ $.write( :comment($_) ) }).join: "\n";
    }

    multi method write(Str :$comment!) {
        $comment ~~ /^ '%'/ ?? $comment !! '% ' ~ $comment;
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

    multi method write( Str :$literal! ) {

        [~] '(',
            $literal.comb.map({
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
                .encode.list.map({ sprintf '#%02x', $_ }).join('');
            }
        } )
    }

    multi method write( Any :$null! ) { 'null' }

    multi method write( Numeric :$number! ) {
        my $int = $number.Int;
        return ~($int == $number ?? $int !! $number);
    }

    multi method write( Hash :$pdf! ) {
        my $header = $.write-obj( $pdf, :node<header> );
        my $comment = $pdf<comment>:exists
            ?? $.write-obj( $pdf, :node<comment> ) ~ "\n"
            !! '';
        my $offset = $header.chars + $comment.chars + 1;  # since format is byte orientated
        my $body = $.write( :body($pdf<body>), :$offset );
        [~] ($header, "\n", $comment, $body, '%%EOF', '');
    }

    multi method write(Any :$header! ) {
        sprintf '%%PDF-%.1f', $header<version> // 1.2;
    }

    multi method write( Numeric :$real! ) {
        ~$real
    }

    multi method write( Hash :$stream! ) {

        my $start = $stream<start>;
        my $end = $stream<end>;

        my $length = $end - $start + 1;
        my %dict = %( $stream<dict> // { } );
        %dict<Length> //= :int($length);

        ($.write( :%dict ),
         "stream",
         $.input.substr($start - 1, $length - 1 ),
         "endstream",
        ).join: "\n";
    }

    multi method write( Hash :$trailer!, :$xref-offset is copy ) {

        $xref-offset //= $trailer<offset>;

        [~] ( "trailer\n",
              $.write( :dict( $trailer<dict> )),
              ( $xref-offset.defined
                ?? ( "\nstartxref\n",
                     $.write( :int( $xref-offset) )
                   )
                !! ()
              ),
              "\n",
            );
    }

    multi method write( Any :$true! ) { 'true' }

    multi method write(Array :$xref!) {
        ( $xref.map({ $.write( :xref($_) ) }), '').join: "\n";
    }

    multi method write(Hash :$xref!) {
        (
         'xref',
         $xref<object-first-num> ~ ' ' ~ $xref<object-count>,
         $xref<entries>.map({
             sprintf '%010d %05d %s ', .<offset>, .<gen>, .<status>
         }),
        ).join: "\n";
    }

    multi method write( *@args, *%opts ) is default {

        die "unexpected arguments: {[@args].perl}"
            if @args;
        
        die "unable to handle {%opts.keys} struct: {%opts.perl}"
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
