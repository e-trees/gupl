module Gupl
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
end
