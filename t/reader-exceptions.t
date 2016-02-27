use v6;
use Test;

use PDF::Reader;
use PDF::Storage::Input;

sub make-pdf( :$header='%PDF-1.3', :$length=46, :$xref-digit='0', :$eof='%%EOF', :$endobj = 'endobj') {

    PDF::Storage::Input.coerce: q:s:to"END";
$header
%xxx
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
    my $r = PDF::Reader.new;
    $r.open( make-pdf( |c ), :$repair );
    $r.ind-obj( 6, 0 );
}

lives-ok { test-case( ) }, 'good pdf - lives';
throws-like  { test-case( :header('') ) }, ::('X::PDF::BadHeader'), 'missing header';
throws-like  { test-case( :eof('') ) }, ::('X::PDF::BadTrailer'), 'missing %%EOF';
throws-like  { test-case( :length('99') ) }, ::('X::PDF::BadIndirectObject'), 'stream length too large';
throws-like  { test-case( :length('10') ) }, ::('X::PDF::BadIndirectObject'), 'stream length too small';
throws-like  { test-case( :xref-digit('x') ) }, ::('X::PDF::BadXRef'), 'corrupted xref';
throws-like  { test-case( :endobj('bye!') ) }, ::('X::PDF::BadIndirectObject::Parse'), 'corrupted indirect objects';

lives-ok { test-case( :repair ) }, 'good pdf :repair- lives';
throws-like  { test-case( :repair, :endobj('bye!') ) }, ::('X::PDF::ParseError'), ':repair - corrupted pdf';

throws-like { PDF::Reader.new.open("META6.json") }, ::("X::PDF::BadDump");

done-testing;
 
