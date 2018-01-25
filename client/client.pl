#!/bin/perl

use warnings;
use strict;

#Libs
use Config::IniFiles;
use IO::Socket::INET;
 
# Config parameters
my $params = Config::IniFiles->new( -file => "./config.ini");

# auto-flush on socket
$| = 1;
 
# create a connecting socket
my $socket = new IO::Socket::INET (
    PeerHost => $params->val("Client", "address"),
    PeerPort => $params->val("Client", "port"),
    Proto => 'tcp'
);
die "cannot connect to the server $!\n" unless $socket;
$socket->autoflush;
print "Connected to the server\n";

while (1) {
    # OUT
    print "We've got nothing to send, can you type something ?\n";
    my $req = <STDIN>;
    chomp $req;
    if ($req eq "-1") {
        last;
    }
    $socket->send($req."\n");
    # IN
    my $res = "";
    $socket->recv($res, 1024);
    chomp $res;
    if($res ne "ack") {
        print $res."\n";
    }
}
$socket->close();