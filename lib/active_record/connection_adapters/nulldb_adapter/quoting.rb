class ActiveRecord::ConnectionAdapters::NullDBAdapter
  def self.quote_column_name(name) = %Q("#{name.to_s.gsub('"', '""')}")
end
