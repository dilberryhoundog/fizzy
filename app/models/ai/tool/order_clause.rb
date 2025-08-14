class Ai::Tool::OrderClause
  ALLOWED_DIRECTIONS = %i[ asc desc ].freeze

  attr_reader :order, :defaults
  attr_accessor :permitted_columns

  def self.parse(value, **options)
    new(nil, **options).tap do |order_clause|
      if value
        value.split(",").each do |clause|
          column, direction = clause.split(" ", 2).map(&:strip)
          order_clause.add(column, direction)
        end
      end
    end
  end

  def initialize(order = nil, defaults: nil, permitted_columns: nil)
    @order = order || {}
    @defaults = defaults || {}
    @permitted_columns = permitted_columns || []
  end

  def add(column, direction)
    order[column] = sanitize_direction(direction)
  end

  def defaults=(hash)
    @defaults = hash.transform_values(&method(:sanitize_direction))
  end

  def to_h
    hash = order.with_indifferent_access

    defaults.each do |key, value|
      hash[key] = value unless hash.key?(key)
    end

    hash.slice(*permitted_columns)
  end

  private
    def sanitize_direction(direction)
      direction = direction&.downcase&.to_sym

      unless ALLOWED_DIRECTIONS.include?(direction)
        raise ArgumentError, "Invalid direction"
      else
        direction
      end
    end
end
