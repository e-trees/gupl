require 'stringio'
require "gupl/version"
require "gupl/entity"
require "gupl/upl"
require "gupl/statemachine"
require "gupl/process"
require "gupl/signal"

module Gupl

  def self.parse_ports(reader, entity)
    
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

  def self.parse_signals(reader, entity)
    
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

  def self.parse_reset_stage(reader, entity)
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

  def self. parse_idle_stage(reader, entity)
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

  def self.parse_stage(reader, entity, name)
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

  def self.parse_upl(reader, upl)
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

  def self.parse_async(reader,entity)
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

  def self.main(str)
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

    return version, entity
  end

end
