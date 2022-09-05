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
      row = [issue.number.to_s,
             issue.title,
             issue.html_url,
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

# make sure dates are formatted how GitHub API expects them
# ex:  22-8-9 => 2022-08-09
# ex: 22-8-9T1:0:0-6 => 22-08-09T01:00:00-06:00
def parse_date(date_string)
  return DateTime.strptime(date_string,"%Y-%m-%d").strftime("%Y-%m-%d") if date_string.length < 10
  return DateTime.strptime(date_string,"%Y-%m-%dT%H:%M:%S%Z").strftime("%Y-%m-%dT%H:%M:%S%z")
end

def nearest_saturday_from_today
  sat = Time.now + ((6 - Time.now.wday)*24*60*60) #but still need midnightj
  return sat - (sat.hour * 3600) - (sat.min * 60) - (sat.sec)
end

def iso8601(time) # https://en.wikipedia.org/wiki/ISO_8601
  return time.strftime("%Y-%m-%dT%H:%M:%S%z")
end

def prep_query(event, labels, start_date, end_date)
  query = "repo:#{$opts[:repo]} is:issue "
  query += "label:\"#{labels}\" " if !labels.nil?
  query += "#{event}:#{start_date}..#{end_date}"

  puts "Github filter query used: " + query if $opts[:show_query]

  return query
end

def process_query(event, labels, start_date, end_date)
  issues =  $client.search_issues prep_query(event, labels, start_date, end_date)

  message = "#{issues.total_count} issues "
  message += "tagged with #{labels} " if !labels.nil?
  message += "were #{event} between #{start_date} and #{end_date}"
  puts message
  write_to_csv(issues.items) if $opts[:csv]
end

def weekly_summary_report
  datelist = []
  $opts[:weekly].times {|i| datelist << iso8601(nearest_saturday_from_today - (i*7*24*3600))}
  datelist.reverse!
  puts "start_date, end_date, bugs_created, bugs_closed, cs_created, cs_closed"

  datelist.each_with_index do |date,i|
    start_date = date 
    end_date = datelist[i+1]
    bugs_created = $client.search_issues(prep_query('created','Bug', date, datelist[i+1])).total_count
    bugs_closed =  $client.search_issues(prep_query('closed','Bug', date, datelist[i+1])).total_count
    cs_created =   $client.search_issues(prep_query('created','Customer Support', date, datelist[i+1])).total_count
    cs_closed =    $client.search_issues(prep_query('closed','Customer Support', date, datelist[i+1])).total_count
    puts "#{start_date},#{end_date},#{bugs_created},#{bugs_closed},#{cs_created},#{cs_closed}"
    sleep(1)
  end

  exit

end

if ENV["GITHUB_PAT"].empty?
  puts "Please configure your Private Access Token in GITHUB_PAT env varilable"
  exit
end

opts = Optimist::options do
  opt :repo, "Specify GitHub repo. E.g. 'stockandawe/gh_client'", type: :string
  opt :labels, "Specify a list of comma separated label names. E.g. 'Bug,Internal'", :type => :string, :default => nil
  opt :event, "Specify the event that you want to track. Can be 'created', 'updated', or 'closed'", :type => :string, :default => "created"
  opt :start_date, "Specify the start date YYYY-MM-DD format", :type => :string, :default => "#{Time.now.year}-#{Time.now.month}-1"
  opt :end_date, "Specify the end date YYYY-MM-DD format", :type => :string, :default => "#{Time.now.year}-#{Time.now.month}-#{Time.now.day}"
  opt :csv, "Set as true a csv output", :type => :boolean, :default => false
  opt :weekly, "run reports for the weekly email", :type => :int, :default => nil
  opt :show_query, "Show the Github query used", :type => :boolean, :default => false
end

if opts[:repo].nil?
  exec "bundle exec ruby #{__FILE__} -h"
  exit
end

$opts = opts

$client = Octokit::Client.new(access_token: ENV["GITHUB_PAT"], per_page: 100)
$client.auto_paginate = true

if opts[:weekly]
  weekly_summary_report
else
  start_date = parse_date(opts[:start_date]) 
  end_date   = parse_date(opts[:end_date])
  process_query(opts[:event], opts[:labels], start_date, end_date)
end





