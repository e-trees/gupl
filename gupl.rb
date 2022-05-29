require 'stringio'

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
  
  def generate_define(buf)
    if @width > 0 then
      buf.puts("  #{@name} : #{@dir} std_logic_vector(#{@width}-1 downto 0);")
    else
      buf.puts("  #{@name} : #{@dir} std_logic;")
    end
  end
  
end

class UPLVariable
  def initialize(upl, name, pos, bits)
    @upl = upl
    @name = name
    @pos = pos
    if bits[0] == '<' then
      @storage = true
      @bits = bits[1..].to_i
    else
      @storage = false
      @bits = bits.to_i
    end
    @signals = []
    if @storage then
      @signals << LocalSignal.new(name: "#{@name}_waddr", width: 32)
      @signals << LocalSignal.new(name: "#{@name}_we", width: 1)
      @signals << LocalSignal.new(name: "#{@name}_din", width: @upl.width)
      @signals << LocalSignal.new(name: "#{@name}_raddr", width: 32)
      @signals << LocalSignal.new(name: "#{@name}_dout", width: @upl.width)
      @signals << LocalSignal.new(name: "#{@name}_send_words", width: 32)
      @signals << LocalSignal.new(name: "#{@name}_recv_words", width: 32)
    else
      @signals << LocalSignal.new(name: "#{@name}", width: bits)
    end
  end
  attr_reader :name, :pos, :bits, :upl

  def generate_define(buf)
    @signals.each{|signal|
      signal.generate_define(buf)
    }
  end

  def storage?()
    return @storage
  end
  
end

class UPL
  def initialize(entity:, name:, width:, id:)
    @entity = entity
    @name = name
    @width = width.to_i
    @id = id.to_i
    @variables = []
    @variable_ptr = 0
    @stages = []
    @storage = nil
  end
  attr_reader :id, :name, :width
  attr_reader :data, :enable, :ack, :request
  attr_reader :variables, :stages
  
  def add_variable(name, bits)
    variable = UPLVariable.new(self, name, @variable_ptr, bits)
    @variables << variable
    if (@variable_ptr / @width) > (@stages.size - 1) then
      @stages << [variable]
    else
      @stages[-1] << variable
    end
    @variable_ptr += variable.bits
    if variable.storage?
      @storage = variable
    end
  end

  def generate_ports(buf)
    buf.puts("  -- #{@name}")
    @data.generate_define(buf)
    @enable.generate_define(buf)
    @request.generate_define(buf)
    @ack.generate_define(buf)
    buf.puts("")
  end

end

