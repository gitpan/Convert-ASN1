%token WORD 1
%token CLASS 2
%token SEQUENCE 3
%token SET 4
%token CHOICE 5
%token OF 6
%token IMPLICIT 7
%token EXPLICIT 8
%token OPTIONAL 9
%token LBRACE 10
%token RBRACE 11
%token COMMA 12
%token ANY 13
%token ASSIGN 14
%token NUMBER 15
%token ENUM 16
%token COMPONENTS 17
%token POSTRBRACE 18

%{
package Convert::ASN1::parser;

;# $Id: //depot/asn/parser.y#5 $

use strict;
use Convert::ASN1 qw(:all);
use vars qw(
  $asn $yychar $yyerrflag $yynerrs $yyn @yyss
  $yyssp $yystate @yyvs $yyvsp $yylval $yys $yym $yyval
);

BEGIN { Convert::ASN1->_internal_syms }

my $yydebug=0;
my %yystate;

my %base_type = (
  BOOLEAN	    => [ asn_encode_tag(ASN_BOOLEAN),    opBOOLEAN ],
  INTEGER	    => [ asn_encode_tag(ASN_INTEGER),    opINTEGER ],
  BIT_STRING	    => [ asn_encode_tag(ASN_BIT_STR),    opBITSTR  ],
  OCTET_STRING	    => [ asn_encode_tag(ASN_OCTET_STR),  opSTRING  ],
  STRING	    => [ asn_encode_tag(ASN_OCTET_STR),  opSTRING  ],
  NULL 		    => [ asn_encode_tag(ASN_NULL), 	 opNULL    ],
  OBJECT_IDENTIFIER => [ asn_encode_tag(ASN_OBJECT_ID),  opOBJID   ],
  REAL		    => [ asn_encode_tag(ASN_REAL), 	 opREAL    ],
  ENUMERATED	    => [ asn_encode_tag(ASN_ENUMERATED), opINTEGER ],
  ENUM		    => [ asn_encode_tag(ASN_ENUMERATED), opINTEGER ],

  SEQUENCE	    => [ asn_encode_tag(ASN_SEQUENCE | ASN_CONSTRUCTOR), opSEQUENCE ],
  SET               => [ asn_encode_tag(ASN_SET      | ASN_CONSTRUCTOR), opSET ],

  ObjectDescriptor  => [ asn_encode_tag(ASN_UNIVERSAL |  7), opSTRING ],
  UTF8String        => [ asn_encode_tag(ASN_UNIVERSAL | 12), opUTF8 ],
  NumericString     => [ asn_encode_tag(ASN_UNIVERSAL | 18), opSTRING ],
  PrintableString   => [ asn_encode_tag(ASN_UNIVERSAL | 19), opSTRING ],
  TeletexString     => [ asn_encode_tag(ASN_UNIVERSAL | 20), opSTRING ],
  T61String         => [ asn_encode_tag(ASN_UNIVERSAL | 20), opSTRING ],
  VideotexString    => [ asn_encode_tag(ASN_UNIVERSAL | 21), opSTRING ],
  IA5String         => [ asn_encode_tag(ASN_UNIVERSAL | 22), opSTRING ],
  GraphicString     => [ asn_encode_tag(ASN_UNIVERSAL | 25), opSTRING ],
  VisibleString     => [ asn_encode_tag(ASN_UNIVERSAL | 26), opSTRING ],
  ISO646String      => [ asn_encode_tag(ASN_UNIVERSAL | 26), opSTRING ],
  GeneralString     => [ asn_encode_tag(ASN_UNIVERSAL | 27), opSTRING ],
  UTCTime           => [ asn_encode_tag(ASN_UNIVERSAL | 23), opUTIME ],
  GeneralizedTime   => [ asn_encode_tag(ASN_UNIVERSAL | 24), opGTIME ],

  CHOICE => [ '', opCHOICE ],
  ANY    => [ '', opANY ],
);

# Given an OP, wrap it in a SEQUENCE

sub explicit {
  my $op = shift;
  my @seq = @$op;

  @seq[cTYPE,cCHILD,cVAR,cLOOP] = ('SEQUENCE',[$op],undef,undef);
  @{$op}[cTAG,cOPT] = ();

  \@seq;
}

%}

