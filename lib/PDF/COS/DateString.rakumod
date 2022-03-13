use v6;

use PDF::COS;

class PDF::COS::DateString
    does PDF::COS
    is DateTime {

    use PDF::COS::Util :date-time-formatter;
    BEGIN our &formatter = &date-time-formatter;

    our constant DateRegex = rx/^
                'D:'?
                $<year>=\d**4
                [$<dd>=\d**2]**0..5
                [$<tz-sign>=< + - Z >
	          [$<tz-hour>=\d**2
                    [\' $<tz-min>=\d**2]? \'?
                  ]?
                ]?
            $/;

    multi method new(Str $pdf-date! is copy) {
        constant BOM-BE = "\xFE\xFF";
        $pdf-date = Buf.new($pdf-date.ords).decode('utf-16')
            if $pdf-date.starts-with(BOM-BE);
	$pdf-date ~~ DateRegex
	    or die "Date /$pdf-date/ not in format: D:YYYYMMDDHHmmSS[+-Z]HH'mm'";

        my UInt \year  = +$<year>;
        my UInt \month = +( @<dd>[0] // 1 );
        my UInt \day   = +( @<dd>[1] // 1 );
        my UInt \hour  = +( @<dd>[2] // 0 );
        my UInt \min   = +( @<dd>[3] // 0 );
        my UInt \sec   = +( @<dd>[4] // 0 );
        my Str  \tz = $<tz-sign> && $<tz-sign> ne 'Z'
            ?? sprintf '%s%02d%02d', $<tz-sign>, $<tz-hour>, $<tz-min>
	    !! '';

        my Str \iso-date = sprintf "%04d-%02d-%02dT%02d:%02d:%02d%s", year, month, day, hour, min, sec, tz;

	nextwith( iso-date, :&formatter );
    }

    method content {
	my Str $literal = formatter( self );
	:$literal;
    }

    multi method COERCE(PDF::COS::DateString $_) { $_ }
    multi method COERCE(Str:D $obj, |c) {
        self.new($obj, |c);
    }

    multi method COERCE(DateTime:D $dt, |c) {
        my %args = <year month day hour minute second timezone>.map: {$_ => $dt."$_"() };
        self.new: |%args, :&formatter;
    }

=begin pod

see [PDF 32000 Section 7.9.4 Dates ]

PDF defines a standard date format, which closely follows that of the international standard ASN.1 (Abstract Syntax Notation One), defined in ISO/IEC 8824. A date is an ASCII string of the form:
 C<(D:YYYYMMDDHHmmSSOHH'mm')>
 where:

=item  YYYY is the year
=item  MM is the month
=item  DD is the day (01–31)
=item  HH is the hour (00–23)
=item  mm is the minute (00–59)
=item  SS is the second (00–59)
=item  O is the relationship of local time to Universal Time (UT), denoted by one of the characters +, −, or Z (see below)
=item  HH followed by ' is the absolute value of the offset from UT in hours (00–23)
=item  mm followed by ' is the absolute value of the offset from UT in minutes (00–59)
=para
The apostrophe character (') after HH and mm is part of the syntax. All fields after the year are optional. (The prefix D : , although also optional, is strongly recommended.) The default values for MM and DD are both 01; all other
# numerical fields default to zero values. A plus sign (+) as the value of the O field signifies that local time is later than UT, a minus sign (−) signifies that local time is earlier than UT, and the letter Z signifies that local time is equal to UT. If no UT information is specified, the relationship of the specified time to UT is considered to be unknown. Regardless of whether the time zone is known, the rest of the date should be specified in local time.

=end pod

}
