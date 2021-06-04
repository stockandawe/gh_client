### How to run

* Configure your [GitHub Personal Access Token](https://docs.github.com/en/github/authenticating-to-github/keeping-your-account-and-data-secure/creating-a-personal-access-token) as a `GITHUB_PAT` environment variable.
* `bundle install`
* `bundle exec ruby gh_client.rb` to review all the command line options


### Examples

1. Get a count of all the open issues in this repository since the beginning of the current month
```
$ bundle exec ruby gh_client.rb -r 'stockandawe/gh_client'
0 (open) issues tagged with Bug between 2021-6-1 and 2021-6-4
```

2. Get a count of all the closed issues in this repository since the beginning of the current month, and export the details to a csv file
```
$ bundle exec ruby gh_client.rb -r 'stockandawe/gh_client' -s 'closed' --csv
0 (closed) issues tagged with Bug between 2021-6-1 and 2021-6-4
Wrote to gh_client_2021-06-04 17:21:02 -0400.csv
```
