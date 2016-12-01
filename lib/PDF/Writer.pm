use v6;

class PDF::Writer {

    use PDF::Grammar;
    use PDF::IO::Input;

    has PDF::IO::Input $!input;
    has $.ast is rw;
    has UInt $.offset;
    has UInt $.prev;
    has UInt $.size;
    has Str $.indent is rw = '';

    submethod TWEAK(:$input) {
        $!input = PDF::IO::Input.coerce( $_ )
            with $input;
    }

    method Str returns Str {
        with $.ast {
            temp $!offset;
            temp $!prev;
            $.write( $_ );
        }
        else {
            nextsame;
        }
    }

    method write-array( Array $_ ) {
	temp $!indent ~= '  ';  # for indentation of child dictionarys
	('[', .map({ $.write($_) }), ']').join: ' ';
    }

    multi method write-body( Array $_, |c ) {
        temp $!prev = Nil;
        .map({ $.write-body( $_, |c )}).join: "\n";
    }

    multi method write-body( Hash $body, |c ) {
	$!offset //= 0;
	$.write-body( $body, my @_idx, |c );
    }

    #| write the body and return the index
    multi method write-body( Hash $body!, @idx, Bool :$write-xref = True --> Str ) {
        my @out;
	@idx.unshift: { :type(0), :offset(0), :gen-num(65535), :obj-num(0) };

	self!make-objects( $body<objects>, @out, @idx );

	my \trailer = $body<trailer> // {};

	if $write-xref {
	    self!make-xref( trailer, @out, @idx );
	}
	else {
            # simple trailer, no xref
            @out.push: [~] ( $.write-trailer( trailer ), '%%EOF' );
	}

        $!offset += @out[*-1].codes + 2;

        @out.join: "\n";
    }

    method !make-objects( @objects, @out = [], @idx = [] ) {
        for @objects -> \obj {

            with obj<ind-obj> -> $ind-obj {
                @out.push: $.write-ind-obj( $ind-obj );

		my UInt $obj-num = $ind-obj[0];
		my UInt $gen-num = $ind-obj[1];

		@idx.push: { :type(1), :$.offset, :$gen-num, :$obj-num, :$ind-obj };
            }
            elsif my \comment = obj<comment> {
                @out.push: $.write-comment(comment);
            }
            else {
                die "don't know how to serialize body component: {obj.perl}"
            }

            $!offset += @out[*-1].codes + 1;
        }
	@out;
    }

    method !make-xref( Hash $trailer, @out, @idx, Bool :$write-xref ) {
	@idx = @idx.sort: { $^a<obj-num> <=> $^b<obj-num> || $^a<gen-num> <=> $^b<gen-num> };

	my Hash @xref;

	for @idx {
	    # [ PDF 1.7 ] 3.4.3 Cross-Reference Table:
	    # "Each cross-reference subsection contains entries for a contiguous range of object numbers"
	    my \contiguous = +@xref && .<obj-num> && .<obj-num> == $!size;
	    @xref.push: %( :obj-first-num(.<obj-num>), :entries[] )
		unless contiguous;
	    @xref[*-1]<entries>.push: $_;
	    @xref[*-1]<obj-count>++;
	    $!size = .<obj-num> + 1;
	}

	my Str \xref-str = $.write-xref( @xref );
	my UInt \startxref = $.offset;

	@out.push: [~] (
	    xref-str,
	    $.write-trailer( $trailer, :$!prev, :$!size ),
	    $.write-startxref( startxref ),
	    '%%EOF');

	$!offset += xref-str.codes;
	$!prev = startxref;
    }

    method write-bool( $_ ) {
        .so ?? 'true' !! 'false';
    }

    #| inverter for PDF::Grammar::Content::Actions

    multi method write-content( Array $_ ) {
        .map({ $.write-content($_) }).join("\n");
    }

    multi method write-content( $_ where Pair | Hash) {
        my ($op, $args) = .kv;
        $args //= [];
        $.write-op($op, |@$args);
    }

    multi method write-content( Str $_ ) { $_ }

    #| BI <dict> - BeginImage
    multi method write-op('BI', $arg = :dict{}) {
        my Hash $entries = $arg<dict>;
        my @lines;
	"BI\n" ~
	  self!indented({
	      $entries.pairs.sort.map({
		  [~] $.indent, $.write-name( .key ), ' ', $.write( .value ),
	      }).join: "\n"
	 });
    }
 
   multi method write-op( Str $_ where /^\w+/ ) { .Str }

    #| ID <bytes> - ImageData
    multi method write-op('ID', $image-data) {
        "ID\n" ~ $image-data<encoded>;
    }

    multi method write-op(Str $op, *@args) is default {
        my @vals;
        my Str @comments;
        for @args -> \arg {
            with arg<comment> {
                @comments.push: $_
            }
            else {
                @vals.push: arg;
            }
        }

        my @out = @vals.map: {$.write($_)};
        @out.push: $.write-op( $op );
        @out.push: $.write-comment( @comments.join(' ') )
            if @comments;

        @out.join: ' ';
    }

    multi method write-comment(List $_) {
        .map({ $.write-comment($_) }).join: "\n";
    }

    multi method write-comment(Str $_) {
        m:s{^ '%'} ?? $_ !! '% ' ~ $_
    }

