use v6;

use PDF::Object::Dict;
use PDF::Object::Type;
use PDF::Object::Inheritance;
use PDF::Object::Type::XObject;
use PDF::Object::Type::XObject::Form;

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
        my $contents = self.Contents;
        my %params = $contents.get-stream();
        my $xobject = PDF::Object::Type::XObject::Form.new( |%params );
        $xobject.Resources = self.find-prop('Resources');
        $xobject.BBox = self.find-prop('MediaBox');

        $xobject;
    }

    #| ensure that the object is registered as a page resource. Return a unique
    #| name for it.
    method register-xobject(PDF::Object::Type::XObject $xobject) {
        my $id = $xobject.id;
        my $resources = self.find-prop('Resources')
            // do {
                self.Resources = {};
                self.Resources
        };

        $resources<XObject> //= {};

        for $resources<XObject>.keys -> $xo-name {
            my $xo-id = $resources<XObject>{$xo-name}.id;

            # we've already got that object, thanks!
            return $xo-name
                if $xo-id eq $id;
        }

        # generate a name and register it in this page's resources
        my $base = $xobject.isa(PDF::Object::Type::XObject::Form)
            ?? 'Fm'
            !! 'Im';

        my $n = (1..*).first({ $resources<XObject>{$base~$_}:!exists });
        my $name = $base ~ $n;
        $resources<XObject>{$name} = $xobject;

        $name;
    }

}
