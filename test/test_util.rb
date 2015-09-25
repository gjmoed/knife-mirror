require 'test/unit'
require 'json'
require_relative '../lib/util'

class Test_UniverseDiff < Test::Unit::TestCase

  ################################
  # Data helper classes
  #
  # The supermarket universe API returns data as follows:
  #   {
  #    "cookbook_a": {
  #        "1.0.0": { "dependencies": {}, "download_url": "a_100_download",
  #            "location_path": "a_path", "location_type": "opscode" },
  #        ...
  #    },
  #    "cookbook_b": { ... }
  #   }
  #
  # Managing test data quickly becomes a hassle, these test classes help with that.
  
  class FakeCookbook
    attr_accessor :name
    attr_accessor :version
    attr_accessor :dependencies
    
    def initialize(name, version, dependencies)
      @name, @version, @dependencies = name, version, dependencies
      @hsh = {
        "dependencies" => self.dependencies,
        "download_url" => "#{self.name}_#{self.version}_download",
        "location_path" => "#{self.name}_path",
        "location_type" => "opscode"
      }
    end

    def name_and_version()
      "#{@name}-#{@version}"
    end

    def add_attribute(key, val)
      @hsh[key] = val
    end
    
    def to_hash()
      @hsh
    end
  end

  class FakeUniverse
    def initialize(*fake_cookbooks)
      @u = {}
      fake_cookbooks.each { |f| self.add(f) }
    end

    def add(fake_cookbook)
      @u[fake_cookbook.name] = {} unless @u[fake_cookbook.name]
      @u[fake_cookbook.name][fake_cookbook.version] = fake_cookbook.to_hash
    end
    
    def universe()
      return @u
    end
  end

  def build_universe_json(*fake_cookbooks)
    u = FakeUniverse.new(*fake_cookbooks)
    return u.universe
  end

  ######################
  
  def setup()
    @a_1 = FakeCookbook.new("a", "1.0.0", {})
    @a_2 = FakeCookbook.new("a", "2.0.0", {})
    @b_1 = FakeCookbook.new("b", "1.0.0", {"nodejs": ">= 0.0.0"})
  end

  def test_diffing_two_nils_returns_nils()
    assert_equal(UniverseDiff.universe_diff(nil, nil), [nil, nil])
  end

  def test_diffing_identical_universes_returns_nothing()
    u = build_universe_json(@a_1, @a_2, @b_1)
    ret = UniverseDiff.universe_diff(u, u)
    assert_equal(0, ret[:removed].keys.count, "Nothing removed")
    assert_equal(0, ret[:added].keys.count, "Nothing added")
  end

  # Build universes out of cookbooks, diff, and compare them to the
  # expected universes.
  def assert_universe_diff_equals(old_cookbooks, new_cookbooks, expected_added, expected_removed)
    old_universe = build_universe_json(*old_cookbooks)
    new_universe = build_universe_json(*new_cookbooks)
    ret = UniverseDiff.universe_diff(old_universe, new_universe)
    added = ret[:added]
    removed = ret[:removed]
    
    expected_added_universe = build_universe_json(*expected_added)
    assert_equal(expected_added_universe, added, "added")

    expected_removed_universe = build_universe_json(*expected_removed)
    assert_equal(expected_removed_universe, removed, "removed")
  end

  def assert_universe_diff_invalid_dependency_changes_equals(old_cookbooks, new_cookbooks, expected_warnings)
    old_universe = build_universe_json(*old_cookbooks)
    new_universe = build_universe_json(*new_cookbooks)
    warnings = UniverseDiff.invalid_dependency_changes(old_universe, new_universe)
    assert_equal(expected_warnings, warnings, "warnings")
  end

  def test_new_cookbook_is_shown_as_added()
    assert_universe_diff_equals([@a_1], [@a_1, @b_1], [@b_1], [])
  end

  def test_new_version_is_shown_as_added()
    assert_universe_diff_equals([@a_1], [@a_1, @a_2], [@a_2], [])
  end

  def test_removed_cookbook_is_shown_as_removed()
    assert_universe_diff_equals([@a_1, @b_1], [@a_1], [], [@b_1])
  end

  def test_removed_version_is_shown_as_removed()
    assert_universe_diff_equals([@a_1, @a_2], [@a_1], [], [@a_2])
  end

  def test_add_and_remove_cookbooks()
    assert_universe_diff_equals([@a_1, @b_1], [@a_2], [@a_2], [@a_1, @b_1])
  end

  def test_add_to_empty_universe()
    assert_universe_diff_equals([], [@a_1, @a_2], [@a_1, @a_2], [])
  end

  def test_remove_all_from_universe()
    assert_universe_diff_equals([@a_1, @a_2], [], [], [@a_1, @a_2])
  end

  def test_the_same_cookbook_version_with_different_dependencies_is_not_returned_as_a_change_but_returns_warning()
    @old_deps = FakeCookbook.new("a", "1.0.0", {})
    @new_deps = FakeCookbook.new("a", "1.0.0", {"nodejs": ">= 0.0.0"})
    assert_universe_diff_equals([@old_deps], [@new_deps], [], [])
    assert_universe_diff_invalid_dependency_changes_equals([@old_deps], [@new_deps], ["a 1.0.0"])
  end

  # A different version of the supermarket may have new attributes for
  # the same cookbook - that is, the universe API call may return
  # different json for the same cookbook.  This attribute change
  # should not show up as a change.
  def test_attribute_addition_is_not_shown_as_a_change()
    @a_old_api = FakeCookbook.new("a", "1.0.0", {"nodejs": ">= 0.0.0"})
    @a_new_api = FakeCookbook.new("a", "1.0.0", {"nodejs": ">= 0.0.0"})
    @a_new_api.add_attribute("somekey", "someval")
    assert_universe_diff_equals([@a_old_api], [@a_new_api], [], [])
  end
  
end
