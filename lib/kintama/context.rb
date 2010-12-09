module Kintama
  class Context
    include Aliases::Context

    attr_reader :name

    def initialize(name, parent=nil, &block)
      @name = name
      @subcontexts = {}
      @tests = {}
      @parent = parent
      @parent.add_subcontext(self) if @parent
      @modules = []
      instance_eval(&block)
    end

    def full_name
      if @name
        [@parent ? @parent.full_name : nil, @name].compact.join(" ")
      else
        nil
      end
    end

    def run(runner=nil)
      runner.context_started(self) if runner
      all_tests.each { |t| t.run(runner) }
      subcontexts.each { |s| s.run(runner) }
      runner.context_finished(self) if runner
      passed?
    end

    def add_subcontext(subcontext)
      @subcontexts[subcontext.name] = subcontext
      @subcontexts[methodize(subcontext.name)] = subcontext
    end

    def setup(&setup_block)
      @setup_block = setup_block
    end

    def run_setups(environment)
      @parent.run_setups(environment) if @parent
      include_modules(environment)
      environment.instance_eval(&@setup_block) if @setup_block
    end

    def teardown(&teardown_block)
      @teardown_block = teardown_block
    end

    def run_teardowns(environment)
      environment.instance_eval(&@teardown_block) if @teardown_block
      @parent.run_teardowns(environment) if @parent
    end

    def should(name, &block)
      add_test("should " + name, &block)
    end

    def it(name, &block)
      add_test("it " + name, &block)
    end

    def test(name, &block)
      add_test(name, &block)
    end

    def passed?
      failures.empty?
    end

    def failures
      all_tests.select { |t| !t.passed? } + subcontexts.map { |s| s.failures }.flatten
    end

    def include(mod=nil, &block)
      if mod.nil?
        mod = Module.new
        mod.class_eval(&block)
      end
      @modules << mod
    end

    def helpers(&block)
      mod = Module.new
      mod.class_eval(&block)
      @modules << mod
    end

    def include_modules(environment)
      @modules.each { |mod| environment.extend(mod) }
    end

    def [](name)
      @subcontexts[name] || @tests[name]
    end

    def method_missing(name, *args, &block)
      if @subcontexts[name]
        @subcontexts[name]
      elsif @tests[name]
        @tests[name]
      else
        begin
          super
        rescue NoMethodError => e
          if @parent
            @parent.send(name, *args, &block)
          else
            raise e
          end
        end
      end
    end

    def respond_to?(name)
      @subcontexts[name] != nil || 
      @tests[name] != nil || 
      super ||
      (@parent ? @parent.respond_to?(name) : false)
    end

    def inspect
      test_names = all_tests.map { |t| t.name }
      context_names = subcontexts.map { |c| c.name }
      "<Context:#{@name.inspect} @tests=#{test_names.inspect} @subcontexts=#{context_names.inspect}>"
    end

    def subcontexts
      @subcontexts.values.uniq.sort_by { |c| c.name }
    end

    private

    def add_test(name, &block)
      test = Test.new(name, self, &block)
      @tests[methodize(name)] = test
      @tests[name] = test
    end

    def methodize(name)
      name.gsub(" ", "_").to_sym
    end

    def all_tests
      @tests.values.uniq.sort_by { |t| t.name }
    end
  end
end