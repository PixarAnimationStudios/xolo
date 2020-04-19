module JSON

  # we want to symbolize names by default
  def self.d3parse(source, opts = {})
    opts[:symbolize_names] = true if opts[:symbolize_names].nil?
    parse source, opts
  end

end
