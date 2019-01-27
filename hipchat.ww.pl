#!/usr/bin/perl

{
package HC::API;

#use strict;
#use warnings;
use LWP::UserAgent;
use JSON;

#Setting Global Package Variables
my $ua   = LWP::UserAgent->new();
my $base = 'https://eig.hipchat.com/v2/';


#Defining Methods

#Constructor including Auth key. 
sub new {
   my $class = shift;
   my $self  = { 'auth' => shift };
   die "[!!] Please declare Auth Token with object creation.\n"
      unless $self->{auth};

   $ua->default_header( 'Authorization' => 'Bearer ' . $self->{auth} );

   bless $self, $class;
   return $self;
}

#To Send a message to a specified room, using the ID or group name
#For more info https://www.hipchat.com/docs/apiv2/method/send_message
sub send_room {

   my($self, $room, $msg) = @_;
   my $url  = $base . 'room/' . $room . '/message';
   
   die "[!!] Usage: send_room( <room id>, <message>)\n"
      unless $msg and $room;

   my $payload = {
      'message' => $msg,
   };
   my $json = encode_json($payload); 

   my $res  = $ua->post( $url, 'content-type' => 'application/json', Content => $json);
   if ( !$res->is_success ) {
      print $res->status_line.$/;
      print $res->content.$/;      
   }
}

#https://www.hipchat.com/docs/apiv2/method/private_message_user
sub send_chat {

   my($self, $user, $msg, $code) = @_;

   my $userID = $user =~ /@.*\.com/ ? $user : get_id($user);
   my $url  = $base . 'user/' . $userID . '/message';

   die "[!!] Usage: send_user( <chat id>, <message> )\n"
      unless $msg and $user;

   $msg = '/code ' . $msg if $code;
   my $payload = {
      'message' => $msg,
   };

   my $json = encode_json($payload);

   my $res  = $ua->post( $url, 'content-type' => 'application/json', Content => $json);

   die "$res->status_line.$/.$res->content.$/"
      unless $res->is_success;

}


#To Send a message to a specified room, using the ID or group name
##For more info https://www.hipchat.com/docs/apiv2/method/send_room_notification
sub send_notif {
   my($self, $room, $msg, $color) = @_;
   my $url  = $base . 'room/' . $room . '/notification';

   die "[!!] Usage: send_notif( <room id>, <message>, [color])\n"
      unless $msg and $room;
   
   my $payload = {
      'message' => $msg,
      'color'   => $color ? $color : 'random',
   };
   my $json = encode_json($payload);

   my $res  = $ua->post( $url, 'content-type' => 'application/json', Content => $json);
   if ( !$res->is_success ) {
      print $res->status_line.$/;
      print $res->content.$/;
   }
}

#To Send a message to a specified user, using the ID or email address
#https://www.hipchat.com/docs/apiv2/method/view_recent_privatechat_history
sub get_chat_hist {
   use Data::Dumper;

   my($self, $user, $num, $watch) = @_; 

   my $flag = undef;
   my $userID = $user =~ /@.*\.com$/ ? $user : get_id($user);
   my $url  = $base . 'user/' . $userID . '/history/latest';

   my $maxres = '?max-results=';
   $maxres   .= $num ? $num : '20' ; # $maxres = $maxres . $num ? $num : '20'
   $url .= $maxres;

   die "[!!] Usage: get_chat_hist(<user id>, [max results(1-1000)])\n"
      unless $user;

   my $res  = $ua->get( $url );

   die $res->status_line.$/.$res->content.$/
      unless $res->is_success;

   my $cont = decode_json($res->content);
   my $dd   = Data::Dumper->new($cont->{items});

   foreach my $value ($dd->Values) {
      my $type = $value->{type};
      my $date = $value->{date};
      my $id   = $value->{from}->{id};
      my $name = $value->{from}->{name};
      my $hndl = $value->{from}->{mention_name};
      chomp (my $msg  = $value->{message});

      $date =~ s|T| |;
      chomp(my $time = `date -d'$date' +'%I:%M%p %Y.%m.%d'`);

      store_id($id, $name, $hndl);

      if ( $type eq 'message' ) {
         printf "\n\e[36m \b%s - %s\n\e[33m \b%s\e[0m\n"
         , $name, $time, $msg;
      }
   }
}

#To Grab the recent history for a chat room using the room name
##For more info https://www.hipchat.com/docs/apiv2/method/view_recent_room_history
sub get_room_hist {
   use Data::Dumper;

   my($self, $room, $num) = @_;
   my $url  = $base . 'room/' . $room . '/history/latest';

   my $maxres = '?max-results=';
   $maxres   .= $num ? $num : '20' ;
   $url .= $maxres;

   die "[!!] Usage: get_room_hist(<room id>, [max results(1-1000)])\n"
      unless $room;

   my $res  = $ua->get( $url );

   die $res->status_line.$/.$res->content.$/ 
      unless $res->is_success;

   my $cont = decode_json($res->content);
   my $dd   = Data::Dumper->new($cont->{items});

   foreach my $value ($dd->Values) {
      my $type = $value->{type};
      my $date = $value->{date};
      my $id   = $value->{from}->{id};
      my $name = $value->{from}->{name};
      my $hndl = $value->{from}->{mention_name};
      chomp (my $msg  = $value->{message});

      $date =~ s|T| |;
      chomp(my $time = `date -d'$date' +'%I:%M%p %Y.%m.%d'`);

      store_id($id, $name, $hndl) if $id;

      if ( $type eq 'message' ) {
         printf "\n\e[36m \b%s - @%s - %s\n\e[33m \b%s \e[0m\n"
         , $name, $hndl, $time, $msg;
      } 
   }
}

sub store_id {
   use YAML qw|LoadFile|;

   my ($id, $name, $hndl)= @_;

   my $file = '/home/amzw/learning/inc/userHC.yaml';
   my $yaml = LoadFile($file);
   
   $name =~ s|^\s+||;
   $name =~ s|\s+$||;
   $name =~ s|(\w) (\w)|$1_$2|g;
   $name = lc $name;
   
   $hndl =~ s|^\s+||;
   $hndl =~ s|\s+$||;
   $hndl = lc $hndl;

   if ( !$yaml->{$name} ) {
      open my $fh, '>>', $file or warn "[!!] $!\n";
      print $fh "$name: $id\n";
      close $fh;
   } 
   if ( !$yaml->{$hndl} ) {
      open my $fh, '>>', $file or warn "[!!] $!\n";
      print $fh "$hndl: $id\n";
      close $fh;
   }
}

sub get_id {
   use YAML qw|LoadFile|;
   my $entry = shift;
   $temp = $entry;
   $temp =~ s|^\s+||;
   $temp =~ s|\s+$||;
   $temp =~ s|(\w) (\w)|$1_$2|g;
   $temp = lc $temp;
    
   if ($temp =~ /^\d+$/) { 
      return;
   } else {
      my $ufile = '/home/amzw/perlSTUFFS/inc/userHC.yaml';
      my $ulist = LoadFile($ufile);

      if ($ulist->{$temp}) {
         return $ulist->{$temp};
      } else {
         die "[!!] Don't seem to have $entry in the database ¯\\_(ツ)_/¯.\n" 
            ."Please use ID instead I should be able to grab it after you do that.\n";
      }
   }
}
1;}

