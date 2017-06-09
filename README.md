## Usage

### write your api token to $HOME/.toggl file

https://toggl.com/app/profile  
It can be found in API token section

### install gems

for example..

```:bash
$ bundle install --path vendor/bundle
```

### execute the command and input some arguments

for example ..

```
$ bundle exec ruby ./get_toggl.rb
workspace name: my_workspace
project name: my_project
start date(YYYY-MM-DD): 2017-05-01
end date(YYYY-MM-DD): 2017-05-31
```

then, a csv file will be generated.
