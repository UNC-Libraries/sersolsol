require 'highline/import'
require './lib/setup'

what = ask("Which table: (p)ackages, (s)tates, (e)rrors, or (a)ll\n")

p = true if what == 'p' or what == 'a'
s = true if what == 's' or what == 'a'
e = true if what == 'e' or what == 'a'

$pcoll.remove if p
$scoll.remove if s
$ecoll.remove if e