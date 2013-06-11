require 'setup'

pkg = ARGV[0]

package = Package.lookup(pkg)

p package