class RecvUPL < UPL

  def initialize(entity:, name:, width:, id:)
    super(entity: entity, name: name, width: width, id: id)
    @data = GenericPort.new(name: "UPL_#{@name}_data", width: @width, dir: "in")
    @enable = GenericPort.new(name: "UPL_#{@name}_en", width: 0, dir: "in")
    @request = GenericPort.new(name: "UPL_#{@name}_req", width: 0, dir: "in")
    @ack = GenericPort.new(name: "UPL_#{@name}_ack", width: 0, dir: "out")
  end

  def generate_stages(buf)
    t = " " * 8
    @stages.each_with_index{|stage, i|
      buf.puts("#{t}when #{name}_recv_#{i} =>")
      pos = @width
      if i == 0 then
        buf.puts("#{t}  if #{enable.name} = '1' then")
        buf.puts("#{t}    #{@ack.name} <= '0';")
        buf.puts("#{t}  else")
        buf.puts("#{t}    #{@ack.name} <= '1';")
        buf.puts("#{t}  end if;")
      else
        buf.puts("#{t}  #{@ack.name} <= '0';")
      end
      stage.each_with_index{|variable|
        if variable.storage? then
          buf.puts("#{t}  if #{enable.name} = '1' then")
          buf.puts("#{t}    #{variable.name}_waddr <= std_logic_vector(unsigned(#{variable.name}_waddr)+1);")
          buf.puts("#{t}    #{variable.name}_we <= \"1\";")
          buf.puts("#{t}    #{variable.name}_din <= #{@data.name};")
          buf.puts("#{t}    #{variable.name}_recv_words <= std_logic_vector(unsigned(#{variable.name}_recv_words)+1);")
          buf.puts("#{t}  else")
          buf.puts("#{t}    #{variable.name}_we <= \"0\";")
          buf.puts("#{t}  end if;")
        else
          buf.puts("#{t}  #{variable.name} <= #{@data.name}(#{pos-1} downto #{pos-variable.bits});")
          pos -= variable.bits
        end
      }

      if i == 0 then
        buf.puts("#{t}  if #{enable.name} = '1' then")
        t += "  "
      end

      buf.puts("#{t}  #{@entity.process.statemachine.name} <= #{name}_recv_#{i+1};")
        
      if i == 0 then
        t = t[2..]
        buf.puts("#{t}  end if;")
      end
    }
    buf.puts("#{t}when #{name}_recv_#{stages.size} =>")
    buf.puts("#{t}  if #{@enable.name} = '0' then")
    buf.puts("#{t}    #{@entity.process.statemachine.name} <= #{@entity.process.statemachine.name}_next;")
    if @storage != nil then
      buf.puts("#{t}    #{@storage.name}_we <= \"0\";")
      buf.puts("#{t}  else")
      buf.puts("#{t}    #{@storage.name}_waddr <= std_logic_vector(unsigned(#{@storage.name}_waddr)+1);")
      buf.puts("#{t}    #{@storage.name}_we <= \"1\";")
      buf.puts("#{t}    #{@storage.name}_din <= #{@data.name};")
      buf.puts("#{t}    #{@storage.name}_recv_words <= std_logic_vector(unsigned(#{@storage.name}_recv_words)+1);")
    end
    buf.puts("#{t}  end if;")
  end
  
end

class SendUPL < UPL

  def initialize(entity:, name:, width:, id:)
    super(entity: entity, name: name, width: width, id: id)
    @data = GenericPort.new(name: "UPL_#{@name}_data", width: @width, dir: "out")
    @enable = GenericPort.new(name: "UPL_#{@name}_en", width: 0, dir: "out")
    @request = GenericPort.new(name: "UPL_#{@name}_req", width: 0, dir: "out")
    @ack = GenericPort.new(name: "UPL_#{@name}_ack", width: 0, dir: "in")
  end
  
  def generate_stages(buf)
    buf.puts("        when #{name}_send_0 =>")
    buf.puts("          #{@request.name} <= '1';")
    if @storage != nil then
      buf.puts("          #{@storage.name}_send_words <= (others => '0');")
    end
    buf.puts("          if #{@ack.name} = '1' then")
    if @storage != nil then
      buf.puts("            #{@storage.name}_raddr <= (others => '0'); -- for next next")
    end
    buf.puts("            #{@entity.process.statemachine.name} <= #{name}_send_1;")
    buf.puts("          end if;")
    
    buf.puts("        when #{name}_send_1 =>")
    buf.puts("          #{@entity.process.statemachine.name} <= #{name}_send_2;")
    if @storage != nil and @stages[0][0] == @storage then
      buf.puts("            #{@storage.name}_raddr <= std_logic_vector(unsigned(#{@storage.name}_raddr)+1);")
    end
    
    @stages.each_with_index{|stage, i|
      buf.puts("        when #{name}_send_#{i+2} =>")
      pos = @width
      state_trans = false
      buf.puts("          #{@request.name} <= '0';")
      stage.each{|variable|
        if variable.storage? then
          state_trans = true
          buf.puts("          if #{variable.name}_recv_words = #{variable.name}_send_words then")
          buf.puts("            #{@entity.process.statemachine.name} <= #{@entity.process.statemachine.name}_next;")
          buf.puts("            #{@enable.name} <= '0';")
          buf.puts("          else")
          buf.puts("            #{variable.name}_raddr <= std_logic_vector(unsigned(#{variable.name}_raddr)+1); -- for next next")
          buf.puts("            #{@data.name} <= #{variable.name}_dout;")
          buf.puts("            #{variable.name}_send_words <= std_logic_vector(unsigned(#{variable.name}_send_words)+1);")
          buf.puts("            #{@enable.name} <= '1';")
          buf.puts("          end if;")
        else
          buf.puts("          #{@data.name}(#{pos-1} downto #{pos-variable.bits}) <= #{variable.name};")
          pos -= variable.bits
        end
      }
      if @storage != nil and @stages[i+1] != nil and @stages[i+1][0] == @storage then
        buf.puts("          #{@storage.name}_raddr <= std_logic_vector(unsigned(#{@storage.name}_raddr)+1); -- for next next")
      end
      if state_trans == false
        buf.puts("          #{@enable.name} <= '1';")
        if i == stages.size - 1 then
          buf.puts("          #{@entity.process.statemachine.name} <= #{@entity.process.statemachine.name}_next;")
        else
          buf.puts("          #{@entity.process.statemachine.name} <= #{name}_send_#{i+2+1};")
        end
      end
    }
  end
  
