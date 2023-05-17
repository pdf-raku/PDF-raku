use v6;

class PDF::IO::Writer {

    use PDF::Grammar:ver(v0.2.1+);
    use PDF::COS;
    use PDF::IO;
    use PDF::COS::Type::XRef;
    use PDF::IO::IndObj;
    has PDF::IO $!input;
    has $.ast is rw;
    has UInt $.offset;
    has UInt $.prev;
    has UInt $.size;
    has Str  $.indent is rw = '';
    has Rat $.compat is rw = 1.4;

    my Lock $lock .= new;

    #| optional role to apply when LibXML::Native is available
    role Native[$writer] {
        # load some native faster alternatives

        method write-bool($_)       { $writer.write-bool($_) }
        method write-hex-string($_) { $writer.write-hex-string($_) }
        method write-literal($_)    { $writer.write-literal($_) }
        method write-name($_)       { $writer.write-name($_) }
        method write-int($_)        { $writer.write-int($_) }
        method write-real($_)       { $writer.write-real($_) }
        method write-entries($_)    { $writer.write-entries($_) }
    }

    submethod TWEAK(:$input) {
        $!input .= COERCE: $_
           with $input;

        $lock.protect: {
            # No thread-safe on older Rakudos
            given try {require ::('PDF::Native::Writer')} -> $writer {
                unless $writer === Nil {
                    self does Native[$writer];
                }
            }
        }
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

    method Blob returns Blob {
	self.Str.encode: "latin-1";
    }

    method write-array(List $_ ) {
	temp $!indent ~= '  ';  # for indentation of child dictionaries
	('[', .map({ $.write($_) }).Slip, ']').join: ' ';
    }

    multi method write-body(List $_, |c ) {
        temp $!prev = Nil;
        .map({ $.write-body( $_, |c )}).join: "\n";
    }

    multi method write-body( Hash $body, |c ) {
	$!offset //= 0;
	$.write-body( $body, |c );
    }

    #| write the body and return the index
    multi method write-body( Hash $body!, @idx = [], Bool :$write-xref = True --> Str ) {
	@idx.unshift: { :type(0), :offset(0), :gen-num(65535), :obj-num(0) };
	my @out = self!make-objects( $body<objects>, @idx );

	my \trailer-dict = $body<trailer> // {};
	my \trailer-bytes = $write-xref
            ?? self!make-trailer( trailer-dict, @idx )
            !! [~] ( $.write-trailer( trailer-dict ), '%%EOF' );

        @out.push: trailer-bytes;
        $!offset += trailer-bytes.codes  +  2 * "\n".codes;

        @out.join: "\n";
    }

    method !make-object($obj, @idx) {
        do with $obj<ind-obj> -> $ind-obj {
            # serialization of in-memory object
            my uint $obj-num = $ind-obj[0];
            my uint $gen-num = $ind-obj[1];
            @idx.push: %( :type(1), :$!offset, :$gen-num, :$obj-num, :$ind-obj );

            $.write-ind-obj( $ind-obj );
        }
        elsif $obj<copy> -> \ref {
            # direct copy of raw object from input to output
            my uint $obj-num = ref[0];
            my uint $gen-num = ref[1];
            my $getter = ref[2];
            my $ind-obj = $getter.get($obj-num, $gen-num);
            @idx.push: %( :type(1), :$!offset, :$gen-num, :$obj-num, :$ind-obj );
            $.write-ind-obj( $ind-obj );
        }
        elsif $obj<comment> -> \comment {
            $.write-comment(comment);
        }
        else {
            die "don't know how to serialize body component: {$obj.raku}"
        }
    }

    method !make-objects( @objects, @idx = [] ) {
        @objects.map: -> $obj is rw {
            my \bytes = self!make-object($obj, @idx);
            $!offset += bytes.codes + 1;
            bytes;
        }
    }

    method !make-trailer($dict, @idx) {
        $!compat >= 1.5
            ?? self!make-trailer-stream($dict, @idx)
            !! self!make-trailer-xref($dict, @idx);
    }

    #| build a PDF 1.5+ Cross Reference Stream
    method !make-trailer-stream( Hash $trailer, @idx is copy) {
	my UInt \startxref = $.offset;
        my %dict = %$trailer<dict>;
        my PDF::COS::Type::XRef $xref .= new: :%dict;
        $xref.Filter = 'FlateDecode';
        my $n := +@idx;
        my uint64 @xref-index[$n;4];
        @idx .= sort: { .<obj-num> };
        with @idx.tail<obj-num> {
            $!size = $_ + 1
                if !$!size || $!size <= $_;
        }

        for ^$n -> $i {
            my $idx := @idx[$i];
            my UInt $type := $idx<type>;
            my $obj-num := $idx<obj-num>;
            @xref-index[$i;0] = $obj-num;
            @xref-index[$i;1] = $type;
            @xref-index[$i;2] = do given $type {
                when 0 { $!size }
                when 1 { $idx<offset> }
                when 2 { $idx<ref-obj-num> }
            }
            @xref-index[$i;3] = do given $type {
                when 0 { $idx<gen-num> + 1 }
                when 1 { $idx<gen-num> }
                when 2 { $idx<index> }
            }
        }

        $xref.encoded = $xref.encode-index: @xref-index;
        my $xref-obj = PDF::IO::IndObj.new: :object($xref), :obj-num($!size), :gen-num(0);

        my \xref-str = self.write($xref-obj.ast);

	my \trailer = [~] (
	    xref-str,
	    $.write-startxref( startxref ),
	    '%%EOF',
        );

	$!offset += xref-str.codes;
	$!prev = startxref;

        trailer;
    }

    #| Build a PDF 1.4- Cross Reference Table
    method !make-trailer-xref( Hash $trailer, @idx ) {
        my $total-entries = +@idx;
	my uint64 @idx-sorted[$total-entries;4] = @idx
            .map({[.<type>, .<obj-num>, .<gen-num>, .<offset> ]})
            .sort({ $^a[1] <=> $^b[1] || $^a[2] <=> $^b[2] });

	my Str \xref-str = self!write-xref-segments: self!xref-segments( @idx-sorted );
	my UInt \startxref = $.offset;

	my \trailer = [~] (
	    xref-str,
	    $.write-trailer( $trailer, :$!prev, :$!size ),
	    $.write-startxref( startxref ),
	    '%%EOF',
        );

	$!offset += xref-str.codes;
	$!prev = startxref;

        trailer;
    }

    method write-bool( $_ ) {
        .so ?? 'true' !! 'false';
    }

    #| inverter for PDF::Grammar::Content::Actions

    multi method write-content(List $_ ) {
        .map({ $.write-content($_) }).join("\n");
    }

    multi method write-content($_ where Pair | Hash) {
        ##        my :($op, $args) := .kv; # needs Rakudo > 2020.12
        my ($op, $args) := .kv;
        $args //= [];
        $.write-op($op, |@$args);
    }

    multi method write-content( Str $_ ) { $_ }

    #| BI <dict> - BeginImage
    multi method write-op('BI', $arg = :dict{}) {
        my Hash $entries = $arg<dict>;
	join( "\n",
              "BI",
              self!indented($entries.pairs.sort,
                            -> $_ { [~] $.write-name( .key ), ' ', $.write( .value ) }
                           ),
            );
    }

   multi method write-op('comment', $_) { $.write-comment($_); }

    #| ID <bytes> - ImageData
    multi method write-op('ID', $image-data) {
        "ID\n" ~ $image-data<encoded>;
    }

    multi method write-op(Str:D $op, *@args) {
        my @vals;
        my @comments;
        for @args -> \arg {
            with arg<comment> {
                @comments.push: $_;
            }
            else {
                @vals.push: arg;
            }
        }

        my @out = @vals.map: {$.write($_)};
        @out.push: $op;
        if @comments -> $_ {
            @out.push: $.write-comment( .join(' ') )
        }

        @out.join: ' ';
    }

    multi method write-comment(List $_) {
        .map({ $.write-comment($_) }).join: "\n";
    }

    multi method write-comment(Str $_) {
        # sanitize non-latin characters
        given .subst(/<- [ \x0..\xFF ]>/, *.ord.fmt('#%x') , :g) {
            .starts-with('%') ?? $_ !! '% ' ~ $_
        }
    }

    method write-dict(Hash $dict) {

        # prioritize /Type and /Subtype entries. output /Length as last entry
        my @keys = $dict.keys.sort: {
            when 'Type'              {"0"}
            when 'Subtype'|'S'       {"1"}
            when .ends-with('Type')  {"1" ~ $_}
            when 'Length'            {"z"}
            default                  {$_}
        };
        my $pad = $!indent;
        temp $!indent ~= '  ';  # for indentation of child dictionaries
        my @entries = @keys.map: { $.write-name($_) ~ ' ' ~ $.write: $dict{$_} };
        my $len = $!indent;
        my Bool $multi-line;
        for @entries {
            $len += .chars;
            if $len > 64 {
                $multi-line = True;
                last;
            }
        }

        $multi-line
            ?? join("\n", '<<', @entries.map({$!indent ~ $_}), $pad ~ '>>')
            !! join(' ', '<<', @entries, '>>');
    }

    multi method write-expr(List $_) {
	[~] '{ ', .map({ $.write($_) }).join(' '), ' }';
    }

    #| 'if' and 'ifelse' functional expressions
    multi method write-expr(% (:$if!, :$else) ) {
        my @expr = $.write( $if );
        @expr.append: do with $else {
	    ($.write( $_ ), 'ifelse');
        }
        else {
	    ('if')
        }
        @expr.join: ' ';
    }


    method write-hex-string( Str $_ ) {
        [~] ('<',
             slip(.encode("latin-1").map(*.fmt('%02x'))),
             '>');
    }

    method write-ind-obj(@_) {
        my (UInt \obj-num, UInt \gen-num, \object) = @_;

        "%d %d obj\n%s\nendobj\n".sprintf(obj-num, gen-num, $.write( object ));
    }

    method write-ind-ref(List $_) {
        join(' ', .[0], .[1], 'R');
    }

    method write-int(Int $_) {.fmt: '%d'}

    method write-literal( Str $_ ) {
        '('
        ~ .trans(["\b",  "\f",  "\n",  "\r",  "\r\n",   "\t",  '(',   ')',  '\\']
              => ['\\b', '\\f', '\\n', '\\r', '\\r\\n', '\\t', '\\(', '\\)', '\\\\'])
        ~ ')';
    }

    my token name-esc-seq {
        <-[\! .. \~] +[( ) < > \[ \] { } / %]>+
    }
    method write-name( Str $_ ) {
        '/' ~
        .subst('#', '##', :g)
        .subst(/<name-esc-seq>/, {.Str.encode.map(*.fmt('#%02x')).join: ''}, :g);
    }

    method write-null( $ ) { 'null' }

    method write-cos(% (:$header!, :$body!, :$comment = q<%¥±ë¼>) ) {
        my Str \header = $.write-header( $header );
        my Str \comment = $.write-comment($comment);
        $!offset = header.codes + comment.codes + 2;  # since format is byte orientated
        # Form Definition Format is normally written without an xref
        my Str \type = $header<type> // 'PDF';
	my Bool $write-xref = type ne 'FDF';
        my \body = $.write-body( $body, :$write-xref );
        (header, comment, body).join: "\n";
    }

    sub print-bytes(IO::Handle:D $fh, Str $chunk) {
        CATCH {
            default {
                note "error printing {$chunk.raku}";
                .rethrow();
            }
        }
        my $buf = $chunk.encode('latin-1');
        $fh.write: $buf;
        $buf.bytes;
    }

    sub say-bytes(IO::Handle:D $fh, Str $chunk) {
        print-bytes($fh, $chunk) + print-bytes($fh, "\n");
    }

    multi method stream-cos(IO::Handle:D $fh, % (:$header!, :$body!, :$comment = q<%¥±ë¼>) ) {
        my Str \type = $header<type> // 'PDF';
        # Form Definition Format is normally written without an xref
	my Bool $write-xref = type ne 'FDF';
        temp $!offset;
        temp $!prev;

        $fh.&say-bytes: $.write-header($header);
        $fh.&say-bytes: $.write-comment($comment);

        self.stream-body: $fh, $body, my @idx, :$write-xref;
    }

    multi method stream-cos(IO::Handle:D $fh) {
        $.stream-cos($fh, $!ast<cos>);
    }

    multi method stream-body(IO::Handle:D $fh, @body, |c) {
        self.stream-body: $fh, $_, |c for @body;
    }

    multi method stream-body(IO::Handle:D $fh, %body, @idx, Bool :$write-xref = True, :$!offset = $fh.tell) {
        @idx.unshift: { :type(0), :offset(0), :gen-num(65535), :obj-num(0) };

        for %body<objects>.list {
            $!offset += $fh.&say-bytes: self!make-object($_, @idx);
        }
        my \trailer-dict = %body<trailer> // {};
        if $write-xref {
            $fh.&print-bytes: self!make-trailer(trailer-dict, @idx);
        }
        else {
            $fh.&print-bytes: $.write-trailer(trailer-dict);
            $fh.&print-bytes: '%%EOF';
        }
    }

    method write-header($_ ) {
        my Str \type = .<type> // 'PDF';
        '%%%s-%.1f'.sprintf(type, .<version> // 1.2);
    }

    multi method write-real( Int $_ ) {
        .fmt: '%d';
    }

    multi method write-real( Numeric $_ ) {
        my Str $num = .fmt('%.5f');
        $num ~~ s/(\.\d*?)0+$/$0/;
        $num.ends-with('.') ?? $num.chop !! $num;
    }

    method write-stream(% (:%dict!, :$encoded = $.input.stream-data( :stream($_) )) ) {
        my $data = $encoded;
        $data .= decode("latin-1")
            unless $data.isa(Str);
        %dict<Length> //= :int($data.codes);
        [~] $.write-dict(%dict), " stream\n", $data, "\nendstream";
    }

    method write-trailer(% (:%dict!), :$prev) {

        %dict<Prev> = :int($_)
            with $prev;

        %dict<Size> = :int($_)
            with $!size;

        [~] "trailer\n", $.write-dict(%dict), "\n";
    }

    method write-startxref(UInt $_ ) {
        "startxref\n" ~ $.write-int($_) ~ "\n"
    }

    method !xref-segment-length($xref where .shape[1] ~~ 4, $i, $n) {
        my $next-obj-num = $xref[$i;1];
        loop (my $j = $i; $j < $n && $next-obj-num == $xref[$j;1]; $j++) {
            $next-obj-num++;
        }
        $j - $i;
    }

    method !xref-segments(@idx) {
        my $total-entries := +@idx;
        given @idx[$total-entries-1;1] + 1 {
            $!size = $_
                if !$!size || $_ > $!size;
        }
        my Hash @xrefs;
        loop (my uint $i = 0; $i < $total-entries;) {
            my uint $obj-count = self!xref-segment-length(@idx, $i, $total-entries);
            my uint32 $obj-first-num = @idx[$i;1];

	    # [ PDF 32000 7.5.4 Cross-Reference Table:
	    # "Each cross-reference subsection contains entries for a contiguous range of object numbers"]
            my uint64 @entries[$obj-count;3];
            for ^$obj-count {
                my uint8  $type    = @idx[$i;0];
                my uint32 $gen-num = @idx[$i;2];
                my uint64 $offset  = @idx[$i;3];
                @entries[$_;0] = $offset;
                @entries[$_;1] = $gen-num;
                @entries[$_;2] = $type;
                $i++;
            }
	    @xrefs.push: %( :$obj-first-num, :$obj-count, :@entries );
        }
        @xrefs;
    }

    method !write-xref-segments(List $_) {
        "xref\n" ~ .map({ self!write-xref-section(|$_) }).join;
    }

    #| write a traditional (PDF 1.4-) cross reference table
    method !write-xref-section(:$obj-first-num!, :$obj-count!, :$entries!) {
        die "xref $obj-count != {$entries.elems}"
            unless $obj-count == +$entries;
         $obj-first-num ~ ' ' ~ $obj-count ~ "\n"
             ~ self!write-entries($entries);
    }

    method !write-entries($_ where .shape[1] ~~ 3) {
        my Str enum ObjectType ( :Free<f>, :Inuse<n> );
        ((^.elems).map: -> int $i {
            my uint64 $offset  = .[$i;0];
            my uint32 $gen-num = .[$i;1];
            my uint32 $type    = .[$i;2];
            my Str $status = do given $type {
                when (0) {Free}
                when (1) {Inuse}
                when (2) { die "unable to write type-2 (embedded) objects in a PDF 1.4 cross reference table"}
                default  { die "unhandled index type: $_" }
            };
            die "generation number $gen-num exceeds 5 digits in PDF 1.4 cross reference table"
                if $gen-num > 99_999;
            die "offset $offset exceeds 10 digits in PDF 1.4 cross reference table"
                if $offset > 9_999_999_999;
            "%010d %05d %s \n".sprintf($offset, $gen-num, $status)
        }).join;
    }

    proto method write(|c) returns Str {*}

    multi method write(Bool:D $_)    { $.write-bool($_); }
    multi method write(Int:D $_)     { $.write-int($_); }
    multi method write(Numeric:D $_) { $.write-real($_); }
    multi method write(Any:U $_)     { $.write-null($_); }

    multi method write(Pair $_) {
        .value.defined
            ?? self."write-{.key}"( .value )
            !! self.write-null(Any);
    }

    multi method write(%ast where .elems == 1) {
        $.write: %ast.pairs[0];
    }
    multi method write(%ast is copy) is DEPRECATED {
        my $key = %ast.keys.sort.first({ $.can("write-$_") })
            or die "unable to handle {%ast.keys} struct: {%ast.raku}";
        my $val = %ast{$key}:delete;
        self."write-$key"($val, |%ast);
    }

    multi method write(*%ast where .so) is DEPRECATED {
        $.write: %ast;
    }
    multi method write($_, *@) {
        die "unable to write: {.raku}";
    }
    multi method write {
        with $!ast {
            self.write: $_;
        }
        else {
            die "nothing to write";
        }
    }

    #| handle indentation.
    method !indented(@lines, &sub) {
        temp $!indent ~= '  ';
        @lines ?? @lines.map({ $!indent ~ &sub($_) }).join("\n") !! ();
    }
}
