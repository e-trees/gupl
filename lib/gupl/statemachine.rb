module Gupl
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

end