end

class State

  def initialize(statemachine, name)
    @statemachine = statemachine
    @name = name
    @contents = ""
  end
  attr_reader :name

  def add_contents(str)
    @contents += str
  end

  def generate(buf)
    if @contents == "" then
      buf.puts("          pass;")
    else
      buf.puts(@contents)
    end
  end
  
end


class StateMachine

  def initialize(process, name)
    @process = process
    @name = name
    @idle_state = State.new(self, "IDLE")
    @states = [@idle_state]
  end
  attr_reader :name

  def init_storage(buf)
    table = {}
    @process.entity.send_upls.each{|upl|
      upl.variables.each{|var|
        if var.storage? and table[var.name] == nil then
          table[var.name] = true
          buf.puts("          #{var.name}_we <= (others => '0');")
          buf.puts("          #{var.name}_waddr <= (others => '1');")
          buf.puts("          #{var.name}_raddr <= (others => '0');")
          buf.puts("          #{var.name}_recv_words <= (others => '0');")
          buf.puts("          #{var.name}_send_words <= (others => '0');")
        end
      }
    }
    @process.entity.recv_upls.each{|upl|
      upl.variables.each{|var|
        if var.storage? and table[var.name] == nil then
          table[var.name] = true
          buf.puts("          #{var.name}_we <= (others => '0');")
          buf.puts("          #{var.name}_waddr <= (others => '1');")
          buf.puts("          #{var.name}_raddr <= (others => '0');")
          buf.puts("          #{var.name}_recv_words <= (others => '0');")
          buf.puts("          #{var.name}_send_words <= (others => '0');")
        end
      }
    }
  end

  def init_idle_state
    upl = @process.entity.get_main_recv_upl
    if upl != nil
      buf = StringIO.new("", "w")
      buf.puts("          #{name} <= #{upl.name}_recv_0;")
      buf.puts("          #{name}_next <= #{@process.entity.name};")
      @process.entity.send_upls.each{|upl|
        buf.puts("          #{upl.enable.name} <= '0';")
        buf.puts("          #{upl.request.name} <= '0';")
        buf.puts("          #{upl.data.name} <= (others => '0');")
      }
      @process.entity.recv_upls.each{|upl|
        buf.puts("          #{upl.ack.name} <= '0';")
      }
      init_storage(buf)
      @idle_state.add_contents(buf.string)
    end
  end

  def generate(buf)
    init_idle_state()
    buf.puts("      case #{@name} is")
    @states.each{|state|
      buf.puts("        when #{state.name} =>")
      state.generate(buf)
    }
    @process.entity.send_upls.each{|upl|
      upl.generate_stages(buf)
    }
    @process.entity.recv_upls.each{|upl|
      upl.generate_stages(buf)
    }
    buf.puts("        when others => #{@name} <= IDLE;")
    buf.puts("      end case;")
  end

  def add_idle_stage(str)
    @idle_state.add_contents(str)
  end
  
  def add_new_stage(name)
    state = State.new(self, name)
    @states << state
    return state
  end

  def generate_define(buf)
    buf.puts("  -- statemachine type and signal")
    sep = ""
    buf.puts("  type StateType is (")
    @states.each{|state|
      buf.print("#{sep}      #{state.name}")
      sep = ",\n"
    }
    @process.entity.send_upls.each{|upl|
      (upl.stages.size+2).times{|i|
        buf.print("#{sep}      #{upl.name}_send_#{i}")
        sep = ",\n"
      }
    }
    @process.entity.recv_upls.each{|upl|
      (upl.stages.size+1).times{|i|
        buf.print("#{sep}      #{upl.name}_recv_#{i}")
        sep = ",\n"
      }
    }
    buf.puts("\n  );")
    buf.puts("  signal #{@name} : StateType := IDLE;")
    buf.puts("  signal #{@name}_next : StateType := IDLE;")
  end

