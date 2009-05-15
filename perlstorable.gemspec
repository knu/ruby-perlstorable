Gem::Specification.new do |s|
  s.specification_version = 2
  s.name = "perlstorable"
  s.version = "0.1.3"
  s.required_ruby_version = Gem::Requirement.new(">= 1.8.7")
  s.authors = ["Akinori MUSHA"]
  s.date = "2009-05-15"
  s.summary = "A Ruby module that emulates deserialization of Perl's Storable module."
  s.description = s.summary
  s.email = "knu@idaemons.org"
  s.homepage = "http://github.com/knu/ruby-perlstorable"
  s.files = ["lib/perlstorable.rb"]
  s.require_paths = ["lib"]
  s.has_rdoc = true
  s.rdoc_options = ["--inline-source", "--charset=UTF-8"]
  s.test_files = Dir.glob("tests/*")
end
