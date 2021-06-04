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
  opt :state, "Specify state of the issue. Can be either 'open', 'closed', or 'all'", :type => :string, :default => "open"
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

issues_1 = normalize_issues(
  client.issues opts[:repo],
                labels: opts[:labels],
                state: opts[:state],
                since: "#{opts[:start_date]}T00:00:00Z",
                direction: "asc"
)

issues_2 = normalize_issues(
  client.issues "himaxwell/maxwell",
                labels: opts[:labels],
                state: opts[:state],
                since: "#{opts[:end_date]}T00:00:00Z",
                direction: "asc"
)

issues = issues_1 - issues_2

puts "#{issues.count} (#{opts[:state]}) issues tagged with #{opts[:labels]} between #{opts[:start_date]} and #{opts[:end_date]}"

write_to_csv(issues) if opts[:csv]
