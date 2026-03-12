module Tasks
  class NinetyDayPlanSeeder
    TaskDefinition = Struct.new(:title, :description, :range, :status, :dependency, keyword_init: true)

    def initialize(company:, base_date: Date.current)
      @company = company
      @base_date = base_date
    end

    def call
      return if already_seeded?

      definitions.each do |definition|
        seed_task(definition)
      end
    end

    private

    attr_reader :company, :base_date

    def already_seeded?
      company.tasks.where('notes ILIKE ?', '%Seed: 90-day plan%').exists?
    end

    def seed_task(definition)
      notes = []
      notes << "Date range: #{definition.range.begin} to #{definition.range.end}"
      notes << "Dependency: #{definition.dependency}" if definition.dependency.present?
      notes << 'Seed: 90-day plan'

      task = company.tasks.find_or_initialize_by(title: definition.title, due_on: definition.range.begin)
      task.description = definition.description
      task.status = definition.status || 'todo'
      task.notes = notes.join("\n")
      task.save!
    end

    def range_from(start_offset, end_offset)
      (base_date + start_offset)..(base_date + end_offset)
    end

    def definitions
      week1 = range_from(0, 6)
      week2 = range_from(7, 13)
      week3 = range_from(14, 20)
      week4 = range_from(21, 27)
      week5 = range_from(28, 34)
      week6 = range_from(35, 41)
      week7 = range_from(42, 48)
      week8 = range_from(49, 55)
      week9 = range_from(56, 62)
      week10 = range_from(63, 69)
      week11 = range_from(70, 76)
      week12 = range_from(77, 83)
      week13 = range_from(84, 90)

      [
        TaskDefinition.new(
          title: 'Contractor contacted; shed walkthrough scheduled',
          description: 'Initial contractor contact completed; walkthrough scheduled.',
          range: range_from(0, 0),
          status: 'done'
        ),
        TaskDefinition.new(
          title: 'Contractor walkthrough (shed)',
          description: 'Complete on-site shed walkthrough with contractor.',
          range: range_from(0, 3)
        ),
        TaskDefinition.new(
          title: 'Reviews collected (initial)',
          description: '10+ Google reviews collected; additional requests in flight.',
          range: range_from(0, 0),
          status: 'done'
        ),
        TaskDefinition.new(
          title: 'Website redesigned and redeployed',
          description: 'Website redesign completed and live.',
          range: range_from(0, 0),
          status: 'done'
        ),
        TaskDefinition.new(
          title: 'Respond to all existing reviews',
          description: 'Reply to every current Google review.',
          range: week1
        ),
        TaskDefinition.new(
          title: 'Review request cadence (week 1)',
          description: 'Send 1–2 review requests.',
          range: week1
        ),
        TaskDefinition.new(
          title: 'Google Business Profile post (week 1)',
          description: 'Publish 1 GBP post.',
          range: week1
        ),
        TaskDefinition.new(
          title: 'Review request cadence (week 2)',
          description: 'Send 1–2 review requests.',
          range: week2
        ),
        TaskDefinition.new(
          title: 'Google Business Profile post (week 2)',
          description: 'Publish 1 GBP post.',
          range: week2
        ),
        TaskDefinition.new(
          title: 'Website: add trust signals',
          description: 'Add review count, testimonials, certifications, and insurance indicators to homepage.',
          range: range_from(2, 13)
        ),
        TaskDefinition.new(
          title: 'Website: clarify service areas',
          description: 'List explicit counties/cities served and any exclusions.',
          range: range_from(2, 13)
        ),
        TaskDefinition.new(
          title: 'Website: separate inquiry paths',
          description: 'Split long-term rental inquiry vs event rental inquiry with distinct CTAs.',
          range: range_from(2, 13)
        ),
        TaskDefinition.new(
          title: 'Receive written shed estimate',
          description: 'Obtain written estimate from contractor.',
          range: range_from(14, 24),
          dependency: 'Contractor walkthrough (shed)'
        ),
        TaskDefinition.new(
          title: 'Identify top 3 shed cost drivers',
          description: 'List and confirm the three biggest cost drivers in the estimate.',
          range: range_from(25, 31),
          dependency: 'Receive written shed estimate'
        ),
        TaskDefinition.new(
          title: 'Shed decision gate',
          description: 'Decision rule: ≤ $40k proceed; $40–45k cut scope then proceed; > $45k pause.',
          range: range_from(32, 34),
          dependency: 'Identify top 3 shed cost drivers'
        ),
        TaskDefinition.new(
          title: 'Add reviews to website homepage',
          description: 'Embed review snippets and/or Google review widget on homepage.',
          range: range_from(14, 24)
        ),
        TaskDefinition.new(
          title: 'Review request cadence (week 3)',
          description: 'Send 1–2 review requests.',
          range: week3
        ),
        TaskDefinition.new(
          title: 'Google Business Profile post (week 3)',
          description: 'Publish 1 GBP post.',
          range: week3
        ),
        TaskDefinition.new(
          title: 'Review request cadence (week 4)',
          description: 'Send 1–2 review requests.',
          range: week4
        ),
        TaskDefinition.new(
          title: 'Google Business Profile post (week 4)',
          description: 'Publish 1 GBP post.',
          range: week4
        ),
        TaskDefinition.new(
          title: 'Review request cadence (week 5)',
          description: 'Send 1–2 review requests.',
          range: week5
        ),
        TaskDefinition.new(
          title: 'Google Business Profile post (week 5)',
          description: 'Publish 1 GBP post.',
          range: week5
        ),
        TaskDefinition.new(
          title: 'Review request cadence (week 6)',
          description: 'Send 1–2 review requests.',
          range: week6
        ),
        TaskDefinition.new(
          title: 'Google Business Profile post (week 6)',
          description: 'Publish 1 GBP post.',
          range: week6
        ),
        TaskDefinition.new(
          title: 'Build outreach list',
          description: 'Compile contractors, parks, schools with contact info.',
          range: range_from(14, 27)
        ),
        TaskDefinition.new(
          title: 'Initial outreach: seasonal availability',
          description: 'Send initial outreach framed as locking in seasonal availability.',
          range: range_from(28, 41),
          dependency: 'Build outreach list'
        ),
        TaskDefinition.new(
          title: 'Log outreach responses and classify demand',
          description: 'Track responses and classify as hot/warm/cold or booked/likely/uncertain.',
          range: range_from(28, 41),
          dependency: 'Initial outreach: seasonal availability'
        ),
        TaskDefinition.new(
          title: 'Define conversion tracking fields',
          description: 'Define lead source, inquiry type (long-term/event), outcome, and conversion date.',
          range: range_from(21, 31)
        ),
        TaskDefinition.new(
          title: 'Define “too busy” thresholds',
          description: 'Set explicit thresholds for time-based, route-based, and asset-based constraints.',
          range: week7
        ),
        TaskDefinition.new(
          title: 'Track constraint type per week',
          description: 'Classify weekly constraints as time-based, route-based, or asset-based.',
          range: range_from(42, 69),
          dependency: 'Define “too busy” thresholds'
        ),
        TaskDefinition.new(
          title: 'Second driver readiness checkpoint',
          description: 'Assess demand and constraints against thresholds; decide yes/no to begin hiring search.',
          range: range_from(56, 58),
          dependency: 'Track constraint type per week'
        ),
        TaskDefinition.new(
          title: 'Second truck search readiness checkpoint',
          description: 'Assess demand and constraints; decide whether to begin truck search (search only).',
          range: range_from(63, 65),
          dependency: 'Track constraint type per week'
        ),
        TaskDefinition.new(
          title: 'Review request cadence (week 7)',
          description: 'Send 1–2 review requests.',
          range: week7
        ),
        TaskDefinition.new(
          title: 'Google Business Profile post (week 7)',
          description: 'Publish 1 GBP post.',
          range: week7
        ),
        TaskDefinition.new(
          title: 'Review request cadence (week 8)',
          description: 'Send 1–2 review requests.',
          range: week8
        ),
        TaskDefinition.new(
          title: 'Google Business Profile post (week 8)',
          description: 'Publish 1 GBP post.',
          range: week8
        ),
        TaskDefinition.new(
          title: 'Review request cadence (week 9)',
          description: 'Send 1–2 review requests.',
          range: week9
        ),
        TaskDefinition.new(
          title: 'Google Business Profile post (week 9)',
          description: 'Publish 1 GBP post.',
          range: week9
        ),
        TaskDefinition.new(
          title: 'Review request cadence (week 10)',
          description: 'Send 1–2 review requests.',
          range: week10
        ),
        TaskDefinition.new(
          title: 'Google Business Profile post (week 10)',
          description: 'Publish 1 GBP post.',
          range: week10
        ),
        TaskDefinition.new(
          title: 'Review request cadence (week 11)',
          description: 'Send 1–2 review requests.',
          range: week11
        ),
        TaskDefinition.new(
          title: 'Google Business Profile post (week 11)',
          description: 'Publish 1 GBP post.',
          range: week11
        ),
        TaskDefinition.new(
          title: 'Review request cadence (week 12)',
          description: 'Send 1–2 review requests.',
          range: week12
        ),
        TaskDefinition.new(
          title: 'Google Business Profile post (week 12)',
          description: 'Publish 1 GBP post.',
          range: week12
        ),
        TaskDefinition.new(
          title: 'Review request cadence (week 13)',
          description: 'Send 1–2 review requests.',
          range: week13
        ),
        TaskDefinition.new(
          title: 'Google Business Profile post (week 13)',
          description: 'Publish 1 GBP post.',
          range: week13
        ),
        TaskDefinition.new(
          title: 'Demand validation checkpoint',
          description: 'Review outreach responses and conversion tracking to validate demand before capital deployment.',
          range: range_from(84, 87),
          dependency: 'Log outreach responses and classify demand'
        )
      ]
    end
  end
end
