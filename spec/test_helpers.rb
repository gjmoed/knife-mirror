require 'fileutils'
require 'tmpdir'

module TestHelpers
  def fixtures_path
    File.expand_path(File.dirname(__FILE__) + "/features/fixtures/")
  end

  def fixture_content(file)
    File.read(File.join(fixtures_path, file))
  end
  
  def stdout
    stdout_io.string
  end

  def stderr
    stdout_io.string
  end

end
