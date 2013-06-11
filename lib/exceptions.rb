class PackageError < StandardError
  def initialize(msg)
    super(msg)
  end
end

class DeleteNonexistentPackageError < PackageError
  def initialize(msg, names)
    super(msg)
    @names = names
  end
end