end


class MainProcess

  def initialize(entity)
    @entity = entity
    @reset_stage = nil
    @statemachine = StateMachine.new(self, "gupl_state")
  end
  attr_reader :entity, :statemachine

  def add_reset_stage(str)
    @reset_stage = str
  end
  
  def add_idle_stage(str)
    @statemachine.add_idle_stage(str)
  end

  def add_new_stage(name)
    @statemachine.add_new_stage(name)
  end

  def generate_reset(buf)
    @entity.send_upls.each{|upl|
      buf.puts("      #{upl.enable.name} <= '0';")
      buf.puts("      #{upl.request.name} <= '0';")
      buf.puts("      #{upl.data.name} <= (others => '0');")
    }
    @entity.recv_upls.each{|upl|
      buf.puts("      #{upl.ack.name} <= '0';")
    }
    buf.puts("      #{@statemachine.name} <= IDLE;")
    buf.puts("      #{@entity.process.statemachine.name}_next <= IDLE;")
    if @reset_stage != nil then
      buf.puts("")
      buf.puts("      -- user-defiend reset stage")
      buf.puts(@reset_stage)
      buf.puts("")
    end
  end

  def generate(buf)
    buf.puts("process(clk)")
    buf.puts("begin")
    buf.puts("  if rising_edge(clk) then")
    buf.puts("    if reset = '1' then")
    generate_reset(buf)
    buf.puts("    else")
    @statemachine.generate(buf)
    buf.puts("    end if;")
    buf.puts("  end if;")
    buf.puts("end process;")
  end
  
end

