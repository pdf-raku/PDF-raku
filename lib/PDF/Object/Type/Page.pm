use v6;

use PDF::Object::Dict;
use PDF::Object::Type;
use PDF::Object::Inheritance;
use PDF::Object::Type::XObject::Image;
use PDF::Object::Type::XObject::Form;
use PDF::Object::Type::Font;

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

    multi method register-resource( PDF::Object::Type::XObject::Form $object) {
        self!"register-resource"( $object, :base-name<Fm>, );
    }

    multi method register-resource( PDF::Object::Type::XObject::Image $object) {
        self!"register-resource"( $object, :base-name<Im>, );
    }

    multi method register-resource( PDF::Object::Type::Font $object) {
        self!"register-resource"( $object, :base-name<F>, );
    }

    #| ensure that the object is registered as a page resource. Return a unique
    #| name for it.
    method !register-resource(PDF::Object $object, Str :$base-name = <Obj>, :$type = $object.Type) {
        my $id = $object.id;
        my $resources = self.find-prop('Resources')
            // do {
                self.Resources = {};
                self.Resources
        };

        $resources{$type} //= {};

        for $resources{$type}.keys {
            my $xo-id = $resources{$type}{$_}.id;

            # we've already got that object, thanks!
            return $_
                if $xo-id eq $id;
        }

        my $name = (1..*).map({$base-name ~ $_}).first({ $resources{$type}{$_}:!exists });
        $resources{$type}{$name} = $object;

        self.compose( :$name );
    }

}