%%

top	: slist		{ $$ = { '' => $1 }; }
	| module
	;

module  : WORD ASSIGN aitem
		{
		  $$ = { $1, [$3] };
		}
	| module WORD ASSIGN aitem
		{
		  $$=$1;
		  $$->{$2} = [$4];
		}
	;

aitem	: class plicit anyelem postrb
		{
		  $3->[cTAG] = $1;
		  $$ = $2 ? explicit($3) : $3;
		}
	| celem
	;

anyelem : onelem
	| eelem
	| oelem
	| selem
	;

celem	: COMPONENTS OF WORD
		{
		  @{$$ = []}[cTYPE,cCHILD] = ('COMPONENTS', $3);
		}
	;

seqset	: SEQUENCE
	| SET
	;

selem	: seqset OF class plicit sselem
		{
		  $5->[cTAG] = $3;
		  @{$$ = []}[cTYPE,cCHILD,cLOOP] = ($1, [$5], 1);
		  $$ = explicit($$) if $4;
		}
	;

sselem	: eelem
	| oelem
	| onelem
	;

onelem	: SEQUENCE LBRACE slist RBRACE
		{
		  @{$$ = []}[cTYPE,cCHILD] = ('SEQUENCE', $3);
		}
	| SET      LBRACE slist RBRACE
		{
		  @{$$ = []}[cTYPE,cCHILD] = ('SET', $3);
		}
	| CHOICE   LBRACE nlist RBRACE
		{
		  @{$$ = []}[cTYPE,cCHILD] = ('CHOICE', $3);
		}
	;

eelem   : ENUM LBRACE elist RBRACE
		{
		  @{$$ = []}[cTYPE] = ('ENUM');
		}
	;

oielem	: WORD
	| SEQUENCE
	| SET
	| ANY
	| ENUM
	;

oelem	: oielem
		{
		  @{$$ = []}[cTYPE] = ($1);
		}
	;

nlist	: nlist1		{ $$ = $1; }
	| nlist1 POSTRBRACE	{ $$ = $1; }
	;

nlist1	: nitem
		{
		  $$ = [ $1 ];
		}
	| nlist1 POSTRBRACE nitem
		{
		  push @{$$=$1}, $3;
		}
	| nlist1 COMMA nitem
		{
		  push @{$$=$1}, $3;
		}
	;

nitem	: WORD class plicit anyelem
		{
		  @{$$=$4}[cVAR,cTAG] = ($1,$2);
		  $$ = explicit($$) if $3;
		}
	;


slist	: slist1		{ $$ = $1; }
	| slist1 POSTRBRACE	{ $$ = $1; }
	;

slist1	: sitem
		{
		  $$ = [ $1 ];
		}
	| slist1 COMMA sitem
		{
		  push @{$$=$1}, $3;
		}
	| slist1 POSTRBRACE sitem
		{
		  push @{$$=$1}, $3;
		}
	;

snitem	: oelem optional
		{
		  @{$$=$1}[cOPT] = ($2);
		}
	| eelem
	| selem
	| onelem
	;

sitem	: WORD class plicit snitem 
		{
		  @{$$=$4}[cVAR,cTAG] = ($1,$2);
		  $$->[cOPT] = $1 if $$->[cOPT];
		  $$ = explicit($$) if $3;
		}
	| celem
	| class plicit onelem
		{
		  @{$$=$3}[cTAG] = ($1);
		  $$ = explicit($$) if $2;
		}
	;

optional :			{ $$ = undef; }
	 | OPTIONAL		{ $$ = 1;     }
	 ;


class	:			{ $$ = undef; }
	| CLASS
	;

plicit	:			{ $$ = undef; }
	| EXPLICIT		{ warn ; $$ = 1;     }
	| IMPLICIT		{ $$ = 0;     }
	;

elist	: eitem			{}
	| elist COMMA eitem	{}
	;

eitem	: WORD NUMBER		{}
	;

postrb	:			{}
	| POSTRBRACE		{}
	;

%%