class Entity
  
  def initialize(name)
    @name = name
    @send_upls = []
    @recv_upls = []
    @ports = []
    @signals = []
    @process = MainProcess.new(self)
    @async = ""
  end
  attr_reader :name, :send_upls, :recv_upls, :process

  def get_main_recv_upl()
    @recv_upls.each{|upl|
      return upl if upl.id == 0
    }
    return nil
  end

  def add_send_upl(upl)
    @send_upls << upl
  end
  
  def add_recv_upl(upl)
    @recv_upls << upl
  end
  
  def add_port(port)
    @ports << port
  end

  def add_signal(signal)
    @signals << signal
  end

  def add_reset_stage(str)
    @process.add_reset_stage(str)
  end
  
  def add_idle_stage(str)
    @process.add_idle_stage(str)
  end

  def add_new_stage(name)
    @process.add_new_stage(name)
  end

  def add_async(str)
    @async += str
  end

  def generate_vhdl_header(buf)
    buf.puts("library ieee;")
    buf.puts("use ieee.std_logic_1164.all;")
    buf.puts("use ieee.numeric_std.all;")
    buf.puts("")
  end

  def generate_entity_define(buf)
    buf.puts("entity #{@name} is")
    buf.puts("port(")
    
    @recv_upls.each{|upl|
      upl.generate_ports(buf)
    }

    @send_upls.each{|upl|
      upl.generate_ports(buf)
    }
    
    buf.puts("  -- user-defiend ports")
    @ports.each{|port|
      port.generate_define(buf)
    }
    buf.puts("")
    
    buf.puts("  -- system clock and reset")
    buf.puts("  clk : in std_logic;")
    buf.puts("  reset : in std_logic")
    buf.puts(");")
    buf.puts("end entity #{@name};")
    buf.puts("")
  end

  def generate_architecture_define(buf)
    buf.puts("architecture RTL of #{@name} is")
    buf.puts("")

    @process.statemachine.generate_define(buf)

    buf.puts()
    buf.puts("  -- UPL signals")
    table = {}
    @send_upls.each{|upl|
      upl.variables.each{|var|
        next if table[var.name] != nil
        table[var.name] = var
        var.generate_define(buf)
      }      
    }
    @recv_upls.each{|upl|
      upl.variables.each{|var|
        next if table[var.name] != nil
        table[var.name] = var
        var.generate_define(buf)
      }      
    }

    buf.puts()
    buf.puts("  -- user-defiend signals")
    @signals.each{|signal|
      signal.generate_define(buf)
    }
    buf.puts("")

    buf.puts("  -- ip-cores")
    simple_dualportram = false
    table.values.each{|var|
      if var.storage? and simple_dualportram == false then
        simple_dualportram = true
        buf.puts("  component simple_dualportram")
        buf.puts("    generic (")
        buf.puts("      DEPTH : integer := 10;")
        buf.puts("      WIDTH : integer := 32;")
        buf.puts("      WORDS : integer := 1024")
        buf.puts("    );")
        buf.puts("    port (")
        buf.puts("      clk    : in  std_logic;")
        buf.puts("      reset  : in  std_logic;")
        buf.puts("      we     : in  std_logic_vector(0 downto 0);")
        buf.puts("      raddr  : in  std_logic_vector(31 downto 0);")
        buf.puts("      waddr  : in  std_logic_vector(31 downto 0);")
        buf.puts("      dout   : out std_logic_vector(WIDTH-1 downto 0);")
        buf.puts("      din    : in  std_logic_vector(WIDTH-1 downto 0);")
        buf.puts("      length : out std_logic_vector(31 downto 0)")
        buf.puts("    );")
        buf.puts("  end component simple_dualportram;")
      end
    }
    buf.puts("")
    
    buf.puts("begin")
    buf.puts("")
    buf.puts("  -- add async")
    buf.puts(@async)
    
    buf.puts("")
    @process.generate(buf)
    buf.puts("")

    buf.puts("")
    table.values.each{|var|
      if var.storage? then
        buf.puts("  buf_#{var.name}_i : simple_dualportram")
        buf.puts("    generic map(")
        buf.puts("      DEPTH => #{Math.log2((var.bits/var.upl.width).ceil).ceil},")
        buf.puts("      WIDTH => #{var.upl.width},")
        buf.puts("      WORDS => #{(var.bits/var.upl.width).ceil}")
        buf.puts("    )")
        buf.puts("    port map(")
        buf.puts("      clk    => clk,")
        buf.puts("      reset  => reset,")
        buf.puts("      we     => #{var.name}_we,")
        buf.puts("      raddr  => #{var.name}_raddr,")
        buf.puts("      waddr  => #{var.name}_waddr,")
        buf.puts("      dout   => #{var.name}_dout,")
        buf.puts("      din    => #{var.name}_din,")
        buf.puts("      length => open")
        buf.puts("    );")
      end
    }

    
    buf.puts("end RTL;")
  end
  
  def generate(buf)
    generate_vhdl_header(buf)
    generate_entity_define(buf)
    generate_architecture_define(buf)
  end

end

def parse_ports(reader, entity)
  
  while line = reader.gets
    l = line.strip
    if /@END/i =~ l then
      return
    else
      items = l.split(/\s*,\s*/)
      port = GenericPort.new(name: items[0], dir: items[2], width: items[1])
      entity.add_port(port)
    end
  end
  
end

def parse_signals(reader, entity)
  
  while line = reader.gets
    l = line.strip
    if /@END/i =~ l then
      return
    else
      items = l.split(/\s*,\s*/)
      signal = LocalSignal.new(name: items[0], width: items[1])
      if items.size > 2 then
        signal.set_type(items[2])
      end
      entity.add_signal(signal)
    end
  end
  
end

