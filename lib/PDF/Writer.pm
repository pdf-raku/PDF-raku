use v6;

class PDF::Writer {

    use PDF::Grammar;
    use PDF::Storage::Input;

    has PDF::Storage::Input $.input;
    has $.ast is rw;
    has $.root;
    has $.offset = 0;
    has $!prev;
    has %!init;

    submethod BUILD(:$input, :$!ast, :$root, :$!offset, :$!prev ) {

        $!root = $root.can('ind-ref')
            ?? $root.ind-ref
            !! $root
            if $root.defined;

        $!input = PDF::Storage::Input.compose( :value($input) )
            if $input.defined;
    }

    method Str {
        nextsame unless $.ast.defined;
        temp $!offset;
        temp $!prev;
        $.write( $.ast );
    }

    multi method write( Array :$array! ) {
        ('[', $array.map({ $.write($_) }), ']').join: ' ';
    }

    multi method write( Array :$body!, :$type='PDF' ) {
        $body.map({ $.write( :body($_), :$type )}).join: "\n";
    }

    multi method write( Hash :$body!, :$type = 'PDF' ) {
        my @entries = %( :type(0), :offset(0), :gen-num(65535), :obj-num(0) ).item;
        my @out;

        for $body<objects>.list -> $obj {

            if my $ind-obj = $obj<ind-obj> {
                my $obj-num = $ind-obj[0].Int;
                my $gen-num = $ind-obj[1].Int;

                @entries.push: %( :type(1), :$.offset, :$gen-num, :$obj-num ).item;
                @out.push: $.write( :$ind-obj );

            }
            elsif my $comment = $obj<comment> {
                @out.push: $.write( :$comment );
            }
            else {
                die "don't know how to serialize body component: {$obj.perl}"
            }

            $!offset += @out[*-1].chars + 1;
        }

        my $trailer = $body<trailer>
            // {};

        if $type eq 'FDF' {
            # don't write an index
            @out.push: [~] (
                $.write( :$trailer ),
                '%%EOF');
        }
        else {

            @entries = @entries.sort: { $^a<obj-num> <=> $^b<obj-num> || $^a<gen-num> <=> $^b<gen-num> };

            my @xref;
            my $size = 1;

            for @entries {
                # [ PDF 1.7 ] 3.4.3 Cross-Reference Table:
                # "Each cross-reference subsection contains entries for a contiguous range of object numbers"
                my $contigous = +@xref && .<obj-num> && .<obj-num> == $size;
                @xref.push: %( object-first-num => .<obj-num>, entries => [] ).item
                    unless $contigous;
                @xref[*-1]<entries>.push: $_;
                @xref[*-1]<object-count>++;
                $size = .<obj-num> + 1;
            }

            my $xref-str = $.write( :@xref );
            my $startxref = $.offset;

            @out.push: [~] (
                $xref-str,
                $.write( :$trailer, :$!prev, :$size ),
                $.write( :$startxref ),
                '%%EOF');

            $!offset += $xref-str.chars;
            $!prev = $startxref;
        }

        $!offset += @out[*-1].chars + 2;

        return @out.join: "\n";
    }

    multi method write( :$body! ) {
        $!offset = 0;
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
        my $ord = $hex-char.ord;
        die "illegal hex character: {$hex-char.perl}"
            unless $hex-char.chars == 1 && $ord >= 0 && $ord <= 255;
        sprintf '#%02X', $ord
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

    multi method write( Hash :$pdf! ) {
        my $header = $.write( $pdf, :node<header> );
        my $comment = $pdf<comment>:exists
            ?? $.write( $pdf, :node<comment> )
            !! $.write( :comment<%¥±ë> );
        $!offset = $header.chars + $comment.chars + 2;  # since format is byte orientated
        # Form Definition Format is normally written without an xref
        my $type = $pdf<header><type>;
        my $body = $.write( :body($pdf<body>), :$type );
        [~] ($header, "\n", $comment, "\n", $body);
    }

    multi method write(Any :$header! ) {
        my $type = $header<type> // 'PDF';
        sprintf '%%%s-%.1f', $type, $header<version> // 1.2;
    }

    multi method write( Numeric :$real! ) {
        ~$real
    }

    multi method write( Hash :$stream! ) {

        my %dict = %( $stream<dict> );
        my $data = $stream<encoded> // $.input.stream-data( :$stream ),
        %dict<Length> //= :int($data.chars);

        ($.write( :%dict ),
         "stream",
         $data,
         "endstream",
        ).join: "\n";
    }

    multi method write( Hash :$trailer!, :$prev, :$size ) {

        my %dict = %( $trailer<dict> // {} );

        %dict<Prev> = :int($prev)
            if $prev.defined;

        %dict<Size> = :int($size)
            if $size.defined;

        %dict<Root> //= $.root
            if $.root.defined;

        die "unable to locate document root"
            unless %dict<Root>.defined;

        ( "trailer", $.write( :%dict ), '' ).join: "\n";
    }

    multi method write(Int :$startxref! ) {
        "startxref\n" ~ $.write( :int( $startxref) ) ~ "\n"
    }

    multi method write(Array :$xref!) {
        ( 'xref',
          $xref.map({ $.write( :xref($_) ) }),
          '').join: "\n";
    }

    #| write a traditional (PDF 1.4-) cross reference table
    multi method write(Hash :$xref!) {
        (
         $xref<object-first-num> ~ ' ' ~ $xref<object-count>,
         $xref<entries>.map({
             my $status = do given .<type> {
                 when (0) {'f'} # free
                 when (1) {'n'} # inuse
                 when (2) { die "unable to write type-2 (embedded) objects in a PDF 1.4 cross reference table"}
                 default  { die "unhandled index type: $_" }
             };
             die "generation number {.<gen_num>} exceeds 5 digits in PDF 1.4 cross reference table"
                 if .<gen-num> > 99_999;
             die "offset {.<offset>} exceeds 10 digits in PDF 1.4 cross reference table"
                 if .<offset> > 9_999_999_999;
             sprintf '%010d %05d %s ', .<offset>, .<gen-num>, $status
         }),
        ).join: "\n";
    }

    multi method write( Pair $ast!) {
        $.write( %$ast );
    }

    multi method write( Hash $ast!, :$node) {
        my %params = $node.defined
            ?? ($node => $ast{$node})
            !! $ast.flat;

        $.write( |%params );
    }

    multi method write( *@args, *%opt ) is default {
        return 'null' if %opt<null>:exists;

        die "unexpected arguments: {[@args].perl}"
            if @args;
        
        die "unable to handle {%opt.keys} struct: {%opt.perl}"
    }

}