my %reserved = (
  'OPTIONAL' 	=> $OPTIONAL,
  'CHOICE' 	=> $CHOICE,
  'OF' 		=> $OF,
  'IMPLICIT' 	=> $IMPLICIT,
  'EXPLICIT' 	=> $EXPLICIT,
  'SEQUENCE'    => $SEQUENCE,
  'SET'         => $SET,
  'ANY'         => $ANY,
  'ENUM'        => $ENUM,
  'ENUMERATED'  => $ENUM,
  'COMPONENTS'  => $COMPONENTS,
  '{'		=> $LBRACE,
  '}'		=> $RBRACE,
  ','		=> $COMMA,
  '::='         => $ASSIGN,
);

my $reserved = join("|", reverse sort grep { /\w/ } keys %reserved);

my %tag_class = (
  APPLICATION => ASN_APPLICATION,
  UNIVERSAL   => ASN_UNIVERSAL,
  PRIVATE     => ASN_PRIVATE,
  CONTEXT     => ASN_CONTEXT,
  ''	      => ASN_CONTEXT # if not specified, its CONTEXT
);

;##
;## This is NOT thread safe !!!!!!
;##

my $pos;
my $last_pos;
my @stacked;

sub parse {
  local(*asn) = \($_[0]);
  ($pos,$last_pos,@stacked) = ();

  eval {
    local $SIG{__DIE__};
    compile(verify(yyparse()));
  }
}

sub compile_one {
  my $tree = shift;
  my $ops = shift;
  my $name = shift;
  foreach my $op (@$ops) {
    next unless ref($op) eq 'ARRAY';
    bless $op;
    my $type = $op->[cTYPE];
    if (exists $base_type{$type}) {
      $op->[cTYPE] = $base_type{$type}->[1];
      $op->[cTAG] = defined($op->[cTAG]) ? asn_encode_tag($op->[cTAG]): $base_type{$type}->[0];
    }
    else {
      die "Internal error\n" unless exists $tree->{$type};
      my $ref = compile_one(
		  $tree,
		  $tree->{$type},
		  defined($op->[cVAR]) ? $name . "." . $op->[cVAR] : $name
		);
      if (defined($op->[cTAG]) && $ref->[0][cTYPE] == opCHOICE) {
        @{$op}[cTYPE,cCHILD] = (opSEQUENCE,$ref);
      }
      else {
        @{$op}[cTYPE,cCHILD,cLOOP] = @{$ref->[0]}[cTYPE,cCHILD,cLOOP];
      }
      $op->[cTAG] = defined($op->[cTAG]) ? asn_encode_tag($op->[cTAG]): $ref->[0][cTAG];
    }
    $op->[cTAG] |= chr(ASN_CONSTRUCTOR)
      if length $op->[cTAG] && ($op->[cTYPE] == opSET || $op->[cTYPE] == opSEQUENCE);

    if ($op->[cCHILD]) {
      ;# If we have children we are one of
      ;#  opSET opSEQUENCE opCHOICE

      compile_one($tree, $op->[cCHILD], defined($op->[cVAR]) ? $name . "." . $op->[cVAR] : $name);

      ;# If a CHOICE is given a tag, then it must be EXPLICIT
      $op = explicit($op) if $op->[cTYPE] == opCHOICE && defined($op->[cTAG]) && length($op->[cTAG]);

      if ( @{$op->[cCHILD]} > 1) {
        ;#if ($op->[cTYPE] != opSEQUENCE) {
        ;# Here we need to flatten CHOICEs and check that SET and CHOICE
        ;# do not contain duplicate tags
        ;#}
      }
      else {
	;# A SET of one element can be treated the same as a SEQUENCE
	$op->[cTYPE] = opSEQUENCE if $op->[cTYPE] == opSET;
      }
    }
  }
  $ops;
}

sub compile {
  my $tree = shift;

  ;# The tree should be valid enough to be able to
  ;#  - resolve references
  ;#  - encode tags
  ;#  - verify CHOICEs do not contain duplicate tags

  ;# once references have been resolved, and also due to
  ;# flattening of COMPONENTS, it is possible for an op
  ;# to appear in multiple places. So once an op is
  ;# compiled we bless it. This ensure we dont try to
  ;# compile it again.

  while(my($k,$v) = each %$tree) {
    compile_one($tree,$v,$k);
  }

  $tree;
}