use strict;
use warnings;
use Getopt::Long qw|:config gnu_getopt|;
use YAML qw|LoadFile|;

my ($room_hist, $chat_hist, $send_chat, $send_room, $send_notif);
my ($count, $user, $room, $msg, $color, $pipe, $code, $watch);

GetOptions (
   'room-hist|rhist|j' => \$room_hist,
   'chat-hist|chist|h' => \$chat_hist,
   'chat-send|csend|s' => \$send_chat,
   'room-send|rsend|g' => \$send_room,
   'send-notif|nsend|n' => \$send_notif,
   'count|num|c=i' => \$count,
   'room|r=s' => \$room,
   'user|name|u=s' => \$user,
   'color|p=s' => \$color,
   'message|msg|m=s' => \$msg,
   'pipe-message|stdin|f' => \$pipe,
   'code|z' => \$code,
   'watch|w' => \$watch,
   '' => sub {die"Plz, no bare hyphens (-). 10q\n";}
); #or usage() and die "\n";

my $token = '/home/amzw/perlSTUFFS/inc/authHC.yaml';
my $yaml  = LoadFile($token);
my $hc    = HC::API->new($yaml->{auth});

die "[!!] Cannot specify both --message and --pipe-message within the same command.\n"
   if $msg and $pipe;

die "[!!] When sending a message, please specify the user ( --user ) and the message ( --message | --pipe-message ).\n" # and usage()
   if($send_chat and !($user and ($msg or $pipe))); 

die "[!!] When sending a message to a room, please specify the user ( --room ) and the message ( --message | --pipe-message ).\n" # and usage()
   if(($send_room or $send_notif) and !($room and ($msg or $pipe)));


csend() if $send_chat;
rsend() if $send_room;
nsend() if $send_notif;
chist() if $chat_hist;
rhist() if $room_hist;


sub csend {   
   if ( $msg ) { 
      $hc->send_chat( $user, $msg);
   } 
   if ( $pipe ) {
      undef $pipe;
      while (<>) {
         $pipe .= $_;
      }
      $hc->send_chat( $user, $pipe, $code);
   }   
}

sub chist { 
   die "[!!] When checking a chat's history, you must specify the user's name, ID, or email ( --user ).\n" # and usage()
      unless $user;

   warn "[**] No need to set the 'room' (--room) when making requests to a private chat.\n" if $room;
   $hc->get_chat_hist($user, $count, $watch);
}

sub rhist { 
   die "[!!] When checking a room's history, you must specify the user's name, ID, or email ( --user ).\n" # and usage()
      unless $room;
   
   warn "[**] No need to set the 'user' (--user) when making requests to a room.\n" if $user;
   $hc->get_room_hist($room, $count);
}

sub rsend {
   if ( $msg ) {
      $hc->send_room($room, $msg);
   }
   if ( $pipe ) {
      undef $pipe;
      while (<>) {
         $pipe .= $_;
      }
      $hc->send_room( $room, $pipe, $code);
   }
}

sub nsend {
   if ( $msg ) {
      $hc->send_notif( $room, $msg, $color );
   }
   if ( $pipe ) {
      undef $pipe;
      while (<>) {
         $pipe .= $_;
      }
      $hc->send_notif( $room, $pipe, $color);
   }
}

#Branch: testing ; Checking Divergant History

