#!/usr/bin/env ruby
require 'rubygems'
require 'bundler/setup'
require 'octokit'
require 'optparse'
require 'optimist'
require 'csv'
require 'date'

def write_to_csv(issues)
  file = "gh_client_#{Time.now}.csv"
  CSV.open(file, "w", :write_headers=> true, :headers => %w[ID Title URL Labels Created Updated Closed]) do |writer|
    issues.each do |issue|
      labels = []
      issue.labels.each do |label|
        labels << label.name
      end
      row = [issue.id.to_s,
             issue.title,
             issue.url,
             labels.join('|'),
             issue.created_at&.strftime("%F %T"),
             issue.updated_at&.strftime("%F %T"),
             issue.closed_at&.strftime("%F %T")
      ]
      writer << row
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
  opt :labels, "Specify a list of comma separated label names. E.g. 'Bug,Internal'", :type => :string, :default => nil
  opt :omit_labels, "Specify a list of comma separated label names to exclude. E.g. 'Epic,Chore'", :type => :string, :default => nil
  opt :event, "Specify the event that you want to track. Can be 'created', 'updated', or 'closed'", :type => :string, :default => "created"
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

excluded_labels = opts[:omit_labels].split(',') if opts[:omit_labels]

# make sure dates are formatted how GitHub API expects them
# i.e.  22-8-9 => 2022-08-09
start_date = Date.parse(opts[:start_date]).strftime("%Y-%m-%d")
end_date = Date.parse(opts[:end_date]).strftime("%Y-%m-%d")

puts "Fetching all issues from #{opts[:repo]}..."

# Fetch all issues (open and closed) with pagination
issues = client.issues(opts[:repo], state: 'all')

puts "Filtering issues based on criteria..."

# Filter by required labels if specified
if !opts[:labels].nil?
  required_labels = opts[:labels].split(',').map(&:strip)
  issues = issues.select do |issue|
    issue_label_names = issue.labels.map(&:name)
    required_labels.all? { |label| issue_label_names.include?(label) }
  end
end

# Filter by date range based on event type
start_date_parsed = Date.parse(start_date)
end_date_parsed = Date.parse(end_date)

issues = issues.select do |issue|
  event_date = case opts[:event]
                when 'created'
                  Date.parse(issue.created_at.to_s)
                when 'updated' 
                  Date.parse(issue.updated_at.to_s)
                when 'closed'
                  issue.closed_at ? Date.parse(issue.closed_at.to_s) : nil
                end
  
  event_date && event_date >= start_date_parsed && event_date <= end_date_parsed
end

# Sort issues by the event date
issues = issues.sort_by do |issue|
  case opts[:event]
  when 'created'
    issue.created_at
  when 'updated'
    issue.updated_at
  when 'closed'
    issue.closed_at || Time.at(0) # Handle nil closed_at by putting at beginning
  end
end

puts "Applied filters: event=#{opts[:event]}, date_range=#{start_date}..#{end_date}"
puts "Required labels: #{opts[:labels]}" if opts[:labels]
puts "Sorted by: #{opts[:event]} date (earliest first)"

unless excluded_labels.nil?
  puts "Excluding issues with labels: #{excluded_labels.join(', ')}"
  filtered_issues = issues.reject do |issue|
    issue.labels.any? { |label| excluded_labels.include?(label.name) }
  end
else
  filtered_issues = issues
end

message = "#{filtered_issues.count} issues "
message += "tagged with #{opts[:labels]} " if !opts[:labels].nil?
message += "were #{opts[:event]} between #{start_date} and #{end_date}"
puts message

write_to_csv(filtered_issues) if opts[:csv]