sub verify {
  my $tree = shift or return;
  my $err = "";

  ;# Well it parsed correctly, now we
  ;#  - check references exist
  ;#  - flatten COMPONENTS OF (checking for loops)
  ;#  - check for duplicate var names

  while(my($name,$ops) = each %$tree) {
    my $stash = {};
    my @scope = ();
    my $path = "";
    my $idx = 0;

    while($ops) {
      if ($idx < @$ops) {
	my $op = $ops->[$idx++];
	my $var;
	if (defined ($var = $op->[cVAR])) {
	  
	  $err .= "$name: $path.$var used multiple times\n"
	    if $stash->{$var}++;

	}
	if (defined $op->[cCHILD]) {
	  if (ref $op->[cCHILD]) {
	    push @scope, [$stash, $path, $ops, $idx];
	    if (defined $var) {
	      $stash = {};
	      $path .= "." . $var;
	    }
	    $idx = 0;
	    $ops = $op->[cCHILD];
	  }
	  elsif ($op->[cTYPE] eq 'COMPONENTS') {
	    splice(@$ops,--$idx,1,expand_ops($tree, $op->[cCHILD]));
	  }
          else {
	    die "Internal error\n";
          }
	}
      }
      else {
	my $s = pop @scope
	  or last;
	($stash,$path,$ops,$idx) = @$s;
      }
    }
  }
  die $err if length $err;
  $tree;
}

sub expand_ops {
  my $tree = shift;
  my $want = shift;
  my $seen = shift || { };
  
  die "COMPONENTS OF loop $want\n" if $seen->{$want}++;
  die "Undefined macro $want\n" unless exists $tree->{$want};
  my $ops = $tree->{$want};
  die "Bad macro for COMPUNENTS OF '$want'\n"
    unless @$ops == 1
        && ($ops->[0][cTYPE] eq 'SEQUENCE' || $ops->[0][cTYPE] eq 'SET')
        && ref $ops->[0][cCHILD];
  $ops = $ops->[0][cCHILD];
  for(my $idx = 0 ; $idx < @$ops ; ) {
    my $op = $ops->[$idx++];
    if ($op->[cTYPE] eq 'COMPONENTS') {
      splice(@$ops,--$idx,1,expand_ops($tree, $op->[cCHILD], $seen));
    }
  }

  @$ops;
}

sub _yylex {
  my $ret = &_yylex;
  warn $ret;
  $ret;
}

sub yylex {
  return shift @stacked if @stacked;

  while ($asn =~ /\G(?:
	  (\s+|--[^\n]*)
	|
	  ([,{}]|::=)
	|
	  ($reserved)\b
	|
	  (
	    (?:OCTET|BIT)\s+STRING
	   |
	    OBJECT\s+IDENTIFIER
	  )\b
	|
	  (\w+)
	|
	    \[\s*
	  (
	   (?:(?:APPLICATION|PRIVATE|UNIVERSAL|CONTEXT)\s+)?
	   \d+
          )
	    \s*\]
	|
	  \((\d+)\)
	)/sxgo
  ) {

    ($last_pos,$pos) = ($pos,pos($asn));

    next if defined $1; # comment or whitespace

    my $paren = 1;
    {
      no strict 'refs';
      # only one paren will be defined
      $paren++ until defined ${$paren}; # $#- in perl-5.6
    }

    if ($paren <= 3) {
      # A comma is not required after a '}' so to aid the
      # parser we insert a fake token after any '}'
      push @stacked, $POSTRBRACE if $paren == 2 && $+ eq '}';

      return $reserved{$yylval = $+};
    }

    if ($paren == 4) {
      ($yylval = $+) =~ s/\s+/_/g;
      return $WORD;
    }

    if ($paren == 5) {
      $yylval = $+;
      return $WORD;
    }

    if ($paren == 6) {
      my($class,$num) = ($+ =~ /^([A-Z]*)\s*(\d+)$/);
      $yylval = asn_tag($tag_class{$class}, $num); 
      return $CLASS;
    }

    if ($paren == 7) {
      $yylval = $+;
      return $NUMBER;
    }

    die "Internal error\n";

  }

  die "Parse error before ",substr($asn,$pos,40),"\n"
    unless $pos == length($asn);

  0
}

sub yyerror {
  die @_," ",substr($asn,$last_pos,40),"\n";
}

1;
