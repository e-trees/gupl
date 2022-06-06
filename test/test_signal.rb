# frozen_string_literal: true

require "test_helper"

require 'gupl/signal'
require 'stringio'

class TestGupl < Minitest::Test

  def test_local_signal_vector
    signal = Gupl::LocalSignal.new(name: "mysig", width: "12")
    assert_equal("mysig", signal.name)
    assert_equal(12, signal.width)
    buf =  StringIO.new(+"", "w")
    signal.generate_define(buf)
    expected = "  signal mysig : std_logic_vector(12-1 downto 0);\n"
    assert_equal(expected, buf.string())
  end

  def test_local_signal_bit
    signal = Gupl::LocalSignal.new(name: "mysig", width: "0")
    assert_equal("mysig", signal.name)
    assert_equal(0, signal.width)
    buf =  StringIO.new(+"", "w")
    signal.generate_define(buf)
    expected = "  signal mysig : std_logic;\n"
    assert_equal(expected, buf.string())
  end

  def test_global_port_vector
    port = Gupl::GenericPort.new(name: "myport", width: "12", dir: "in")
    assert_equal("myport", port.name)
    assert_equal(12, port.width)
    assert_equal(true, port.input?)
    assert_equal(false, port.output?)
    assert_equal(false, port.inout?)
    buf =  StringIO.new(+"", "w")
    port.generate_define(buf)
    expected = "  myport : in std_logic_vector(12-1 downto 0);\n"
    assert_equal(expected, buf.string())
  end

  def test_global_port_bit
    port = Gupl::GenericPort.new(name: "myport", width: "0", dir: "out")
    assert_equal("myport", port.name)
    assert_equal(0, port.width)
    assert_equal(false, port.input?)
    assert_equal(true, port.output?)
    assert_equal(false, port.inout?)
    buf =  StringIO.new(+"", "w")
    port.generate_define(buf)
    expected = "  myport : out std_logic;\n"
    assert_equal(expected, buf.string())
  end

end
