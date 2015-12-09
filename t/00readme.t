use Test;
use PDF::Grammar::PDF;

# ensure consistant document ID generation
srand(123456);

my $read-me = "README.md".IO.slurp;

$read-me ~~ /^ $<waffle>=.*? +%% ["```" \n? $<code>=.*? "```" \n?] $/
    or die "README.md parse failed";

for @<code> {
    my $snippet = ~$_;
    given $snippet {
	when /^ '%PDF' / {
	    ok PDF::Grammar::PDF.parse($_), 'is valid PDF document'
		or warn "unable to parse as PDF: $_"
	}
	when /^ \d+ / {
	    ok PDF::Grammar::PDF.parse($_, :rule<ind-obj>), 'is valid PDF indirect object'
		or warn "unable to parse as PDF indirect object: $_"
	}
	when /^ '<<' / {
	    ok PDF::Grammar::PDF.parse($_, :rule<object>), 'is valid PDF object'
		or warn "unable to parse as PDF object: $_"
	}
	when /^ 'trailer' / {
	    ok PDF::Grammar::PDF.subparse($_, :rule<trailer>), 'is valid PDF trailer'
		or warn "unable to parse as PDF trailer: $_"
	}
        when /^ ['>' | 'snoopy'] / { } # REPL
	default {
	    # assume anything else is code.
	    $snippet = $snippet.subst('DateTime.now;', 'DateTime.new( :year(2015), :month(12), :day(25) );' );
	    # disable say
	    sub say(|c) { }

	    lives-ok {EVAL $snippet}, 'code sample'
		or die "eval error: $snippet";
	}
    }
}

done-testing;
