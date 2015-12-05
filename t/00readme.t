use Test;
use PDF::Grammar::PDF;

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
	    ok PDF::Grammar::PDF.parse($_, :rule<ind-obj>), 'is valid PDF object'
		or warn "unable to parse as PDF indirect object: $_"
	}
	when /^ '<<' / {
	    ok PDF::Grammar::PDF.parse($_, :rule<object>), 'is valid PDF object'
		or warn "unable to parse as PDF object: $_"
	}
	when /^ 'trailer' / {
	    ok PDF::Grammar::PDF.parse($_, :rule<trailer>), 'is valid PDF object'
		or warn "unable to parse as PDF trailer: $_"
	}
        when /^ ['>' | 'snoopy'] / { } # REPL
	default {
	    # assume anything else is code.
	    lives-ok {EVAL $snippet}, $snippet.substr(0,80) ~ ' ...'
		or die "eval error: $snippet";
	}
    }
}

done-testing;
