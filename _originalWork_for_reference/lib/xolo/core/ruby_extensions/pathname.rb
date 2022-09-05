class Pathname

  # This allows us to write out to a file which many other
  # threads or processes are reading, and not worry about
  # them reading a partial file.
  # It does so by writing into a temp file, then moving the
  # file into the path `self`
  #
  # WARNING: This will overwrite the current file.
  #
  # @param data [String] the data to write into the file.
  #
  # @return [void]
  #
  def d3_atomic_write(data)
    # This gives a unique path to a non-existing temp file
    tmpf = Pathname.new(Dir::Tmpname.create('') { |path| path })
    tmpf.open('w+') { |f| f.write data }
    tmpf.rename self
  end

  # Shortcut to parsing the YAML contents of this pathname
  #
  # @return [Object] The parsed JSON contents of self
  #
  def d3_load_yaml
    YAML.load read
  end

end
