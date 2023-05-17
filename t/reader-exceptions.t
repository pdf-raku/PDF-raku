use v6;
use Test;
plan 10;

use PDF::IO::Reader;
use PDF::IO;

sub make-pdf( :$header='%PDF-1.3', :$length=46, :$xref-digit='0', :$eof='%%EOF', :$endobj = 'endobj') {

    PDF::IO.COERCE: q:s:to"END";
$header
%xyz
1 0 obj <<
  /Author (PDF-Tools/t/helloworld.t)
  /CreationDate (D:20151225000000Z00'00')
>> $endobj

2 0 obj <<
  /Type /Catalog
  /Outlines 3 0 R
  /Pages 4 0 R
>> $endobj

3 0 obj <<
  /Type /Outlines
  /Count 0
>> $endobj

4 0 obj <<
  /Type /Pages
  /Count 1
  /Kids [ 5 0 R ]
>> $endobj

5 0 obj <<
  /Type /Page
  /Contents 6 0 R
  /MediaBox [ 0 0 420 595 ]
  /Parent 4 0 R
  /Resources <<
    /Font <<
      /F1 7 0 R
    >>
    /Procset [ /PDF /Text ]
  >>
>> $endobj

6 0 obj <<
  /Length $length
>> stream
BT /F1 24 Tf  100 250 Td (Hello, world!) Tj ET
endstream $endobj

7 0 obj <<
  /Type /Font
  /Subtype /Type1
  /BaseFont /Helvetica
  /Encoding /MacRomanEncoding
>> $endobj

xref
0 8
000000000$xref-digit 65535 f 
0000000014 00000 n 
0000000115 00000 n 
0000000187 00000 n 
0000000238 00000 n 
0000000304 00000 n 
0000000487 00000 n 
0000000586 00000 n 
trailer
<<
  /ID [ <4386dc7bc3489e418b44434e3a168843> <4386dc7bc3489e418b44434e3a168843> ]
  /Info 1 0 R
  /Root 2 0 R
  /Size 8
>>
startxref
693
$eof
END

}

sub test-case(Bool :$repair = False, |c) {
    my PDF::IO::Reader $r .= new;
    $r.open( make-pdf( |c ), :$repair );
    $r.ind-obj( 6, 0 );
}

lives-ok { test-case( ) }, 'good pdf - lives';
throws-like  { test-case( :header('') ) }, X::PDF::BadHeader, :message(rx/^"Expected file header '%XXX-n.m', got: \" \\%xyz 1"/), 'missing header';
throws-like  { test-case( :eof<junk> ) }, X::PDF::BadTrailer, :message("Expected file trailer 'startxref ... %%EOF', got: \"\\%PDF-1.3 \\%xyz 1 0 obj <<   /Auth ...  startxref 693 junk \""), 'missing %%EOF';
throws-like  { test-case( :length('99') ) }, X::PDF::BadIndirectObject, :message("Error processing indirect object 6 0 R at byte offset 487:\nStream dictionary entry /Length 99 overlaps with neighbouring objects (maximum size here is 65 bytes)"), 'stream length too large';
throws-like  { test-case( :length('10') ) }, X::PDF::BadIndirectObject, :message("Error processing indirect object 6 0 R at byte offset 487:\nUnable to locate 'endstream' marker after consuming /Length 10 bytes"), 'stream length too small';
throws-like  { test-case( :xref-digit('x') ) }, X::PDF::BadXRef, :message("Unable to parse index: \"xref 0 8 000000000x 65535 f  000 ... startxref 693 \\%\\%EOF \""), 'corrupted xref';
throws-like  { test-case( :endobj('bye!') ) }, X::PDF::BadIndirectObject::Parse, :message("Error processing indirect object at byte offset 693:\nUnable to parse indirect object: \"00000 65535 f  0000000014 00000  ... startxref 693 \\%\\%EOF \""), 'corrupted indirect objects';

lives-ok { test-case( :repair ) }, 'good pdf :repair- lives';
throws-like  { test-case( :repair, :endobj('bye!') ) }, X::PDF::ParseError, :message("Unable to parse PDF document: \"\\%PDF-1.3 \\%xyz 1 0 obj <<   /Auth ... startxref 693 \\%\\%EOF \""), ':repair - corrupted pdf';

throws-like { PDF::IO::Reader.new.open("META6.json") }, X::PDF::BadJSON;

done-testing;
 
