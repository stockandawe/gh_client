### How to run

* Configure your [GitHub Personal Access Token](https://docs.github.com/en/github/authenticating-to-github/keeping-your-account-and-data-secure/creating-a-personal-access-token) as a `GITHUB_PAT` environment variable.
* `bundle install`
* `bundle exec ruby gh_client.rb` to review all the command line options


### Examples

1. Show help/all command line options
```
$ bundle exec ruby gh_client.rb --help                                                                      
Options:
 -r, --repo=<s>          Specify GitHub repo. E.g. 'stockandawe/gh_client'
 -l, --labels=<s>        Specify a list of comma separated label names. E.g. 'Bug,Internal'
 -e, --event=<s>         Specify the event that you want to track. Can be 'created', 'updated', or 'closed' (default: created)
 -s, --start-date=<s>    Specify the start date YYYY-MM-DD format (default: 2022-4-1)
 -n, --end-date=<s>      Specify the end date YYYY-MM-DD format (default: 2022-4-22)
 -c, --csv               Set as true a csv output
 -h, --help              Show this message
 ```

2. Get a count of all the open issues in this repository since the beginning of the current month
```
$ bundle exec ruby gh_client.rb -r 'stockandawe/gh_client'
0 (open) issues tagged with Bug between 2021-6-1 and 2021-6-4
```

3. Get a count of all the closed issues in this repository since the beginning of the current month, and export the details to a csv file
```
$ bundle exec ruby gh_client.rb -r 'stockandawe/gh_client' -e 'closed' --csv
0 (closed) issues tagged with Bug between 2021-6-1 and 2021-6-4
Wrote to gh_client_2021-06-04 17:21:02 -0400.csv
```
