#!/usr/bin/env ruby
require 'rubygems'
require 'bundler/setup'
require 'octokit'
require 'optparse'
require 'optimist'
require 'csv'

def write_to_csv(issues)
  file = "gh_client_#{Time.now}.csv"
  CSV.open(file, "w", :write_headers=> true, :headers => %w[ID Title URL Labels Created Updated Closed]) do |writer|
    issues.each do |issue|
      writer << issue
    end
  end

  puts "Wrote to #{file}"
end

def normalize_issues(issues)
  issues.map do |issue|
    [
      issue.number,
      issue.title,
      issue.html_url,
      issue.labels.map{|label| label.name},
      issue.created_at,
      issue.updated_at,
      issue.closed_at
    ]
  end
end

if ENV["GITHUB_PAT"].empty?
  puts "Please configure your Private Access Token in GITHUB_PAT env varilable"
  exit
end

opts = Optimist::options do
  opt :repo, "Specify GitHub repo. E.g. 'stockandawe/gh_client'", type: :string
  opt :labels, "Specify a list of comma separated label names. E.g. 'Bug,Internal'", :type => :string, :default => "Bug"
  opt :event, "Specify of the event that you want to track. Can be either 'created' or 'closed'", :type => :string, :default => "created"
  opt :start_date, "Specify the start date YYYY-MM-DD format", :type => :string, :default => "#{Time.now.year}-#{Time.now.month}-1"
  opt :end_date, "Specify the end date YYYY-MM-DD format", :type => :string, :default => "#{Time.now.year}-#{Time.now.month}-#{Time.now.day}"
  opt :csv, "Set as true a csv output", :type => :boolean, :default => false
end

if opts[:repo].nil?
  exec "bundle exec ruby #{__FILE__} -h"
  exit
end

client = Octokit::Client.new(access_token: ENV["GITHUB_PAT"], per_page: 100)
client.auto_paginate = true

#https://github.com/himaxwell/maxwell/issues?q=is%3Aissue+label%3A%22Bug%22+created%3A2022-01-14..2022-01-21+
query = "repo:#{opts[:repo]} is:issue label:#{opts[:labels]} #{opts[:event]}:#{opts[:start_date]}..#{opts[:end_date]}"

puts "Github filter query used: " + query

searched =  client.search_issues query

puts "#{searched.items.count} issues tagged with #{opts[:labels]} were #{opts[:event]} between #{opts[:start_date]} and #{opts[:end_date]}"

write_to_csv(issues) if opts[:csv]
