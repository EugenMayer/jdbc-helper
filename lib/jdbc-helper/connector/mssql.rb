# encoding: UTF-8
# Junegunn Choi (junegunn.c@gmail.com)

module JDBCHelper
# Shortcut connector for MS SQL Server
module MSSQL
  extend Connector

  # @param [String] host
  # @param [String] user
  # @param [String] password
  # @param [String] db
  # @param [Hash] extra_params
  # @return [JDBCHelper::Connection]
  def self.connect(host, user, password, db, extra_params = {}, &block)
    connect_impl :sqlserver, {
      :url      => "jdbc:sqlserver://#{host};databaseName=#{db};",
      :user     => user,
      :password => password
    }, extra_params, &block
  end
end#SqlServer

# Alias
SqlServer = MSSQL

# Backward-compatibility
# @deprecated
module SqlServerConnector
  extend Connector
  def self.connect(host, user, password, db,
           timeout = Constants::DEFAULT_LOGIN_TIMEOUT,
           extra_params = {}, &block)
    check_params extra_params
    MSSQL.connect(host, user, password, db,
                  {:timeout => timeout}.merge(extra_params), &block)
  end
end
end#JDBCHelper

