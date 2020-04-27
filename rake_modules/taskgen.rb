require 'fileutils'
require 'git'
require 'set'
require 'json'
require 'yaml'
require 'rake'
require 'rake/tasklib'
require 'shellwords'

require 'puppet-lint/tasks/puppet-lint'
require 'puppet-syntax'
require 'puppet-syntax/tasks/puppet-syntax'
require 'rubocop/rake_task'

require 'rake_modules/monkey_patch'
require 'rake_modules/git'
require 'rake_modules/specdeps'

class TaskGen < ::Rake::TaskLib
  attr_accessor :tasks, :failed_specs

  def initialize(path)
    @tasks_categories = [
      :puppet_lint,
      :typos,
      :syntax,
      :rubocop,
      :common_yaml,
      :python_extensions,
      :spec,
      :tox,
      :dhcp,
      :per_module_tox,
      :conftool_schema
    ]
    @git = GitOps.new(path)
    @changed_files = @git.changes_in_head
    @tasks = setup_tasks
    @failed_specs = []
    PuppetSyntax.exclude_paths = ['vendor/**/*']
  end

  def setup_wmf_lint_check
    # Sets up puppet-lint to only check for the wmf style guide
    PuppetLint.configuration.checks.each do |check|
      if check == :wmf_styleguide
        PuppetLint.configuration.send('enable_wmf_styleguide')
      else
        PuppetLint.configuration.send("disable_#{check}")
      end
    end
  end

  def print_wmf_style_violations(problems, other = nil, format = '%{path}:%{line} %{message}')
    # Prints the wmf style violations
    other ||= {}
    events = problems.select do |p|
      other.select { |x| x[:message] == p[:message] && x[:path] == p[:path] }.empty?
    end
    events.each do |p|
      p[:KIND] = p[:kind].to_s.upcase
      puts format(format, p).red
    end
    puts "Nothing found".green if events.length.zero?
  end

  private

  def setup_tasks
    tasks = []
    @tasks_categories.each do |cat|
      method_name = "setup_#{cat}"
      tasks.concat send(method_name)
    end
    setup_wmf_styleguide_delta
    tasks
  end

  def sort_python_files(files, default = :py2)
    py_files = { py2: [], py3: [] }
    files_unknown_version = []
    deps = SpecDependencies.new
    have_own_tox = deps.files_with_own_tox(files)

    files.reject{ |file| have_own_tox.include?(file) }.each do |file|
      next if File.zero?(file)
      # skip files copied from upstream
      next if file.end_with?('.original.py')
      # skip scripts in user home dirs
      next if file.start_with?('modules/admin/files/home')
      shebang = File.open(file) {|f| f.readline}
      match = shebang.match(/#!.*python(\d)/)
      if !match || !match.captures
        files_unknown_version << file
      elsif match.captures[0] == '2'
        py_files[:py2] << file
      elsif match.captures[0] == '3'
        py_files[:py3] << file
      else
        # might be more sensible to fail here?
        files_unknown_version << file
      end
    end
    py_files[default] += files_unknown_version
    puts "python2 files: #{py_files[:py2].length}".green unless py_files[:py2].empty?
    puts "python3 files: #{py_files[:py3].length}".green unless py_files[:py3].empty?
    py_files
  end

  def puppet_changed_files(files = @changed_files)
    files.select{ |x| File.fnmatch("*.pp", x) }
  end

  def filter_files_by(*globs)
    changed = FileList[@changed_files]
    changed.exclude(*PuppetSyntax.exclude_paths).select do |file|
      # If at least one glob pattern matches, the file is included.
      !globs.select{ |glob| File.fnmatch(glob, file)}.empty?
    end
  end

  def linter_problems(files)
    problems = []
    linter = PuppetLint.new
    puppet_changed_files(files).each do |puppet_file|
      next unless File.file?(puppet_file)
      linter.file = puppet_file
      linter.run
      problems.concat(linter.problems)
    end
    problems.reject{ |p| p[:kind] == :ignored }
  end

  def setup_puppet_lint
    # Sets up a standard puppet-lint task
    changed = puppet_changed_files
    return [] if changed.empty?
    # Reset puppet-lint tasks, define a new one
    Rake::Task[:lint].clear
    PuppetLint.configuration.send('disable_wmf_styleguide')
    PuppetLint::RakeTask.new :puppet_lint do |config|
      config.fail_on_warnings = true  # be strict
      config.log_format = '%{path}:%{line} %{KIND} %{message} (%{check})'.red
      config.pattern = changed
    end
    [:puppet_lint]
  end

  def setup_dhcp
    changed = filter_files_by("modules/install_server/files/dhcpd/*")
    return [] if changed.empty?
    unless File.exists?('/usr/sbin/dhcpd')
      puts 'dhcp: skipping tests as dhcpd is not available'
      return []
    end
    desc 'Check dhcp configuration is correct'
    task :dhcp do
      failures = 0
      Dir.mktmpdir do |dir|
        FileUtils.cp_r("modules/install_server/files/dhcpd", dir)
        dhcp_config_dir = File.join dir, "dhcpd"
        dhcp_config_file = File.join dhcp_config_dir, "dhcpd.conf"
        dhcp_config = File.read(dhcp_config_file)
        dhcp_config.gsub!(%r{/etc/dhcp}, dhcp_config_dir)

        File.open(dhcp_config_file, "w") {|file| file.puts dhcp_config }
        begin
          puts "dhcp configuration: BEGIN TEST"
          puts "=============================="
          failures = 1 unless system('/usr/sbin/dhcpd', '-t', '-cf', dhcp_config_file)
        rescue
          failures = 1
        end
      end
      abort("dhcp configuration: NOT OK".red) if failures == 1
      puts "dhcp configuration: END TEST"
      puts "=============================="
    end
    [:dhcp]
  end

  def setup_wmf_styleguide_delta
    changed = @git.changes
    if puppet_changed_files(changed.values.flatten.uniq).empty?
      task :wmf_styleguide do
        puts "wmf-style: no files to check"
      end
      task :wmf_styleguide_delta => [:wmf_styleguide]
    else
      desc 'Check wmf styleguide violations in the current commit'
      task :wmf_styleguide do
        setup_wmf_lint_check
        problems = linter_problems changed[:new]
        print_wmf_style_violations(problems)
        abort("wmf-styleguide: NOT OK".red)
      end

      desc 'Check regressions for the wmf style guide'
      task :wmf_styleguide_delta do
        puts '---> wmf_style lint'
        setup_wmf_lint_check
        if @git.uncommitted_changes?
          puts "Will NOT run the task as you have uncommitted changes that would be lost"
          next
        end
        # Only enable the wmf_styleguide
        new_problems = linter_problems changed[:new]
        old_problems = nil
        @git.exec_in_rewind do
          old_problems = linter_problems changed[:old]
        end
        delta = new_problems.length - old_problems.length
        puts "wmf-style: total violations delta #{delta}"
        puts "NEW violations:"
        print_wmf_style_violations(new_problems, old_problems)
        puts "Resolved violations:"
        print_wmf_style_violations(old_problems, new_problems)
        puts '---> end wmf_style lint'
        abort if delta > 0 # rubocop:disable Style/NumericPredicate
      end
    end
  end

  def setup_typos
    return [] if @changed_files.empty?
    # Exclude the typos file itself
    shell_files = Shellwords.join(@changed_files - ['typos'])
    # If only typos was modified, bail out immediately
    return [] if shell_files.empty?
    desc "Check common typos from /typos"
    task :typos do
      system("git grep -I -n -P -f typos -- #{shell_files}")
      case $CHILD_STATUS.exitstatus
      when 0
        fail "Typo found!".red
      when 1
        puts "No typo found.".green
      else
        fail "Some error occurred".red
      end
    end
    [:typos]
  end

  def setup_syntax
    # Reset puppet-syntax tasks, define a new one
    Rake::Task[:syntax].clear
    namespace :syntax do
      Rake::Task[:manifests].clear
      Rake::Task[:hiera].clear
      Rake::Task[:templates].clear
    end
    if Puppet.version.to_f < 4.0
      PuppetSyntax.exclude_paths = [
        'modules/stdlib/types/*.pp',
        'modules/stdlib/types/compat/*.pp',
        'modules/stdlib/spec/fixtures/test/manifests/*.pp',
      ]
      PuppetSyntax.future_parser = true
    end
    # Set up filelists
    PuppetSyntax.manifests_paths = puppet_changed_files
    PuppetSyntax.templates_paths = filter_files_by("**/templates/**.erb", "**/templates/**.epp")
    PuppetSyntax.hieradata_paths = filter_files_by("hieradata/**.yaml", "conftool-data/**.yaml")
    tasks = []
    unless PuppetSyntax.manifests_paths.empty?
      tasks << 'syntax:manifests'
    end
    unless PuppetSyntax.templates_paths.empty?
      tasks << 'syntax:templates'
    end
    unless PuppetSyntax.hieradata_paths.empty?
      tasks << 'syntax:hiera'
    end
    return tasks if tasks.empty?
    # Now re-set up the jobs by instantiating the class
    PuppetSyntax::RakeTask.new
    # The jobs we select here need to be run in sequence for some thread-safety reasons
    task :syntax_all => tasks
    [:syntax_all]
  end

  def setup_rubocop
    # Files that require a full tree compilation.
    # If the gemfile changed, we might have updated rubocop.
    # Err on the side of caution and scan all files in that case.
    # Also, if the rubocop exceptions changed, check the whole tree
    # .ruby-version is for rbenv but is also used by rubocop to override the
    # ruby version to use when parsing files (T250538).
    global_files = ['Gemfile', '.rubocop.todo.yml', '.ruby-version']
    ruby_files = filter_files_by("**/*.rb", "**/Rakefile", 'Rakefile', 'Gemfile', '**/.rubocop.todo.yml', '.ruby-version')
    return [] if ruby_files.empty?
    RuboCop::RakeTask.new(:rubocop) do |r|
        r.options = ['--force-exclusion', '--color']
        if @changed_files.select{ |f| global_files.include?f }.empty?
          r.patterns = ruby_files
        end
    end

    [:rubocop]
  end

  def setup_python_extensions
    # Ensure python files have the correct extension so they are picked up by tox
    source_files = filter_files_by("**/files/**")
    return [] if source_files.empty?
    desc 'Ensure python files have a .py extensions so they can be checked'
    task :python_extensions do
      failures = false
      source_files.each do |source_file|
        # We don't need to perform CI on user files as such we skip them
        next if source_file.end_with?('.py') || source_file.start_with?('modules/admin/files/home')
        # skip zero byte files
        next if File.zero?(source_file)
        shebang = File.open(source_file) {|f| f.readline}
        # If the first line is not correctly encoded its likely a binary file
        next unless shebang.valid_encoding?
        mime_type = `file --mime-type -b '#{source_file}'`.chomp
        if shebang =~ /^#!.*python/ || mime_type == 'text/x-python'
          failures = true
          $stderr.puts "#{source_file} have been recognized as a Python source file, hence MUST have a '.py' file extension".red
        end
      end
      abort("python_extensions: FAILED".red) if failures
      puts "python_extensions: OK".green
    end
    [:python_extensions]
  end

  def setup_common_yaml
    # ensure the common.yaml file has no qualified variables in it
    common_yaml_file = filter_files_by("hieradata/common.yaml")
    return [] if common_yaml_file.empty?
    desc 'Check hieradata/common.yaml contains only unqualified names'
    task :common_yaml do
      failures = false
      common_yaml = YAML.safe_load(File.open(common_yaml_file[0]))
      common_yaml.each_key do |key|
        next unless key.include?('::')
        key_path = key.split('::')[0..-1].join('/')
        $stderr.puts "#{key} in hieradata/common.yaml is qualified".red
        $stderr.puts "\tIf this is for labs it should go in hieradata/labs.yaml".red
        $stderr.puts "\tIf this is for production it should go in common/#{key_path}.yaml".red
        failures = true
      end
      abort("hieradata/common.yaml: FAILED".red) if failures
      puts "hieradata/common.yaml: OK".green
    end
    [:common_yaml]
  end

  def setup_conftool_schema
    schema_files = filter_files_by("modules/profile/files/conftool/json-schema/**/*.schema")
    return [] if schema_files.empty?
    desc 'Check json schema files for conftool'
    failures = false
    task :conftool_schema do
      schema_files.each do |fn|
        begin
          JSON.parse(File.open(fn).read)
        rescue JSON::ParserError => e
          puts "Error parsing #{fn}".red
          puts e.message
          failures = true
        end
      end
      abort("JSON schema validation: FAILED".red) if failures
      puts "JSON schema validation: OK".green
    end
    [:conftool_schema]
  end

  def setup_spec
    # Modules known not to pass tests
    ignored_modules = ['mysql', 'osm', 'puppetdbquery', 'stdlib', 'lvm']

    deps = SpecDependencies.new
    spec_modules = deps.specs_to_run(@changed_files).select do |m|
      !ignored_modules.include?(m)
    end
    return [] if spec_modules.empty?

    namespace :spec do
      spec_modules.each do |module_name|
        desc "Run spec for module #{module_name}"
        task module_name do
          puts "---> spec:#{module_name}"
          spec_result = system("cd 'modules/#{module_name}' && rake spec")
          unless spec_result
            @failed_specs << module_name
          end
          puts "---> spec:#{module_name}"
        end
      end
    end
    desc "Run spec tests found in modules"
    multitask :spec => spec_modules.map{ |m| "spec:#{m}" } do
      raise "Modules that failed to pass the spec tests: #{@failed_specs.join ', '}".red unless @failed_specs.empty?
    end
    [:spec]
  end

  def setup_per_module_tox
    tasks = []
    namespace :tox do
      # first let's select only the python files
      python_files = filter_files_by('**/*.py')
      return tasks if python_files.empty?
      deps = SpecDependencies.new
      deps.tox_to_run(python_files).each do |module_name|
        test_name = "tox:#{module_name}"
        # Test already added
        next if tasks.include? test_name
        tasks << test_name
        desc "Run tox in module #{module_name}"
        task module_name do
          tox_ini = "modules/#{module_name}/tox.ini"
          if @changed_files.include?(tox_ini)
            raise "Running tox in #{module_name} failed".red unless system("tox -r -c #{tox_ini}")
          else
            raise "Running tox in #{module_name} failed".red unless system("tox -c #{tox_ini}")
          end
        end
      end
    end
    tasks
  end

  def setup_tox
    tasks = []
    namespace :tox do
      if @changed_files.include?('tox.ini')
        py_files = sort_python_files(Dir.glob('**/*.py'))
        ENV['TOX_PY2_FILES'] = py_files[:py2].join(' ')
        ENV['TOX_PY3_FILES'] = py_files[:py3].join(' ')
        desc 'Refresh the tox environment'
        task :update do
          raise "Running tox failed" unless system('tox -r')
        end
        tasks << 'tox:update'
      else
        admin_data_files = filter_files_by('modules/admin/data/**')
        unless admin_data_files.empty?
          desc 'Run tox for the admin data file'
          task :admin do
            res = system('tox -e admin')
            raise "Tox tests for admin/data/data.yaml failed!".red unless res
          end
          tasks << 'tox:admin'
        end
        mtail_files = filter_files_by("modules/mtail/files/**")
        unless mtail_files.empty?
          desc 'Run tox for mtail'
          task :mtail do
            res = system("tox -e mtail")
            raise 'Tests for mtail failed!'.red unless res
          end
          tasks << 'tox:mtail'
        end
        tslua_files = filter_files_by("modules/profile/files/trafficserver/**")
        unless tslua_files.empty?
          desc 'Run tox for tslua'
          task :tslua do
            res = system("tox -e tslua")
            raise 'Tests for tslua failed!'.red unless res
          end
          tasks << 'tox:tslua'
        end
        nagios_common_files = filter_files_by("modules/nagios_common/files/check_commands/**")
        unless nagios_common_files.empty?
          desc 'Run tox for nagios_common'
          task :nagios_common do
            res = system("tox -e nagios_common")
            raise 'Tests for nagios_common failed!'.red unless res
          end
          tasks << 'tox:nagios_common'
        end
        grafana_files = filter_files_by("modules/grafana/files/**")
        unless grafana_files.empty?
          desc 'Run tox for grafana'
          task :grafana do
            res = system("tox -e grafana")
            raise 'Tests for grafana failed!'.red unless res
          end
          tasks << 'tox:grafana'
        end
        sonofgridengine_files = filter_files_by("modules/sonofgridengine/files/**")
        unless sonofgridengine_files.empty?
          desc 'Run tox for sonofgridengine'
          task :sonofgridengine do
            res = system("tox -e sonofgridengine")
            raise 'Tests for sonofgridengine failed!'.red unless res
          end
          tasks << 'tox:sonofgridengine'
        end
        smart_data_dump_files = filter_files_by("modules/smart/files/**")
        unless smart_data_dump_files.empty?
          desc 'Run tox for smart_data_dump'
          task :smart_data_dump do
            res = system("tox -e smart_data_dump")
            raise 'Tests for smart_data_dump failed!'.red unless res
          end
          tasks << 'tox:smart_data_dump'
        end
        # Get all python files that don't have a tox.ini in their module
        py_files = sort_python_files(filter_files_by("*.py"))

        unless py_files[:py2].empty?
          desc 'Run flake8 on python2 files via tox'
          task :flake8 do
            shell_python2_files = Shellwords.join(py_files[:py2])
            raise "Flake8 failed".red unless system("tox -e py2-pep8 #{shell_python2_files}")
          end
          tasks << 'tox:flake8'
        end

        unless py_files[:py3].empty?
          desc 'Run flake8 on python3 files via tox'
          task :flake8_3 do
            shell_python3_files = Shellwords.join(py_files[:py3])
            raise "Flake8 failed" unless system("tox -e py3-pep8 #{shell_python3_files}")
          end
          tasks << 'tox:flake8_3'
        end

        # commit message
        desc 'Check commit message'
        task :commit_message do
          raise 'Invalid commit message'.red unless system("tox -e commit-message")
        end
        tasks << 'tox:commit_message'
      end
    end

    desc 'Run all the tox-related tasks'
    task :tox => tasks
    [:tox]
  end
end
