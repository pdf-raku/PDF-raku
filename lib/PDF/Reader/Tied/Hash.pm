use v6;

use PDF::Reader::Tied;

role PDF::Reader::Tied::Hash
    does PDF::Reader::Tied {

    method ACCEPTS(*@arg) {
        my $result := callsame;
        note "ACCEPTS {{ :@arg}.perl} --> {$result.perl}";
        $result;
    }

    method ASSIGN-KEY(*@arg) {
        my $result := callsame;
        note "ASSIGN-KEY {{ :@arg}.perl} --> {$result.perl}";
        $result;
    }

    method AT-KEY(*@arg) {
        my $result := callsame;
        note "AT-KEY {{ :@arg}.perl} --> {$result.perl}";
        $result;
    }

    method BIND-KEY(*@arg) {
        my $result := callsame;
        note "BIND-KEY {{ :@arg}.perl} --> {$result.perl}";
        $result;
    }

    method DELETE-KEY(*@arg) {
        my $result := callsame;
        note "DELETE-KEY {{ :@arg}.perl} --> {$result.perl}";
        $result;
    }

    method DUMP(*@arg) {
        my $result := callsame;
        note "DUMP {{ :@arg}.perl} --> {$result.perl}";
        $result;
    }

    method EXISTS-KEY(*@arg) {
        my $result := callsame;
        note "EXISTS-KEY {{ :@arg}.perl} --> {$result.perl}";
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

    method STORE(*@arg) {
        my $result := callsame;
        note "STORE {{ :@arg}.perl} --> {$result.perl}";
        $result;
    }

    method STORE_AT_KEY(*@arg) {
        my $result := callsame;
        note "STORE_AT_KEY {{ :@arg}.perl} --> {$result.perl}";
        $result;
    }
}
