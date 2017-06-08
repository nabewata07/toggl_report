require 'togglv8'
require 'date'

# open class and monkey patch
module TogglV8
  module Connection
    def self.open(username=nil, password=API_TOKEN, url=nil, opts={})
      raise 'Missing URL' if url.nil?

      Faraday.new(:url => url, :ssl => {:verify => true}) do |faraday|
        faraday.request :url_encoded
        faraday.response :logger, Logger.new('faraday.log') if opts[:log]
        faraday.adapter Faraday.default_adapter
        faraday.headers = { "Content-Type" => "application/json" }
        faraday.basic_auth username.chomp, password
      end
    end

    def get(resource, params={})
      query_params = params.map { |k,v| "#{k}=#{v}" }.join('&')
      resource += "?#{query_params}" unless query_params.empty?
      resource.gsub!('+', '%2B')
      full_resp = _call_api(debug_output: lambda { "GET #{resource}" },
                  api_call: lambda { self.conn.get(resource) } )
      return {} if full_resp == {}
      begin
        resp = Oj.load(full_resp.body)
        return resp if params[:full_resp]
        return resp['data'] if resp.respond_to?(:has_key?) && resp.has_key?('data')
        return resp
      rescue Oj::ParseError
        return full_resp.body
      end
    end
  end
end

class TogglManager
  @@man_hours = {}

  def self.get_input
    @@args = {}
    print 'workspace name: '
    @@args[:workspace_name] = gets.chomp!
    print 'project name: '
    @@args[:project_name] = gets.chomp!
    print 'start date(YYYY-MM-DD): '
    @@args[:start_date] = gets.chomp!
    print 'end date(YYYY-MM-DD): '
    @@args[:end_date] = gets.chomp!
    # TODO validate args
  end

  def self.get_monthly_report
    get_input
    # TODO get project list and get project_id from project name
    toggl_api    = TogglV8::API.new()
    reports      = TogglV8::ReportsV2.new()
    user         = toggl_api.me(all=true)
    workspaces   = toggl_api.my_workspaces(user)

    workspace_id = nil
    workspaces.each do |w|
      if w['name'] == @@args[:workspace_name]
        workspace_id = w['id']
        break
      end
    end

    reports.workspace_id = workspace_id
    params = {
      since: @@args[:start_date],
      until: @@args[:end_date],
      full_resp: true,# custom argument for this command
      page: 1#,
    }
    repo = reports.details('csv', params)
    total_count = repo['total_count']
    per_page = repo['per_page']

    loop_num = (total_count*1.0 / per_page).ceil - 1

    parse_report(repo)

    loop_num.times do
      params[:page] += 1
      tmp_repo = reports.details('csv', params)
      parse_report(tmp_repo)
    end

    start_date = Date.parse(@@args[:start_date])
    end_date = Date.parse(@@args[:end_date])
    (start_date..end_date).each do |d|
      d_str = d.strftime('%Y-%m-%d')
      unless @@man_hours[d_str]
        @@man_hours[d_str] = 0
      end
    end

    create_csv
  end

  def self.create_csv
    keys = @@man_hours.keys.sort
    csv_str = keys.join(',') + "\n"
    tmp_ary = []
    keys.each do |k|
      tmp_ary.push(@@man_hours[k].round(2))
    end
    csv_str += tmp_ary.join(',')
    suffix = Date.today.strftime('%Y%m%d')
    file_name = "man_hours_#{suffix}.csv"
    file_path = Dir.pwd + '/' + file_name
    File.write(file_path, csv_str)
    puts "#{file_path}"
    puts "was generated"
  end

  def self.parse_report(repo)
    repo['data'].each do |record|
      next if record['project'] != @@args[:project_name]
      start_time = ::DateTime.parse(record['start'])
      date_str = start_time.strftime('%Y-%m-%d')
      unless @@man_hours[date_str]
        @@man_hours[date_str] = 0
      end
      end_time = ::DateTime.parse(record['end'])
      delta_sec = end_time.to_time.to_i - start_time.to_time.to_i
      delta_hours = delta_sec*1.0 / (60*60)
      @@man_hours[date_str] += delta_hours
    end
  end
end

if  __FILE__ == $0
  TogglManager.get_monthly_report
end
