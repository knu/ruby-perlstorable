# -*- mode: ruby; coding: utf-8 -*-
#--
# perlstorable.rb - a library that emulates deserialization of Perl's Storable module
#++
# Copyright (c) 2009 Akinori MUSHA <knu@iDaemons.org>
#
# All rights reserved.  You can redistribute and/or modify it under the same
# terms as Ruby.
#
# == Overview
#
# This library deals with data serialized by Perl's Storable module.
#
# This library requires ruby 1.8.7 or better (including 1.9) at the moment.

require 'stringio'

#
# This module handles the data structure defined and implemented by
# Perl's Storable module.
#
module PerlStorable
  #
  # call-seq:
  #     PerlStorable.thaw(str) => object
  #
  # Deserializes a string serialized by Perl's Storable module.
  #
  # Only data frozen by Storable::nfreeze() is supported at the
  # moment.
  #
  # Blessed Perl objects can be distinguished by using
  # PerlStorable.blessed?(), and the package name of a blessed object
  # can be obtained by PerlBlessed#perl_class.
  #
  # A list of currently unsupported data types includes:
  #   - Tied objects (scalar/array/hash etc.)
  #   - Weak reference
  #   - Code references
  #
  def self.thaw(string_or_iolike)
    if string_or_iolike.respond_to?(:read)
      io = string_or_iolike
      need_close = false
    else
      io = StringIO.new(string_or_iolike)
      need_close = true
    end

    case magic = io.read(2)
    when "\x05\x07"
      # data frozen by Storable::nfreeze()
    else
      raise ArgumentError, 'unsupported format'
    end

    PerlStorable::Reader.new(io).read
  ensure
    io.close if need_close
  end

  SX_OBJECT           =  0 # Already stored object
  SX_LSCALAR          =  1 # Scalar (large binary) follows (length, data)
  SX_ARRAY            =  2 # Array forthcominng (size, item list)
  SX_HASH             =  3 # Hash forthcoming (size, key/value pair list)
  SX_REF              =  4 # Reference to object forthcoming
  SX_UNDEF            =  5 # Undefined scalar
  SX_INTEGER          =  6 # Integer forthcoming
  SX_DOUBLE           =  7 # Double forthcoming
  SX_BYTE             =  8 # (signed) byte forthcoming
  SX_NETINT           =  9 # Integer in network order forthcoming
  SX_SCALAR           = 10 # Scalar (binary, small) follows (length, data)
  SX_TIED_ARRAY       = 11 # Tied array forthcoming
  SX_TIED_HASH        = 12 # Tied hash forthcoming
  SX_TIED_SCALAR      = 13 # Tied scalar forthcoming
  SX_SV_UNDEF         = 14 # Perl's immortal PL_sv_undef
  SX_SV_YES           = 15 # Perl's immortal PL_sv_yes
  SX_SV_NO            = 16 # Perl's immortal PL_sv_no
  SX_BLESS            = 17 # Object is blessed
  SX_IX_BLESS         = 18 # Object is blessed, classname given by index
  SX_HOOK             = 19 # Stored via hook, user-defined
  SX_OVERLOAD         = 20 # Overloaded reference
  SX_TIED_KEY         = 21 # Tied magic key forthcoming
  SX_TIED_IDX         = 22 # Tied magic index forthcoming
  SX_UTF8STR          = 23 # UTF-8 string forthcoming (small)
  SX_LUTF8STR         = 24 # UTF-8 string forthcoming (large)
  SX_FLAG_HASH        = 25 # Hash with flags forthcoming (size, flags, key/flags/value triplet list)
  SX_CODE             = 26 # Code references as perl source code
  SX_WEAKREF          = 27 # Weak reference to object forthcoming
  SX_WEAKOVERLOAD     = 28 # Overloaded weak reference
  SX_ERROR            = 29 # Error

  SHF_TYPE_MASK       = 0x03
  SHF_LARGE_CLASSLEN  = 0x04
  SHF_LARGE_STRLEN    = 0x08
  SHF_LARGE_LISTLEN   = 0x10
  SHF_IDX_CLASSNAME   = 0x20
  SHF_NEED_RECURSE    = 0x40
  SHF_HAS_LIST        = 0x80

  SHT_SCALAR          = 0
  SHT_ARRAY           = 1
  SHT_HASH            = 2
  SHT_EXTRA           = 3

  SHT_TSCALAR         = 4  # 4 + 0 -- tied scalar
  SHT_TARRAY          = 5  # 4 + 1 -- tied array
  SHT_THASH           = 6  # 4 + 2 -- tied hash

  class Reader	# :nodoc: all
    def initialize(io)
      @io = io
      @objects = []
      @packages = []
    end

    def read_byte
      @io.getbyte
    end

    def read_netint32
      n = @io.read(4).unpack('N').first
      if n <= 2147483647
        n
      else
        n - 4294967296
      end
    end

    def read_int32
      read_netint32
    end

    def read_flexlen
      len = read_byte
      if (len & 0x80) != 0
        read_int32
      else
        len
      end
    end

    def read_blob(len)
      @io.read(len)
    end

    if defined?(::Encoding)
      def read_string(len)
        @io.read(len).force_encoding('UTF-8')
      end
    else
      def read_string(len)
        @io.read(len)
      end
    end

    def remember_object(object)
      unless object.nil?
        @objects.each_index { |i|
          @objects[i] = object if @objects[i].nil?
        }
      end
      @objects << object
      object
    end

    def remember_ref()
      @objects << nil
    end

    def remember_ref_undo()
      @objects.pop while @objects.last.nil?
    end

    def lookup_object(index)
      @objects[index]
    end

    def remember_package(package)
      @packages << package
      package
    end

    def read_object(type)
      case type
      when SX_SCALAR
        remember_object(read_blob(read_byte))
      when SX_LSCALAR
        remember_object(read_blob(read_int32))
      when SX_BYTE
        remember_object(read_byte - 128)
      when SX_NETINT
        remember_object(read_netint32)
      when SX_UTF8STR
        remember_object(read_string(read_byte))
      when SX_LUTF8STR
        remember_object(read_string(read_int32))
      when SX_ARRAY
        len = read_int32
        ary = Array.new(len)
        remember_object(ary)
        len.times { |i|
          ary[i] = read
        }
        ary
      when SX_HASH
        size = read_int32
        hash = Hash.new
        remember_object(hash)
        size.times {
          value = read
          key = read_object(SX_LSCALAR)
          hash[key] = value
        }
        hash
      when SX_FLAG_HASH
        frozen = (read_byte != 0)
        size = read_int32
        hash = Hash.new
        remember_object(hash)
        size.times {
          value = read
          flag = (read_byte != 0)
          if flag
            key = read_object(SX_LUTF8STR)
          else
            key = read_object(SX_LSCALAR)
          end
          hash[key] = value
        }
        hash.freeze if frozen
        hash
      when SX_REF
        remember_ref
        read
      when SX_OBJECT
        remember_ref_undo
        lookup_object(read_int32)
      when SX_OVERLOAD
        read
      when SX_BLESS
        package = read_blob(read_flexlen)
        remember_package(package)
        object = read
        object.extend(PerlBlessed).perl_bless(package)
      when SX_IX_BLESS
        package = @packages[read_flexlen]
        object = read
        object.extend(PerlBlessed).perl_bless(package)
      when SX_HOOK
        flags = read_byte

        if (flags & SHF_IDX_CLASSNAME) != 0
          package = @packages[read_int32]
        elsif (flags & SHF_LARGE_CLASSLEN) != 0
          package = read_blob(read_int32)
        else
          package = read_blob(read_byte)
        end

        if (flags & SHF_LARGE_STRLEN) != 0
          string = read_blob(read_int32)
        else
          string = read_blob(read_byte)
        end

        remember_object(string)

        if (flags & SHF_HAS_LIST) != 0
          raise TypeError, 'SX_HOOK having a list not implemented'
          case flags & SHF_TYPE_MASK
          when SHT_TSCALAR
          when SHT_TARRAY
          when SHT_THASH
          end
        else
          string.extend(PerlBlessed).perl_bless(package)
        end
      when SX_SV_YES
        true
      when SX_SV_NO
        false
      when SX_UNDEF, SX_SV_UNDEF
        nil
      else
        raise TypeError, 'unknown data type: %d' % type
      end
    end

    # Reads an object at the posision.
    def read
      read_object(read_byte)
    end
  end

  # This module is used to represent a Perl object blessed in a
  # package by extending an object to hold a package name.
  module PerlBlessed
    # Returns the Perl class the object was blessed into.
    attr_reader :perl_class

    # call-seq:
    #     perl_bless(perl_class) => self
    #
    # Blesses the object into +perl_class+ (String).
    def perl_bless(perl_class)
      @perl_class = perl_class
      self
    end
  end

  # Tests if an object is blessed.
  def self.blessed?(obj)
    obj.is_a?(PerlBlessed)
  end
end

if $0 == __FILE__
  eval DATA.read, nil, $0, __LINE__+4
end

__END__

# TODO: Real tests needed

require 'pp'
obj = PerlStorable.thaw(ARGF.read)
pp obj
