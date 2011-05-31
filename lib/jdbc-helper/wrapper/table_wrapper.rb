# encoding: UTF-8
# Junegunn Choi (junegunn.c@gmail.com)

module JDBCHelper
# A wrapper object representing a database table. Allows you to perform table operations easily.
# @since 0.2.0
# @example Usage
#  # For more complex examples, refer to test/test_object_wrapper.rb
#
#  # Creates a table wrapper
#  table = conn.table('test.data')
#
#  # Counting the records in the table
#  table.count
#  table.count(:a => 10)
#  table.where(:a => 10).count
#
#  table.empty?
#  table.where(:a => 10).empty?
#
#  # Selects the table by combining select, where, and order methods
#  table.select('a apple', :b).where(:c => (1..10)).order('b desc', 'a asc') do |row|
#    puts row.apple
#  end
#
#  # Updates with conditions
#  table.update(:a => 'hello', :b => JDBCHelper::SQL('now()'), :where => { :c => 3 })
#  # Or equivalently,
#  table.where(:c => 3).update(:a => 'hello', :b => JDBCHelper::SQL('now()'))
#
#  # Insert into the table
#  table.insert(:a => 10, :b => 20, :c => JDBCHelper::SQL('10 + 20'))
#  table.insert_ignore(:a => 10, :b => 20, :c => 30)
#  table.replace(:a => 10, :b => 20, :c => 30)
#
#  # Delete with conditions
#  table.delete(:c => 3)
#  # Or equivalently,
#  table.where(:c => 3).delete
#
#  # Truncate or drop table (Cannot be undone)
#  table.truncate_table!
#  table.drop_table!
class TableWrapper < ObjectWrapper
	# Returns the name of the table
	# @return [String]
	alias to_s name

	# Retrieves the count of the table
	# @param [List of Hash/String] where Filter conditions
	# @return [Fixnum] Count of the records.
	def count *where
		@connection.query(JDBCHelper::SQL.count name, where.empty? ? @query_where : where)[0][0].to_i
	end

	# Sees if the table is empty
	# @param [Hash/String] Filter conditions
	# @return [boolean]
	def empty? *where
		count(*where) == 0
	end

	# Inserts a record into the table with the given hash
	# @param [Hash] data_hash Column values in Hash
	# @return [Fixnum] Number of affected records
	def insert data_hash
		@connection.send @update_method, JDBCHelper::SQL.insert(name, data_hash)
	end

	# Inserts a record into the table with the given hash.
	# Skip insertion when duplicate record is found.
	# @note This is not SQL standard. Only works if the database supports insert ignore syntax.
	# @param [Hash] data_hash Column values in Hash
	# @return [Fixnum] Number of affected records
	def insert_ignore data_hash
		@connection.send @update_method, JDBCHelper::SQL.insert_ignore(name, data_hash)
	end

	# Replaces a record in the table with the new one with the same unique key.
	# @note This is not SQL standard. Only works if the database supports replace syntax.
	# @param [Hash] data_hash Column values in Hash
	# @return [Fixnum] Number of affected records
	def replace data_hash
		@connection.send @update_method, JDBCHelper::SQL.replace(name, data_hash)
	end

	# Executes update with the given hash.
	# :where element of the hash is taken out to generate where clause of the update SQL.
	# @param [Hash] data_hash_with_where Column values in Hash.
	#   :where element of the given hash can (usually should) point to another Hash representing update filters.
	# @return [Fixnum] Number of affected records
	def update data_hash_with_where
		where = data_hash_with_where.delete(:where) || @query_where
		@connection.send @update_method, JDBCHelper::SQL.update(name, data_hash_with_where, where)
	end

	# Deletes records matching given condtion
	# @param [List of Hash/String] where Delete filters
	# @return [Fixnum] Number of affected records
	def delete *where
		@connection.send @update_method, JDBCHelper::SQL.delete(name, where.empty? ? @query_where : where)
	end

	# Empties the table.
	# @note This operation cannot be undone
	# @return [Fixnum] executeUpdate return value
	def truncate_table!
		@connection.update(JDBCHelper::SQL.check "truncate table #{name}")
	end
	
	# Drops the table.
	# @note This operation cannot be undone
	# @return [Fixnum] executeUpdate return value
	def drop_table!
		@connection.update(JDBCHelper::SQL.check "drop table #{name}")
	end

	# Select SQL wrapper
	include Enumerable

	# Returns a new TableWrapper object which can be used to execute a select
	# statement for the table selecting only the specified fields.
	# If a block is given, executes the select statement and yields each row to the block.
	# @return [*String/*Symbol] List of fields to select
	# @return [JDBCHelper::TableWrapper]
	# @since 0.4.0
	def select *fields, &block
		obj = self.dup
		obj.instance_variable_set :@query_select, fields unless fields.empty?
		ret obj, &block
	end

	# Returns a new TableWrapper object which can be used to execute a select
	# statement for the table with the specified filter conditions.
	# If a block is given, executes the select statement and yields each row to the block.
	# @param [Hash/String] Filter conditions
	# @return [JDBCHelper::TableWrapper]
	# @since 0.4.0
	def where *conditions, &block
		raise ArgumentError.new("Wrong number of arguments") if conditions.empty?

		obj = self.dup
		obj.instance_variable_set :@query_where, conditions
		ret obj, &block
	end

	# Returns a new TableWrapper object which can be used to execute a select
	# statement for the table with the given sorting criteria.
	# If a block is given, executes the select statement and yields each row to the block.
	# @param [*String/*Symbol] Sorting criteria
	# @return [JDBCHelper::TableWrapper]
	# @since 0.4.0
	def order *criteria, &block
		raise ArgumentError.new("Wrong number of arguments") if criteria.empty?
		obj = self.dup
		obj.instance_variable_set :@query_order, criteria
		ret obj, &block
	end

	# Executes a select SQL for the table and returns an Enumerable object,
	# or yields each row if block is given.
	# @return [JDBCHelper::Connection::ResultSetEnumerator]
	# @since 0.4.0
	def each &block
		@connection.enumerate sql, &block
	end

	# Returns a new TableWrapper object whose subsequent inserts, updates,
	# and deletes are added to batch for JDBC batch-execution. The actual execution
	# is deferred until JDBCHelper::Connection#execute_batch method is called.
	# Self is returned when batch is called more than once.
	# @return [JDBCHelper::Connection::ResultSetEnumerator]
	# @since 0.4.0
	def batch
		if batch?
			self
		else
			obj = self.dup
			obj.instance_variable_set :@update_method, :add_batch
			obj
		end
	end

	# Returns if the subsequent updates for this wrapper will be batched
	# @return [Boolean]
	# @since 0.4.0
	def batch?
		@update_method == :add_batch
	end

	# Returns the select SQL for this wrapper object
	# @return [String] Select SQL
	# @since 0.4.0
	def sql
		JDBCHelper::SQL.select(
				name, 
				:select => @query_select, 
				:where => @query_where,
				:order => @query_order)
	end

	def initialize connection, table_name
		super connection, table_name
		@update_method = :update
	end
private
	def ret obj, &block
		if block_given?
			obj.each &block
		else
			obj
		end
	end
end#TableWrapper
end#JDBCHelper

