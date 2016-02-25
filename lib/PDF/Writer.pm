use v6;

class PDF::Writer {

    use PDF::Grammar;
    use PDF::Storage::Input;

    has PDF::Storage::Input $.input;
    has $.ast is rw;
    has UInt $.offset;
    has UInt $.prev;
    has UInt $.size;
    has Str $.indent is rw = '';

    submethod BUILD(:$input, :$!ast, :$!offset = Nil, :$!prev = Nil) {
        $!input = PDF::Storage::Input.coerce( $input )
            if $input.defined;
    }

    method Str returns Str {
        nextsame unless $.ast.defined;
        temp $!offset;
        temp $!prev;
        $.write( $.ast );
    }

    proto method write(|c) returns Str {*}

    multi method write( Array :$array! ) {
	temp $!indent ~= '  ';  # for indentation of child dictionarys
	('[', $array.map({ $.write($_) }), ']').join: ' ';
    }

    multi method write( Array :$body!, Bool :$write-xref = True ) {
        temp $!prev = Nil;
        $body.map({ $.write( :body($_), :$write-xref )}).join: "\n";
    }

    multi method write( Hash :$body!,  Bool :$write-xref = True ) {
	$!offset //= 0;
	$.write-body( $body, :$write-xref);
    }

    method make-objects( @objects, @out = [], @idx = [] ) {
        for @objects -> $obj {

            if my $ind-obj = $obj<ind-obj> {
                @out.push: $.write( :$ind-obj );

		my UInt $obj-num = $ind-obj[0];
		my UInt $gen-num = $ind-obj[1];

		@idx.push: { :type(1), :$.offset, :$gen-num, :$obj-num, :$ind-obj };
            }
            elsif my $comment = $obj<comment> {
                @out.push: $.write( :$comment );
            }
            else {
                die "don't know how to serialize body component: {$obj.perl}"
            }

            $!offset += @out[*-1].codes + 1;
        }
	@out;
    }

    method make-xref( Hash $trailer, @out, @idx, Bool :$write-xref ) {

	@idx = @idx.sort: { $^a<obj-num> <=> $^b<obj-num> || $^a<gen-num> <=> $^b<gen-num> };

	my Hash @xref;

	for @idx {
	    # [ PDF 1.7 ] 3.4.3 Cross-Reference Table:
	    # "Each cross-reference subsection contains entries for a contiguous range of object numbers"
	    my $contigous = +@xref && .<obj-num> && .<obj-num> == $!size;
	    @xref.push: %( obj-first-num => .<obj-num>, entries => [] )
		unless $contigous;
	    @xref[*-1]<entries>.push: $_;
	    @xref[*-1]<obj-count>++;
	    $!size = .<obj-num> + 1;
	}

	my Str $xref-str = $.write( :@xref );
	my UInt $startxref = $.offset;

	@out.push: [~] (
	    $xref-str,
	    $.write( :$trailer, :$!prev, :$!size ),
	    $.write( :$startxref ),
	    '%%EOF');

	$!offset += $xref-str.codes;
	$!prev = $startxref;
    }

    method write-body( Hash $body!, @idx = [], Bool :$write-xref = True --> Str ) {
        my @out;
	@idx.unshift: { :type(0), :offset(0), :gen-num(65535), :obj-num(0) };

	$.make-objects( $body<objects>, @out, @idx );

	my $trailer = $body<trailer> // {};

	if $write-xref {
	    $.make-xref( $trailer, @out, @idx );
	}
	else {
            # simple trailer, no xref
            @out.push: [~] ( $.write( :$trailer ), '%%EOF' );
	}

        $!offset += @out[*-1].codes + 2;

        @out.join: "\n";
    }

    multi method write( Bool :$bool! ) {
        $bool ?? 'true' !! 'false';
    }

    #| inverter for PDF::Grammar::Content::Actions

    multi method write( Array :$content! ) {
        $content.map({ $.write( :content($_) ) }).join("\n");
    }

    multi method write( :$content! where Pair | Hash) {
        my ($op, $args) = $content.kv;
        $args //= [];
        $.write-op($op, |@$args);
    }

    #| BI <dict> - BeginImage
    multi method write-op('BI', $arg = :dict{}) {
        my Hash $entries = $arg<dict>;
        my @lines;
	"BI\n" ~
	  $.indented({
	      $entries.pairs.sort.map({
		  [~] $.indent, $.write( :name( .key )), ' ', $.write( .value ),
	      }).join: "\n"
	 });
    }

    #| ID <bytes> - ImageData
    multi method write-op('ID', $image-data) {
        "ID\n" ~ $image-data<encoded>;
    }

    multi method write-op(Str $op, *@args) is default {
        (@args.map({ $.write( $_ ) }).Slip, $.write( :$op )).join(' ');
    }

    multi method write( Str :$content! ) {
        $content
    }

    multi method write( Str :$op! where /^\w+/ ) { $op }

    multi method write(List :$comment!) {
        $comment.map({ $.write( :comment($_) ) }).join: "\n";
    }

    multi method write(Str :$comment!) {
        $comment ~~ /^ '%'/ ?? $comment !! '% ' ~ $comment;
    }

    multi method write(Hash :$dict!) {

        # prioritize /Type and /Subtype entries. output /Length as last entry
        my @keys = $dict.keys.sort({
            when 'Type'          {"0"}
            when 'Subtype' | 'S' {"1"}
            when 'Length'        {"z"}
            default              {$_}
        });

        ( '<<',
          $.indented({
	      @keys.map( -> $key {
		  [~] $.indent, $.write( :name($key)), ' ', $.write( $dict{$key} ),
	      }).join: "\n"
	  }),
          $!indent ~ '>>'
        ).join: "\n";

    }

