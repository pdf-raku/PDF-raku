use v6;

use PDF::Object::Dict;
use PDF::Object::Type;
use PDF::Object::Inheritance;

# /Type /Page - describes a single PDF page

class PDF::Object::Type::Page
    is PDF::Object::Dict
    does PDF::Object::Type
    does PDF::Object::Inheritance {

    method Parent is rw { self<Parent> }
    method Resources is rw { self<Resources> }
    method MediaBox is rw { self<MediaBox> }
    method Contents is rw { self<Contents> }

    #| produce an XObject form for this page
    method to-xobject() {
        require ::('PDF::Object::Type::XObject::Form');
        my $contents = self.Contents;
        my %params = $contents.get-stream();
        my $xobject = ::('PDF::Object::Type::XObject::Form').new( |%params );
        $xobject.Resources = self.find-prop('Resources');
        $xobject.BBox = self.find-prop('MediaBox');

        $xobject;
    }

}
