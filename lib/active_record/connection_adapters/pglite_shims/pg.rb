# frozen_string_literal: true

# pg gem stub
module PG
  PQTRANS_IDLE = 0 # (connection idle)
  PQTRANS_ACTIVE = 1 # (command in progress)
  PQTRANS_INTRANS = 2 # (idle, within transaction block)
  PQTRANS_INERROR = 3 # (idle, within failed transaction)
  PQTRANS_UNKNOWN = 4 # (cannot determine status)

  class Error < StandardError; end
  class ConnectionBad < Error; end

  class Connection
    class << self
      def quote_ident(str)
        str = str.to_s
        return '""' if str.empty?
        if str =~ /[^a-zA-Z_0-9]/ || str =~ /^[0-9]/
          '"' + str.gsub('"', '""') + '"'
        else
          str
        end
      end
    end
  end

  # Just a stub for now
  class SimpleDecoder
  end
end
