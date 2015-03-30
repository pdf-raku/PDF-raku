use v6;

use PDF::Object::Dict;
use PDF::Object::Type;

# /Type /Pages - a node in the page tree

class PDF::Object::Type::Pages
    is PDF::Object::Dict
    does PDF::Object::Type {

    method Count is rw { self<Count> }
    method Kids is rw { self<Kids> }

    #| terminal page node - no children
    multi method find-page(Int $page-num where { self<Count> == + self<Kids> && $_ <= + self<Kids>}) {
        my $page = self<Kids>[$page-num -1];
        my $reader = self.reader
            or return $page;
        $reader.deref( $page );
    }

    #| traverse page tree
    multi method find-page(Int $page-num) {

        my $page-count = 0;
        my $reader = self.reader
            or die "no reader for page traversal";

        for self<Kids>.list {
            my $kid = $reader.deref( $_ );

            if $kid.isa(PDF::Object::Type::Pages) {
                my $sub-pages = $kid<Count>;
                my $sub-page-num = $page-num - $page-count;
                return $kid.find-page( $sub-page-num )
                    if $sub-page-num > 0 && $sub-page-num <= $sub-pages;

                $page-count += $sub-pages
            }
            else {
                $page-count++;
                return $kid
                    if $page-count == $page-num;
            }
        }

        die "unable to locate page: $page-num";
    }

    method AT-POS($pos) is rw {
        self.find-page($pos + 1)
    }
}
