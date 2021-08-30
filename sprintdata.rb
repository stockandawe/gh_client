#!/usr/bin/env ruby
require 'rubygems'
require 'bundler/setup'
require 'octokit'
require 'optparse'
require 'optimist'
require 'csv'
require 'zenhub_ruby'

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

def default_report(opts, gh_client)
  issues_1 = normalize_issues(
    gh_client.issues opts[:repo],
                  labels: opts[:labels],
                  state: opts[:state],
                  since: "#{opts[:start_date]}T00:00:00Z",
                  direction: "asc"
  )

  issues_2 = normalize_issues(
    gh_client.issues "himaxwell/maxwell",
                  labels: opts[:labels],
                  state: opts[:state],
                  since: "#{opts[:end_date]}T00:00:00Z",
                  direction: "asc"
  )

  issues = issues_1 - issues_2

  puts "#{issues.count} (#{opts[:state]}) issues tagged with #{opts[:labels]} between #{opts[:start_date]} and #{opts[:end_date]}"

  write_to_csv(issues) if opts[:csv]
end

def team_report(opts, gh_client, zh_client)
  puts "Running team report for " + opts[:team]
  supported_teams = ['mls','lender','manager','borrower']
  unless supported_teams.include? opts[:team].downcase
    puts opts[:team] + " is not a team I know about"
    exit
  end

  milestones = fetch_milestones_for_team(opts[:team], gh_client)

  sprintdata = compile_sprintdata(milestones, gh_client)

  pp sprintdata


  # fetch estimates from zenhub

  #compile report: 
  # Milestone:
  #   velocity (total points completed)
  #   bugs
  #   features
  #   tasks
  #   qa
  #   post planning
  #   carryover
end

def compile_sprintdata(milestones, gh_client)
  # fetch data from github for all issues in the milestones
  sprintdata = {}
  milestones.each do |m|
    sprintdata["#{m[:number]}"] = {}
    sprintdata["#{m[:number]}"][:title] = m[:title]
    sprintdata["#{m[:number]}"][:due_on] = m[:due_on]
    sprintdata["#{m[:number]}"][:issues] = fetch_issues_for_milestone(m[:title], gh_client)
  end
  sprintdata
end

def fetch_milestones_for_team(team, gh_client)
  gh_client.
    milestones('himaxwell/maxwell', state:'all', per_page:100, direction:'desc').
    select {|m| m.title.match(/#{team}/i)}
end

def fetch_issues_for_milestone(milestone_title, gh_client)
  issues = gh_client.search_issues('is:issue milestone:"' + milestone_title + '"', {repo: 'himaxwell/maxwell'})
  issues_w_selected_attr = {}
  issues.items.each do |i|
    issues_w_selected_attr[i.number] = {}
    issues_w_selected_attr[i.number][:number] = i.number
    issues_w_selected_attr[i.number][:title] = i[:title]
    issues_w_selected_attr[i.number][:html_url] = i[:html_url]
    issues_w_selected_attr[i.number][:labels] = i[:labels].map {|l| l.name}
  end
  issues_w_selected_attr
end

if ENV["GITHUB_PAT"].nil? || ENV["ZENHUB_PAT"].nil?
  puts "Please configure your Github and Zenhub Private Access Tokens in GITHUB_PAT and ZENHUB_PAT env varilables"
  exit
end

opts = Optimist::options do
  opt :repo, "Specify GitHub repo. E.g. 'stockandawe/gh_client'", type: :string
  opt :labels, "Specify a list of comma separated label names. E.g. 'Bug,Internal'", :type => :string, :default => "Bug"
  opt :state, "Specify state of the issue. Can be either 'open', 'closed', or 'all'", :type => :string, :default => "open"
  opt :start_date, "Specify the start date YYYY-MM-DD format", :type => :string, :default => "#{Time.now.year}-#{Time.now.month}-1"
  opt :end_date, "Specify the end date YYYY-MM-DD format", :type => :string, :default => "#{Time.now.year}-#{Time.now.month}-#{Time.now.day}"
  opt :csv, "Set as true a csv output", :type => :boolean, :default => false
  opt :team, "Run an analysis reeport for the specified team", type: :string
end

if opts[:repo].nil?
  exec "bundle exec ruby #{__FILE__} -h"
  exit
end

gh_client = Octokit::Client.new(access_token: ENV["GITHUB_PAT"], per_page: 100)
gh_client.auto_paginate = true

zh_client = ZenhubRuby.new(ENV["ZENHUB_PAT"], ENV["GITHUB_PAT"])

if opts[:team].nil? then default_report(opts, gh_client)
else team_report(opts, gh_client, zh_client)


end

