use v6;

use PDF::Object::Dict;
use PDF::DOM;
use PDF::DOM::Page;
use PDF::Object::Inheritance;

# /Type /Pages - a node in the page tree

class PDF::DOM::Pages
    is PDF::Object::Dict
    does PDF::DOM
    does PDF::Object::Inheritance {

    method Count is rw { self<Count> }
    method Kids is rw { self<Kids> }

    #| add new last page
    method add-page( $page = PDF::DOM::Page.new ) {
        my $sub-pages = self.Kids[*-1]
            if self.Kids;

        if $sub-pages && $sub-pages.can('add-page') {
            $sub-pages.add-page( $page )
        }
        else {
            self.Kids.push: $page;
        }

        $page<Parent> //= self;
        self<Count>++;

        $page
    }

    #| terminal page node - no children
    multi method find-page(Int $page-num where { self.Count == + self.Kids && $_ <= + self.Kids}) {
        self.Kids[$page-num -1];
    }

    #| traverse page tree
    multi method find-page(Int $page-num) {
        my $page-count = 0;

        for self.Kids.keys {
            my $kid = self.Kids[$_];

            if $kid.can('find-page') {
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

    method finish {
        my $count = 0;
        my $kids = self.Kids;
        for $kids.keys {
            my $kid = $kids[$_];
            $kid.<Parent> //= self;
            $kid.finish;
            $count += $kid.can('Count') ?? $kid.Count !! 1;
        }
        self<Count> = $count;
    }

}
