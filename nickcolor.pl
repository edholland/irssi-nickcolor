use strict;
use Irssi 20020101.0250 ();
use vars qw($VERSION %IRSSI); 
$VERSION = "1.2";
%IRSSI = (
    authors     => "Timo Sirainen, Ian Peters, modified by Daniele Sluijters, Edwin \"Dutchy\" Smulders",
    contact	=> "tss\@iki.fi, mail\@dutchy.org", 
    name        => "Nick Color",
    description => "assign a different color for each nick",
    license	=> "Public Domain",
    url		=> "https://github.com/Dutchy-/irssi-nickcolor",
    changed	=> "2012-04-23T15:17+0100"
);

# hm.. i should make it possible to use the existing one..
Irssi::theme_register([
  'pubmsg_hilight', '{pubmsghinick $0 $3 $1}$2'
]);

my %saved_colors;
my %session_colors = {};
my @colors = qw/2 3 4 5 6 7 9 10 11 12 13/;
# This hash is used globally across all channels, so collisions may still occur where channel size < 11
my %used;
foreach my $c (@colors) {
    $used{$c} = 0;
}

sub load_colors {
  open COLORS, "$ENV{HOME}/.irssi/saved_colors";

  while (<COLORS>) {
    # I don't know why this is necessary only inside of irssi
    my @lines = split "\n";
    foreach my $line (@lines) {
      my($nick, $color) = split ":", $line;
      # Set color, and keep counter for later
      $saved_colors{$nick} = $color;
      $used{$color} += 1;
    }
  }

  close COLORS;
}

sub save_colors {
  open COLORS, ">$ENV{HOME}/.irssi/saved_colors";

  foreach my $nick (keys %saved_colors) {
    print COLORS "$nick:$saved_colors{$nick}\n";
  }
    Irssi::print("Saved colors to $ENV{HOME}/.irssi/saved_colors");

  close COLORS;
}

# If someone we've colored (either through the saved colors, or the hash
# function) changes their nick, we'd like to keep the same color associated
# with them (but only in the session_colors, ie a temporary mapping).

sub sig_nick {
  my ($server, $newnick, $nick, $address) = @_;
  my $color;

  $newnick = substr ($newnick, 1) if ($newnick =~ /^:/);

  if ($color = $saved_colors{$nick}) {
    $session_colors{$newnick} = $color;
  } elsif ($color = $session_colors{$nick}) {
    $session_colors{$newnick} = $color;
  }
  # Dont increment the used counters here as this is 1:1 swap, and 
  # frequent nick changes could affect the distribution of colours otherwise
}

# This gave reasonable distribution values when run across
# /usr/share/dict/words

sub simple_hash {
  my ($string) = @_;
  chomp $string;
  my @chars = split //, $string;
  my $counter;

  foreach my $char (@chars) {
    $counter += ord $char;
  }

  $counter = $colors[$counter % 11];

  return $counter;
}

# FIXME: breaks /HILIGHT etc.
sub sig_public {
  my ($server, $msg, $nick, $address, $target) = @_;
  my $chanrec = $server->channel_find($target);
  return if not $chanrec;
  my $nickrec = $chanrec->nick_find($nick);
  return if not $nickrec;
  my $nickmode = $nickrec->{op} ? "@" : $nickrec->{voice} ? "+" : "";

  # Has the user assigned this nick a color?
  my $color = $saved_colors{$nick};

  # Have -we- already assigned this nick a color?
  if (!$color) {
    $color = $session_colors{$nick};
  }
  
  # Let's assign this nick a color
  if (!$color) {
    $color = simple_hash $nick;

    # Check if the color we want is available
    if ( $used{$color} == 0 ) {
      $session_colors{$nick} = $color ;
    } else {
      # Pick the _least_ used color
      $color = (sort {$used{$a} cmp $used{$b} } keys %used)[0];
      $session_colors{$nick} = $color;
    }
    # Store the color used
    $used{$color} += 1;
  } 

  $color = "0".$color if ($color < 10);
  $server->command('/^format pubmsg {pubmsgnick $2 {pubnick '.chr(3).$color.'$0}}$1');
}

sub cmd_color {
  my ($data, $server, $witem) = @_;
  my ($op, $nick, $color) = split " ", $data;

  $op = lc $op;

  if (!$op) {
    Irssi::print ("Supported commands: 
    preview (list possible colors and their codes)
    list (show current entries in saved_colors)
    set <nick> <color> (associate a color to a nick)
    clear <nick> (delete color associated to nick)
    save (save colorsettings to saved_colors file)");
  } elsif ($op eq "save") {
    save_colors;
  } elsif ($op eq "set") {
    if (!$nick) {
      Irssi::print ("Nick not given");
    } elsif (!$color) {
      Irssi::print ("Color not given");
    } elsif ($color < 2 || $color > 14) {
      Irssi::print ("Color must be between 2 and 14 inclusive");
    } else {
      $saved_colors{$nick} = $color;
    }
  } elsif ($op eq "clear") {
    if (!$nick) {
      Irssi::print ("Nick not given");
    } else {
      delete ($saved_colors{$nick});
    }
  } elsif ($op eq "list") {
    Irssi::print ("\nSaved Colors:");
    foreach my $nick (keys %saved_colors) {
      Irssi::print (chr (3) . "$saved_colors{$nick}$nick" .
		    chr (3) . "1 ($saved_colors{$nick})");
    }
  } elsif ($op eq "preview") {
    Irssi::print ("\nAvailable colors:");
    foreach my $i (2..14) {
      Irssi::print (chr (3) . "$i" . "Color #$i");
    }
  }
}

load_colors;

Irssi::command_bind('color', 'cmd_color');

Irssi::signal_add('message public', 'sig_public');
Irssi::signal_add('event nick', 'sig_nick');
