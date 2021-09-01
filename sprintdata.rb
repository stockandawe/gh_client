#!/usr/bin/env ruby
require 'rubygems'
require 'bundler/setup'
require 'octokit'
require 'optparse'
require 'optimist'
require 'csv'
require 'zenhub_ruby'


class SprintData 

  attr_accessor :gh_client, :zh_client, :opts, :milestones, :sprintdata

  def initialize(opts)
    @gh_client = Octokit::Client.new(access_token: ENV["GITHUB_PAT"], per_page: 100)
    gh_client.auto_paginate = true
    @zh_client = ZenhubRuby.new(ENV["ZENHUB_PAT"], ENV["GITHUB_PAT"])
    @opts = opts
    @milestones = fetch_milestones_for_team(opts[:team])
    @sprintdata = compile_sprintdata
  end

  def team_report
    puts "Running team report for " + opts[:team]
    supported_teams = ['mls','lender','manager','borrower']
    unless supported_teams.include? opts[:team].downcase
      puts opts[:team] + " is not a team I know about"
      exit
    end
    sprintdata

  end

  def compile_sprintdata
    # fetch data from github for all issues in the milestones
    sprintdata = {}
    milestones.each do |m|
      sprintdata["#{m[:number]}"] = {}
      sprintdata["#{m[:number]}"][:number] = m[:number]
      sprintdata["#{m[:number]}"][:title] = m[:title]
      sprintdata["#{m[:number]}"][:due_on] = m[:due_on]
      sprintdata["#{m[:number]}"][:issues] = fetch_issues_for_milestone(m[:title])
    end

    sprintdata.each do |k,m|
      #initiallize all the labels we want to track
      m[:velocity] = 0
      m[:bug_points] = 0
      m[:task_points] = 0 
      m[:qa_points] = 0 
      m[:feature_points] = 0
      m[:carryover] = 0
      m[:post_planning] = 0
      m[:frontend] = 0
      m[:backend] = 0

      m[:issues].each do |k,i|
        m[:velocity] += i[:estimate]
        #mutually exclusive Bugs, Features, Tasks, QA
        if i[:labels].include?("Bug") then m[:bug_points] += i[:estimate] 
          elsif i[:labels].include?("Task") then m[:task_points] += i[:estimate] 
          elsif i[:labels].include?("QA Task") then m[:qa_points] += i[:estimate] 
          else m[:feature_points] += i[:estimate]
        end
        m[:carryover] += i[:estimate] if i[:labels].include?("Carryover")
        m[:post_planning] += i[:estimate] if i[:labels].include?("Post Planning")
        m[:frontend] += i[:estimate] if i[:labels].include?("Frontend")
        m[:backend] += i[:estimate] if i[:labels].include?("Backend")
      end
    end
    sprintdata
  end

  def fetch_milestones_for_team(team)
    if opts[:test] == true 
    then 
      return gh_client.
        milestones(opts[:repo], state:'all', per_page:100, direction:'desc').
        select {|m| m.title.match(/iggy/i)}
    else 
      return gh_client.
        milestones(opts[:repo], state:'all', per_page:100, direction:'desc').
        select {|m| m.title.match(/#{team}/i)}
    end
  end

  def fetch_issues_for_milestone(milestone_title)
    puts "\n***************************\nfetching issues data for milestone: " + milestone_title
    issues = gh_client.search_issues('is:issue milestone:"' + milestone_title + '"', {repo: opts[:repo]})
    trim_issues = {}
    issues.items.each do |i|
      zhdata = fetch_zenhub_data(i.number)
      trim_issues[i.number] = {}
      trim_issues[i.number][:number] = i.number
      trim_issues[i.number][:title] = i[:title]
      trim_issues[i.number][:html_url] = i[:html_url]
      trim_issues[i.number][:labels] = i[:labels].map {|l| l.name}
      trim_issues[i.number][:estimate] = zhdata[:estimate].nil? ? 0 : zhdata[:estimate]
      trim_issues[i.number][:is_epic] = zhdata[:is_epic]
      trim_issues[i.number][:pipeline] = zhdata[:pipeline]
    end
    trim_issues
  end

  def fetch_zenhub_data(issue_number)
    puts "fetching zenhub data for issue: " + issue_number.to_s
    zh_data = zh_client.issue_data(opts[:repo],issue_number).body
    #only need a subset of this data
    ret = {}
    if zh_data.nil?
      ret[:estimate] = nil
      ret[:is_epic] = nil
      ret[:pipeline] = nil
    else
      ret[:estimate] = zh_data["estimate"].nil? ? nil : zh_data["estimate"]["value"]
      ret[:is_epic] = zh_data["is_epic"]
      ret[:pipeline] = zh_data["pipeline"]
    end
    ret
  end

  def write_to_csv
    write_data = sprintdata.map {|mkey,m| m.select {|k,v| k != :issues}}
    file = "sprintdata#{Time.now.to_s.gsub(' ','_')}.csv"
    CSV.open(file, "w", :write_headers=> true, :headers => %w[ID Title End Velocity Bugs Tasks QA Features Carryover Post_Planning Frontend Backend]) do |writer|
      write_data.each do |m|
        writer << m.values
      end
    end

    puts "Wrote to #{file}"
  end
end


if ENV["GITHUB_PAT"].nil? || ENV["ZENHUB_PAT"].nil?
  puts "Please configure your Github and Zenhub Private Access Tokens in GITHUB_PAT and ZENHUB_PAT env varilables"
  exit
end

opts = Optimist::options do
  opt :repo, "Specify GitHub repo. E.g. 'stockandawe/gh_client'", type: :string
  opt :csv, "Set as true a csv output", :type => :boolean, :default => false
  opt :team, "Run an analysis reeport for the specified team", type: :string, default: 'lender'
  opt :test, "run on only 1 milestone for more efficient testing", :type => :boolean , :default => false
end

if opts[:repo].nil?
  exec "bundle exec ruby #{__FILE__} -h"
  exit
end

sprintdata = SprintData.new(opts)
if opts[:csv] 
  sprintdata.write_to_csv 
else
  pp sprintdata.team_report
end