    #| invertors for PDG::Grammar::Function expr term
    #| an array is a sequence of sub-expressions
    multi method write(Array :$expr!) {
	[~] '{ ', $expr.map({ $.write($_) }).join(' '), ' }';
    }

    #| 'ifelse' functional expression
    multi method write(Hash :$expr! where {.<else>:exists}) {
	($.write( $expr<if>) , $.write( $expr<else> ), 'ifelse').join(' ');
    }

    #| 'if' functional expression
    multi method write(Hash :$expr!) {
	[~] $.write( $expr<if>) ,' if'
    }

    multi method write( Str :$hex-char! ) {
        for $hex-char {
            die "multi or zero-byte hex character: {.perl}"
                unless .chars == 1;
            die "illegal non-latin hex character: U+" ~ .ord.base(16)
                unless 0 <= .ord <= 0xFF;
            sprintf '#%02x', .ord
        }
    }

    multi method write( Str :$hex-string! ) {
        [~] flat '<', $hex-string.comb.map({ 
            die "illegal non-latin character in string: U+" ~ .ord.base(16)
                unless 0 <= .ord <= 0xFF;
            sprintf '%02x', .ord;
        }), '>';
    }

    multi method write(:@ind-obj! ) {
        my (UInt $obj-num, UInt $gen-num, $object where Pair | Hash) = @ind-obj;

        [~] (sprintf('%d %d obj ', $obj-num, $gen-num),
	     $.write( $object ),
	     " endobj\n");
    }

    multi method write(Array :$ind-ref!) {
        ($ind-ref[0], $ind-ref[1], 'R').join: ' ';
    }

    multi method write(Int :$int!) {sprintf "%d", $int}

    BEGIN my %escapes = "\b" => '\\b', "\f" => '\\f', "\n" => '\\n', "\r" => '\\r', "\t" => '\\t'
        , "\n" => '\\n', '(' => '\\(', ')' => '\\)', '\\' => '\\\\';

    multi method write( Str :$literal! ) {

        [~] flat '(',
            $literal.comb.map({
                when ' ' .. '~' { %escapes{$_} // $_ }
                when "\o0" .. "\o377" { sprintf "\\%03o", .ord }
                default {die "illegal non-latin character in string: U+" ~ .ord.base(16)}
            }),
           ')';
    }

    BEGIN constant Name-Reg-Chars = set ('!'..'~').grep({/<PDF::Grammar::name-reg-char>/});

    multi method write( Str :$name! ) {
        [~] flat '/', $name.comb.map( {
            when $_ ∈ Name-Reg-Chars { $_ }
            when '#' { '##' }
            default {
                .encode.list.map({ sprintf '#%02x', $_ }).join('');
            }
        } )
    }

    multi method write( Any :$null! ) { 'null' }

    multi method write( Hash :$pdf! ) {
        my Str $header = $.write( $pdf, :node<header> );
        my Str $comment = $pdf<comment>:exists
            ?? $.write( $pdf, :node<comment> )
            !! $.write( :comment<%¥±ë> );
        $!offset = $header.codes + $comment.codes + 2;  # since format is byte orientated
        # Form Definition Format is normally written without an xref
        my Str $type = $pdf<header><type> // 'PDF';
	my Bool $write-xref = $type ne 'FDF';
        my $body = $.write( :body($pdf<body>), :$write-xref );
        [~] ($header, "\n", $comment, "\n", $body);
    }

    multi method write(Any :$header! ) {
        my Str $type = $header<type> // 'PDF';
        sprintf '%%%s-%.1f', $type, $header<version> // 1.2;
    }

    multi method write( Num :$real! ) {
	constant Epsilon = 1e-5;

	my $int = $real.round(1).Int;

	abs($real - $int) < Epsilon
	    ?? ~$int   # assume int, give or take
	    !! sprintf("%.5f", $real);
    }

    multi method write( Numeric :$real! ) {
        ~$real
    }

    multi method write( Hash :$stream! ) {

        my %dict = %( $stream<dict> );
        my $data = $stream<encoded> // $.input.stream-data( :$stream ),
        %dict<Length> //= :int($data.codes);

        [~] $.write( :%dict ), " stream\n", $data, "\nendstream";
    }

    multi method write( Hash :$trailer!, :$prev, :$size ) {

        my %dict = %( $trailer<dict> // {} );

        %dict<Prev> = :int($prev)
            if $prev.defined;

        %dict<Size> = :int($!size)
            if $!size;

        ( "trailer", $.write( :%dict ), '' ).join: "\n";
    }

    multi method write(UInt :$startxref! ) {
        "startxref\n" ~ $.write( :int( $startxref) ) ~ "\n"
    }

    multi method write(Array :$xref!) {
        (flat 'xref',
          $xref.map({ $.write( :xref($_) ) }),
	 '').join: "\n";
    }

    #| write a traditional (PDF 1.4-) cross reference table
    multi method write(Hash :$xref!) {
        (flat
         $xref<obj-first-num> ~ ' ' ~ $xref<obj-count>,
         $xref<entries>.map({
             my Str $status = do given .<type> {
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

    multi method write( Hash $ast!, :$node?) {
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

    #| handle indentation.
    method indented( &code ) {
        temp $!indent ~= '  ';
        &code();
    }
}
