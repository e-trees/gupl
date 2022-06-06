module Gupl
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

end
