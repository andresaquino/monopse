#!/usr/bin/env perl 
# vim: set ts=3 sw=3 sts=3 et si ai: 
#	
# httpResponse.pl -- Verificar el estado de un site
# -----------------------------------------------------------------------------
# (c) 2008 NEXTEL DE MEXICO
#  
# Andres Aquino <andres.aquino@nextel.com.mx>
# $Id: 5e91b94d5b134e130338d0d1e717d77e92784b88 $

use LWP::Simple;
use URI::Heuristic;

my $raw_url = shift                      
   or die "usage: $0 url\n";
my $url = URI::Heuristic::uf_urlstr($raw_url);

$content = getstore($url,"/tmp/output.html");
print($content."\n");

#