    method write-dict(Hash $_) {

        # prioritize /Type and /Subtype entries. output /Length as last entry
        my @keys = .keys.sort({
            when 'Type'          {"0"}
            when 'Subtype' | 'S' {"1"}
            when 'Length'        {"z"}
            default              {$_}
        });

        ( '<<',
          self!indented({
	      @keys.map( -> \key {
		  [~] $.indent, $.write-name(key), ' ', $.write( .{key} ),
	      }).join: "\n"
	  }),
          $!indent ~ '>>'
        ).join: "\n";

    }

    #| invertors for PDF::Grammar::Function expr term
    #| an array is a sequence of sub-expressions
    multi method write-expr(Array $_) {
	[~] '{ ', .map({ $.write($_) }).join(' '), ' }';
    }

    #| 'if' and 'ifelse' functional expressions
    multi method write-expr(Hash $_) {
        my @expr = $.write( .<if> );
        @expr.append: do with .<else> {
	    ($.write( $_ ), 'ifelse');
        }
        else {
	    ('if')
        }
        @expr.join: ' ';
    }

    method write-hex-char( Str $_ ) {
        die "multi or zero-byte hex character: {.perl}"
           unless .chars == 1;
        die "illegal non-latin hex character: U+" ~ .ord.base(16)
            unless 0 <= .ord <= 0xFF;
        sprintf '#%02x', .ord
    }

    method write-hex-string( Str $_ ) {
        [~] flat '<', .encode("latin-1").map({ 
            sprintf '%02x', $_;
        }), '>';
    }

    method write-ind-obj(@_) {
        my (UInt \obj-num, UInt \gen-num, \object where Pair | Hash) = @_;

        sprintf "%d %d obj %s\nendobj\n", obj-num, gen-num, $.write( object );
    }

    method write-ind-ref(Array $_) {
        [ .[0], .[1], 'R' ].join: ' ';
    }

    method write-int(Int $_) {sprintf "%d", $_}

    constant %Escapes = %(
        "\b" => '\\b', "\f" => '\\f', "\n" => '\\n', "\r" => '\\r',
        "\t" => '\\t', '(' => '\\(', ')' => '\\)', '\\' => '\\\\' );

    method write-literal( Str $_ ) {

        [~] flat '(',
        .encode("latin-1").map({
                my \c = .chr;
                %Escapes{c} // (32 <= $_ <= 126 ?? c !! sprintf "\\%03o", $_);
            }),
           ')';
    }

    constant Name-Reg-Chars = set ('!'..'~').grep({ $_ !~~ /<PDF::Grammar::char_delimiter>/});

    method write-name( Str $_ ) {
        [~] flat '/', .comb.map( {
            when $_ ∈ Name-Reg-Chars { $_ }
            when '#' { '##' }
            default {
                .encode.list.map({ sprintf '#%02x', $_ }).join('');
            }
        } )
    }

    method write-null( $ ) { 'null' }

    method write-pdf( Hash $pdf ) {
        my Str \header = $.write( $pdf, :node<header> );
        my Str \comment = $pdf<comment>:exists
            ?? $.write( $pdf, :node<comment> )
            !! $.write-comment( q<%¥±ë> );
        $!offset = header.codes + comment.codes + 2;  # since format is byte orientated
        # Form Definition Format is normally written without an xref
        my Str \type = $pdf<header><type> // 'PDF';
	my Bool $write-xref = type ne 'FDF';
        my \body = $.write-body( $pdf<body>, :$write-xref );
        (header, comment, body).join: "\n";
    }

    method write-header($_ ) {
        my Str \type = .<type> // 'PDF';
        sprintf '%%%s-%.1f', type, .<version> // 1.2;
    }

    multi method write-real( Num $_ ) {
	my \int = .round(1).Int;
	$_ =~= int
	    ?? ~int
	    !! sprintf("%.5f", $_);
    }

    multi method write-real( Numeric $_ ) {
        ~$_
    }

    method write-stream( Hash $stream ) {
        my %dict = $stream<dict>;
        my $data = $stream<encoded> // $.input.stream-data( :$stream );
        $data = $data.decode("latin-1")
            unless $data.isa(Str);
        %dict<Length> //= :int($data.codes);
        [~] $.write-dict(%dict), " stream\n", $data, "\nendstream";
    }

    method write-trailer( Hash $trailer, :$prev, :$size ) {
        my %dict = $trailer<dict> // {};

        %dict<Prev> = :int($_)
            with $prev;

        %dict<Size> = :int($_)
            with $!size;

        [~] "trailer\n", $.write-dict(%dict), "\n";
    }

    method write-startxref(UInt $_ ) {
        "startxref\n" ~ $.write-int($_) ~ "\n"
    }

    multi method write-xref(Array $_) {
        (flat 'xref',
          .map({ $.write-xref($_) }),
	 '').join: "\n";
    }

    #| write a traditional (PDF 1.4-) cross reference table
    multi method write-xref(Hash $xref!) {
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

    proto method write(|c) returns Str {*}

    multi method write( Pair $_!) {
        self."write-{.key}"( .value );
    }

    multi method write( Hash $ast!, :$node) {
        my %params = $node.defined
            ?? ($node => $ast{$node})
            !! $ast;

        $.write( |%params );
    }

    multi method write( *@args, *%opt ) is default {
        die "unexpected arguments: {[@args].perl}"
            if @args;

        my $key = %opt.keys.sort.first({  $.can("write-$_") })
            or die "unable to handle {%opt.keys} struct: {%opt.perl}";
        my $val = %opt{$key}:delete;
        self."write-$key"($val, |%opt);
    }

    #| handle indentation.
    method !indented( &code ) {
        temp $!indent ~= '  ';
        &code();
    }
}
