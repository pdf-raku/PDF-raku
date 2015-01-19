use v6;

class PDF::Core::Writer {

    use PDF::Grammar;
    use PDF::Core;
    use PDF::Core::IndObj;

    has PDF::Core $.pdf;
    has $.offset is rw = 0;
    has $.prev-xref-offset is rw;

    submethod BUILD( :$!pdf! ) {}

    multi method write( Array :$array! ) {
        ('[', $array.map({ $.write($_) }), ']').join: ' ';
    }

    multi method write( Array :$body! ) {
        $body.map({ $.write( :body($_) )}).join: "\n";
    }

    multi method write( Hash :$body! ) {
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
                @entries.push: %( :$.offset, :$gen, :status<n>, :$obj, :$gen ).item;
                @out.push: $.write( :$ind-obj );

            }
            elsif my $comment = $obj<comment> {
                @out.push: $.write( :$comment );
            }
            else {
                die "don't know how to serialize body component: {$obj.perl}"
            }

            $.offset += @out[*-1].chars + 1;
        }

        my $xref-offset = $.offset;
        my $prev-xref-offset = $.prev-xref-offset;

        @entries = @entries.sort: { $^a<obj> <=> $^b<obj> || $^a<gen> <=> $b<gen> };

        my %xref = :$object-first-num, :$object-count, :@entries;
        @out.push: $.write( :%xref );
        $.offset += @out[*-1].chars + 1;
        my $trailer = $body<trailer>
            // die "body does not have a trailer";
        @out.push: $.write( :$trailer, :$xref-offset, :$prev-xref-offset, :size(+@entries) );
        $.prev-xref-offset = $xref-offset;
        $.offset += @out[*-1].chars + 2;

        return @out.join: "\n";
    }

    multi method write( :$body! ) {
        $.offset = 0;
        $.write( :$body );
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
             [~] $.write( :name($key)), ' ', $.write( $dict{$key} ),
                    }),
         '>>').join: ' ';

    }

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
        my ($obj-num, $gen-num, $object) = @$ind-obj;

        (sprintf('%d %d obj', $obj-num, $gen-num),
         $.write( $object ),
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
        my $header = $.write( $pdf, :node<header> );
        my $comment = $pdf<comment>:exists
            ?? $.write( $pdf, :node<comment> )
            !! $.write( :comment<%¥±ë> );
        $.offset = $header.chars + $comment.chars + 1;  # since format is byte orientated
        my $body = $.write( :body($pdf<body>) );
        [~] ($header, "\n", $comment, "\n", $body, '%%EOF', '');
    }

    multi method write(Any :$header! ) {
        sprintf '%%PDF-%.1f', $header<version> // 1.2;
    }

    multi method write( Numeric :$real! ) {
        ~$real
    }

    multi method write( Hash :$stream! ) {

        my %dict = %( $stream<dict> );
        my $data = $.pdf.stream-data( :$stream ),
        %dict<Length> //= :int($data.chars);

        ($.write( :%dict ),
         "stream",
         $data,
         "endstream",
        ).join: "\n";
    }

    multi method write( Hash :$trailer!, :$xref-offset is copy, :$prev-xref-offset, :$size ) {

        $xref-offset //= $trailer<offset> // 0;

        my %dict = %( $trailer<dict> // {} );

        %dict<Prev> = :int($prev-xref-offset)
            if $prev-xref-offset.defined;

        %dict<Size> = :int($size)
            if $size.defined;

        %dict<Root> //= $.pdf.root-obj
            if $.pdf.root-obj.defined;

        die "unable to locate document root"
            unless %dict<Root>.defined;

        ( "trailer", $.write( :%dict ),
          "startxref", $.write( :int( $xref-offset) ),
          ''
        ).join: "\n";
    }

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

    multi method write( PDF::Core::IndObj $ind-obj ) {
        $.write( $ind-obj.ast );
    }

    multi method write( Pair $ast!) {
        $.write( %$ast );
    }

    multi method write( Hash $ast!, :$node) {
        my %params = $node.defined
            ?? $node => $ast{$node}
        !! $ast.flat;

        $.write( |%params );
    }

    multi method write( *@args, *%opts ) is default {

        die "unexpected arguments: {[@args].perl}"
            if @args;
        
        die "unable to handle {%opts.keys} struct: {%opts.perl}"
    }

}
