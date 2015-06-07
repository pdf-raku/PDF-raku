use v6;
use Test;

plan 6;

use PDF::Storage::IndObj;
use PDF::Grammar::Test :is-json-equiv;
use PDF::Grammar::PDF;
use PDF::Grammar::PDF::Actions;

my $actions = PDF::Grammar::PDF::Actions.new;

my $input = q:to"--END-OBJ--";
10 0 obj
<< /Length 4344 /Subtype /XML /Type /Metadata >>
stream
<?xpacket begin="﻿" id="W5M0MpCehiHzreSzNTczkc9d"?>
<x:xmpmeta xmlns:x="adobe:ns:meta/" x:xmptk="Adobe XMP Core 4.2.1-c041 52.342996, 2008/05/07-20:48:00        ">
   <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
      <rdf:Description rdf:about=""
            xmlns:pdf="http://ns.adobe.com/pdf/1.3/">
         <pdf:Producer>Acrobat Distiller 7.0.5 (Windows)</pdf:Producer>
      </rdf:Description>
      <rdf:Description rdf:about=""
            xmlns:pdfx="http://ns.adobe.com/pdfx/1.3/">
         <pdfx:SourceModified>D:20081012170642</pdfx:SourceModified>
      </rdf:Description>
      <rdf:Description rdf:about=""
            xmlns:xmp="http://ns.adobe.com/xap/1.0/">
         <xmp:CreatorTool>Acrobat PDFMaker 7.0.7 for Word</xmp:CreatorTool>
         <xmp:ModifyDate>2009-09-11T09:26:05+10:00</xmp:ModifyDate>
         <xmp:CreateDate>2008-10-12T13:06:53-04:00</xmp:CreateDate>
         <xmp:MetadataDate>2009-09-11T09:26:05+10:00</xmp:MetadataDate>
      </rdf:Description>
      <rdf:Description rdf:about=""
            xmlns:xmpMM="http://ns.adobe.com/xap/1.0/mm/">
         <xmpMM:DocumentID>uuid:1b0d594e-a3b7-4223-a3a1-cf52582ab3c5</xmpMM:DocumentID>
         <xmpMM:InstanceID>uuid:3e885f30-aa3d-4532-8902-5b5fd7bbc531</xmpMM:InstanceID>
         <xmpMM:VersionID>
            <rdf:Seq>
               <rdf:li>7</rdf:li>
            </rdf:Seq>
         </xmpMM:VersionID>
      </rdf:Description>
      <rdf:Description rdf:about=""
            xmlns:dc="http://purl.org/dc/elements/1.1/">
         <dc:format>application/pdf</dc:format>
         <dc:title>
            <rdf:Alt>
               <rdf:li xml:lang="x-default"> </rdf:li>
            </rdf:Alt>
         </dc:title>
         <dc:creator>
            <rdf:Seq>
               <rdf:li>Elluminate</rdf:li>
            </rdf:Seq>
         </dc:creator>
         <dc:subject>
            <rdf:Bag>
               <rdf:li/>
            </rdf:Bag>
         </dc:subject>
      </rdf:Description>
      <rdf:Description rdf:about=""
            xmlns:photoshop="http://ns.adobe.com/photoshop/1.0/">
         <photoshop:headline>
            <rdf:Seq>
               <rdf:li/>
            </rdf:Seq>
         </photoshop:headline>
      </rdf:Description>
   </rdf:RDF>
</x:xmpmeta>
                                                                                                    
                                                                                                    
                                                                                                    
                                                                                                    
                                                                                                    
                                                                                                    
                                                                                                    
                                                                                                    
                                                                                                    
                                                                                                    
                                                                                                    
                                                                                                    
                                                                                                    
                                                                                                    
                                                                                                    
                                                                                                    
                                                                                                    
                                                                                                    
                                                                                                    
                                                                                                    
                           
<?xpacket end="w"?>
endstream
endobj
--END-OBJ--

PDF::Grammar::PDF.parse($input, :$actions, :rule<ind-obj>)
    // die "parse failed";
my $ast = $/.ast;
my $ind-obj = PDF::Storage::IndObj.new( |%$ast, :$input);
is $ind-obj.obj-num, 10, '$.obj-num';
is $ind-obj.gen-num, 0, '$.gen-num';
my $metadata-obj = $ind-obj.object;
isa-ok $metadata-obj, ::('PDF::DOM')::('Metadata::XML');
is $metadata-obj.Type, 'Metadata', '$.Type accessor';
is $metadata-obj.Subtype, 'XML', '$.Subtype accessor';
is $metadata-obj.encoded.substr(0,51), '<?xpacket begin="﻿" id="W5M0MpCehiHzreSzNTczkc9d"?>', '$.encoded accessor (sample)';
