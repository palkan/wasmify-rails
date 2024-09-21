class IO
  def winsize
    [80, 24]
  end
  def wait_readable(timeout = nil)
    false
  end
  def raw(**kwargs)
    yield
  end
end
