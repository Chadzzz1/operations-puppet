# normalize_level.rb
# Logstash Ruby script to build an ECS `log` field from level and syslog fields

def register(*)
  # RFC5424 severity to supported level field mapping
  # see get_severity() below
  @severity_map = {
    "emergency" => {
      :aliases => ["emerg", "fatal"],
      :code => 0
    },
    "alert" => {
      :aliases => [],
      :code => 1
    },
    "critical" => {
      :aliases => ["crit"],
      :code => 2
    },
    "error" => {
      :aliases => ["err"],
      :code => 3
    },
    "warning" => {
      :aliases => ["warn"],
      :code => 4
    },
    "notice" => {
      :aliases => [],
      :code => 5
    },
    "informational" => {
      :aliases => ["info"],
      :code => 6
    },
    "debug" => {
      :aliases => ["trace"],
      :code => 7
    },
  }
end

def get_facility(field)
  # Returns normalized facility field
  unless field.nil?
    if field[-1].match?(/[0-7]/)
      return field.downcase, field[-1].to_i + 16
    end
  end
  ["local7", 23]
end

def get_severity(field)
  # Returns normalized severity field
  # Defaults to alert because this severity level is seldom hit.
  # Mismatches between `log.syslog.severity` and `log.level` should be addressed
  # Default ["alert", 1]
  unless field.nil?
    field = field.downcase
    @severity_map.each do |k, v|
      if (v[:aliases] + [k]).include?(field)
        return k, v[:code]
      end
    end
  end
  ["alert", 1]
end

def get_level(event)
  # Returns normalized level field.
  # dependent on the availability of either `event.level` or `event.severity`
  if event.get('level').nil?
    if event.get('severity').nil?
      return "NOTSET"
    else
      return event.get('severity').upcase
    end
  end
  event.get('level').upcase
end

def filter(event)
  # Builds the ECS `log` field based on event `level` and `severity`
  # https://doc.wikimedia.org/ecs/#ecs-log

  # Assume ECS compliant if 'log' is a hash.
  unless event.get('log').instance_of?(Hash)
    level = get_level(event)
    severity_name, severity_code = get_severity(level)
    facility_name, facility_code = get_facility(event.get('facility'))

    event.set('log', {
      :level => level,
      :syslog => {
        :severity => {
          :code => severity_code,
          :name => severity_name
        },
        :facility => {
          :code => facility_code,
          :name => facility_name
        },
        :priority => (facility_code * 8 + severity_code) # RFC5424 (6.2.1)
      }
    })

    # Clean up migrated fields
    event.remove('severity')
    event.remove('level')
    event.remove('facility')
  end
  [event]
end
