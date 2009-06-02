#!/usr/bin/env ruby

require 'pathname'
$this_dir = Pathname(__FILE__).dirname
$LOAD_PATH.unshift($this_dir.parent.join('lib'))
require 'perlstorable'

require 'test/unit'
require 'pp'

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
    nfreeze(<<-'EOF') {
      $Storable::Deparse = 1;
      {
        package TestPackage;
        sub new {
          my($class, $value) = @_;
          bless { value => $value }, $class;
        }
      };
      $a = ['hello', 1, 2.3, [-4, 5678901234], 'world'];
      $o = TestPackage->new($a);
      $result = {
        ('test' x 100) => $o,
        "y" => sub { print "test!" },
        "x" => $a,
        5 => $o,
      };
    EOF
      |value|
      assert_instance_of(Hash, value)
      assert_equal(4, value.size)
      assert_equal(['5', 'test' * 100, 'x', 'y'], value.keys.sort)
      sub = value['y']
      assert_instance_of(PerlStorable::PerlCode, sub)
      assert_instance_of(String, sub.source)
      a = value['x']
      assert_equal(['hello', 1, "2.3", [-4, "5678901234"], 'world'], a)
      o = value['5']
      assert_equal(true, PerlStorable.blessed?(o))
      assert_equal('TestPackage', o.perl_class)
      assert_instance_of(Hash, o)
      assert_equal(1, o.size)
      assert_same(a, o['value'])
      assert_same(o, value['test' * 100])
    }
  end

  def test_tied
    nfreeze(<<-'EOF') {
      {
        package TestTiedScalar;
        sub TIEARRAY {
          my($class, $string) = @_;
          my $scalar = $string;
          bless \$scalar, $class;
        }
        sub POP {
          my($self) = @_;
          if ($$self =~ s/\A(.)//) {
            return $1;
          } else {
            return ();
          }
        }
      };
      tie @array, 'TestTiedScalar', "hello";
      \@array;
    EOF
      |value|
      assert_instance_of(PerlStorable::PerlTiedValue, value)
      tied_to = value.value
      assert_equal('hello', tied_to)
      assert_equal('TestTiedScalar', tied_to.perl_class)
    }
  end
end
