use v6;

use PDF::Reader::Tied;

class PDF::Reader::Tied::Array
    does PDF::Reader::Tied {

    method ACCEPTS(*@arg) {
        my $result := callsame;
        note "ACCEPTS {{ :@arg}.perl} --> {$result.perl}";
        $result;
    }

    method ASSIGN-POS(*@arg) {
        my $result := callsame;
        note "ASSIGN-POS {{ :@arg}.perl} --> {$result.perl}";
        $result;
    }

    method AT-POS(*@arg) {
        my $result := callsame;
        note "AT-POS {{ :@arg}.perl} --> {$result.perl}";
        $result;
    }

    method BIND-POS(*@arg) {
        my $result := callsame;
        note "BIND-POS {{ :@arg}.perl} --> {$result.perl}";
        $result;
    }

    method DELETE-POS(*@arg) {
        my $result := callsame;
        note "DELETE-POS {{ :@arg}.perl} --> {$result.perl}";
        $result;
    }

    method DUMP(*@arg) {
        my $result := callsame;
        note "DUMP {{ :@arg}.perl} --> {$result.perl}";
        $result;
    }

    method EXISTS-POS(*@arg) {
        my $result := callsame;
        note "EXISTS-POS {{ :@arg}.perl} --> {$result.perl}";
        $result;
    }

    method FLATTENABLE_HASH(*@arg) {
        my $result := callsame;
        note "FLATTENABLE_HASH {{ :@arg}.perl} --> {$result.perl}";
        $result;
    }

    method FLATTENABLE_LIST(*@arg) {
        my $result := callsame;
        note "FLATTENABLE_LIST {{ :@arg}.perl} --> {$result.perl}";
        $result;
    }

    method PARAMETERIZE_TYPE(*@arg) {
        my $result := callsame;
        note "PARAMETERIZE_TYPE {{ :@arg}.perl} --> {$result.perl}";
        $result;
    }

    method REIFY(*@arg) {
        my $result := callsame;
        note "REIFY {{ :@arg}.perl} --> {$result.perl}";
        $result;
    }

    method STORE(*@arg) {
        my $result := callsame;
        note "STORE {{ :@arg}.perl} --> {$result.perl}";
        $result;
    }

    method STORE_AT_POS(*@arg) {
        my $result := callsame;
        note "STORE_AT_POS {{ :@arg}.perl} --> {$result.perl}";
        $result;
    }

 }