def parse_reset_stage(reader, entity)
  str = ""
  while line = reader.gets
    l = line.strip
    if /@END/i =~ l then
      break
    else
      str += line
    end
  end
  entity.add_reset_stage(str)
end

def parse_idle_stage(reader, entity)
  str = ""
  while line = reader.gets
    l = line.strip
    if /@END/i =~ l then
      break
    else
      str += line
    end
  end
  entity.add_idle_stage(str)
end

def parse_stage(reader, entity, name)
  stage = entity.add_new_stage(name)
  
  str = ""
  while line = reader.gets
    l = line.strip
    if /@END/i =~ l then
      break
    elsif /^@TO\s+(\w+)/i =~ l then
      str += "          #{entity.process.statemachine.name} <= #{$1};\n"
    elsif /^@SEND\s+(\w+)/i =~ l then
      str += "          #{entity.process.statemachine.name} <= #{$1}_send_0;\n"
      str += "          #{entity.process.statemachine.name}_next <= IDLE;\n"
    elsif /^@SEND\s+(\w+)\s+@TO\s+(\w+)/i =~ l then
      str += "          #{entity.process.statemachine.name} <= #{$1}_send_0;\n"
      str += "          #{entity.process.statemachine.name}_next <= #{$2};\n"
    elsif /^@RECV\s+(\w+)\s+@TO\s+(\w+)/i =~ l then
      str += "          #{entity.process.statemachine.name} <= #{$1}_recv_0;\n"
      str += "          #{entity.process.statemachine.name}_next <= #{$2};\n"
    else
      str += line
    end
  end
  
  stage.add_contents(str)
end

def parse_upl(reader, upl)
  str = ""
  while line = reader.gets
    l = line.strip
    if /@END/i =~ l then
      return
    else
      items = l.split(/\s*,\s*/)
      upl.add_variable(items[0], items[1])
    end
  end
end

def parse_async(reader,entity)
  str = ""
  while line = reader.gets
    l = line.strip
    if /@END/i =~ l then
      break
    else
      str += line
    end
  end
  entity.add_async(str)
end

def main(str)
  entity = nil
  reader = StringIO.new(str, "r")
  version = nil
  
  while line = reader.gets
    l = line.strip
    if /@GUPL_VERSION\s+(\w+)/i =~ l then
      version = $1
    elsif /@ENTITY\s+(\w+)/i =~ l then
      entity = Entity.new($1)
    elsif /@RECV\s+(\d+)\s+(\w+)\s+(\d+)/i =~ l then
      upl = RecvUPL.new(entity: entity, name: $2, width: $3.to_i, id: $1.to_i)
      entity.add_recv_upl(upl)
      parse_upl(reader, upl)
    elsif /@SEND\s+(\d+)\s+(\w+)\s+(\d+)/i =~ l then
      upl = SendUPL.new(entity: entity, name: $2, width: $3.to_i, id: $1.to_i)
      entity.add_send_upl(upl)
      parse_upl(reader, upl)
    elsif /@PORT/i =~ l then
      parse_ports(reader, entity)
    elsif /@LOCAL/i =~ l then
      parse_signals(reader, entity)
    elsif /@RESET_STAGE/i =~ l then
      parse_reset_stage(reader, entity)
    elsif /@IDLE_STAGE/i =~ l then
      parse_idle_stage(reader, entity)
    elsif /@STAGE\s+(\w+)/i =~ l then
      parse_stage(reader, entity, $1)
    elsif /@ASYNC/i =~ l then
      parse_async(reader, entity)
    end
  end

  puts "ERROR: entity is undefined" if entity == nil
  puts "ERROR: version is undefined" if version == nil
  return version, entity
end

# main
ARGV.each{|argv|
  entity = nil
  version = nil
  open(argv){|f|
    str = f.read()
    version, entity = main(str)
  }
  exit(0) if entity == nil
  exit(0) if version == nil

  dirname = File.dirname(argv)
  open("#{dirname}/#{entity.name}.vhd", "w"){|dst|
    buf = StringIO.new("", "w")
    entity.generate(buf)
    dst.puts(buf.string())
  }
}
