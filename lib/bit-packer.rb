# encoding: utf-8
# (c) 2011 Martin Kozák (martinkozak@martinkozak.net)

require "hashie/mash"
require "lookup-hash/frozen"

class BitPacker
    
    ##
    # Holds types index.
    #
    
    TYPES = Frozen::LookupHash[
        :number,
        :boolean
    ]

    ##
    # Indicates size of one byte.
    #
    
    BYTESIZE = 8
    
    ##
    # Holds type stack.
    #
    
    @stack
    
    ##
    # Holds stack in compiled form.
    #
    
    @compiled
    
    ##
    # Holds data.
    #
    
    @data
    
    ##
    # Holds raw data.
    # @return [Integer] raw (original) integer data
    #
    
    attr_reader :raw
    @raw
    
    ##
    # Holds total length.
    #
    # @return [Integer] total length of the packed data according 
    #   to declaration
    #
    
    attr_reader :length
    @length
    
    ##
    # Constructor.
    #
    # @param [Integer] data raw integer for unpack
    # @param [Proc] block block with declaration
    # @see #declare
    #
    
    def initialize(data = nil, &block)
        @stack = [ ]
        @length = 0
        self.declare(&block)
        
        if not data.nil?
            self << data
        end
    end
    
    ##
    # Receives declaration.
    # 
    # Adds declaration of bit array items. Can be call multiple times.
    # New delcarations are joind to end of the array.
    #
    # @example
    #   packer.declare do
    #       number (:number) {2}
    #       boolean :boolean
    #   end
    #
    # @param [Proc] block block with declaration
    # @see {TYPES}
    #
    
    def declare(&block)
        self.instance_eval(&block)
    end
    
    ##
    # Handles missing methods as declarations.
    #
    # @param [Symbol] name data type of the entry
    # @param [Array] args first argument is expected to be name
    # @param [Proc] block block which returns length of the entry in bits
    # @return [Integer] new length of the packed data
    # @see #declare
    #

    def method_missing(name, *args, &block)
        if not self.class::TYPES.include? name
            raise Exception::new("Invalid type/method specified: '" << name.to_s << "'.")
        end
    
        if not block.nil?
            length = block.call()
        else
            length = 1
        end
        
        self.add(args.first, name, length)
    end
    
    ##
    # Adds declaration.
    # 
    # @param [Symbol] name name of the entry
    # @param [Symbol] data type of the entry
    # @param [Integer] length length of the entry in bits
    # @return [Integer] new length of the packed data
    #
    
    def add(name, type, length = 1)
        @stack << [name, type, @length, length]
        @length += length
    end
    
    ##
    # Fills by input data.
    # @param [Integer] value raw integer data for unpack
    #
    
    def <<(value)
        if not value.kind_of? Integer
            raise Exception::new("Integer is expected for BitPacker.")
        end
        
        @raw = value
        @data = nil
    end
    
    ##
    # Returns structure analyze.
    # @return [Hashie::Mash] mash with the packed data
    #
    
    def data
        if @data.nil?
            @data = Hashie::Mash::new
            @stack.each do |name, type, position, length|
                rel_pos = @length - position - length
                value = @raw & __mask(rel_pos, length)
                
                case type
                    when :boolean
                        @data[name] = value > 0
                    when :number
                        @data[name] = value >> rel_pos
                end
            end
        end
        
        return @data
    end
    
    ##
    # Converts to integer.
    # @return [Integer] resultant integer according to current data state
    #
    
    def to_i
        result = 0
        @stack.each do |name, type, position, length|
            rel_pos = @length - position - length
            value = self.data[name]
            
            case type
                when :boolean
                    mask = __mask(rel_pos, length)
                    if value === true
                        result |= mask
                    else
                        result &= ~mask
                    end
                when :number
                    value &= __mask(0, length)
                    value = value << rel_pos
                    result |= value
            end
        end
        
        return result
    end

    
    private 
    
    ##
    # Generates mask.
    #
    
    def __mask(position, length = 1)
    
        # length of mask
        mask = 0
        length.times do |i|
            mask += 2 ** i
        end
        
        # position of mask
        mask = mask << position

        return mask
    end
    
end
