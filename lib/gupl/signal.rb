module Gupl
  
  class LocalSignal

    def initialize(name:, width:)
      @name = name
      @width = width.to_i
      @type = "std_logic_vector"
    end
    attr_reader :name, :width
    
    def generate_define(buf)
      if @width > 0 then
        buf.puts("  signal #{@name} : #{@type}(#{@width}-1 downto 0);")
      else
        buf.puts("  signal #{@name} : std_logic;")
      end
    end

    def set_type(type)
      @type = type
    end
    
  end

  class GenericPort

    def initialize(name:, width:, dir:)
      @name = name
      @width = width.to_i
      @dir = dir
    end
    attr_reader :name, :width, :dir

    def input?
      return @dir == "in"
    end
    
    def output?
      return @dir == "out"
    end
    
    def inout?
      return @dir == "inout"
    end
    
    def generate_define(buf)
      if @width > 0 then
        buf.puts("  #{@name} : #{@dir} std_logic_vector(#{@width}-1 downto 0);")
      else
        buf.puts("  #{@name} : #{@dir} std_logic;")
      end
    end
    
  end
  
end
