# encoding: UTF-8
# Junegunn Choi (junegunn.c@gmail.com)

module JDBCHelper
# Shortcut connector for Oracle
module OracleConnector
	include Constants
	include Constants::Connector

	def self.connect(host, user, password, service_name, timeout = DEFAULT_LOGIN_TIMEOUT)
		Connection.new(
			:driver   => JDBC_DRIVER[:oracle],
			:url      => "jdbc:oracle:thin:@#{host}/#{service_name}",
			:user     => user,
			:password => password,
			:timeout  => timeout)
	end

	def self.connect_by_sid(host, user, password, sid, timeout = DEFAULT_LOGIN_TIMEOUT)
		Connection.new(
			:driver   => JDBC_DRIVER[:oracle],
			:url      => "jdbc:oracle:thin:@#{host}:#{sid}",
			:user     => user,
			:password => password,
			:timeout  => timeout)
	end
end#OracleConnector
end#JDBCHelper
