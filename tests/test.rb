#!/usr/bin/env ruby

require 'pathname'
$this_dir = Pathname(__FILE__).dirname
$LOAD_PATH.unshift($this_dir.parent.join('lib'))
require 'perlstorable'

require 'test/unit'

$nfreeze_pl = $this_dir.join('nfreeze.pl')

class TC_PerlStorable < Test::Unit::TestCase
  def nfreeze(perl_code, &block)
    perl_storable = open("| perl #{$nfreeze_pl}", "r+b") { |pipe|
      pipe.print perl_code
      pipe.flush
      pipe.close_write
      pipe.read
    }
    block.call(PerlStorable.thaw(perl_storable))
  end

  def test_basic
    nfreeze(<<-EOF) {
      {
        package TestPackage;
        sub new {
          my($class, $value) = @_;
          bless { value => $value }, $class;
        }
      };
      my $a = ['hello', 1, 2.3, [-4, 5678901234567890], 'world'];
      my $o = TestPackage->new($a);
      my $result = {
        ('test' x 100) => $o,
        "x" => $a,
        5 => $o,
      };
    EOF
      |value|
      assert_instance_of(Hash, value)
      assert_equal(3, value.size)
      assert_equal(['5', 'test' * 100, 'x'], value.keys.sort)
      a = value['x']
      assert_equal(['hello', 1, "2.3", [-4, "5678901234567890"], 'world'], a)
      o = value['5']
      assert_equal(true, PerlStorable.blessed?(o))
      assert_equal('TestPackage', o.perl_class)
      assert_instance_of(Hash, o)
      assert_equal(1, o.size)
      assert_same(a, o['value'])
      assert_same(o, value['test' * 100])
    }
  end
end
