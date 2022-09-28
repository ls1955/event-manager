# frozen_string_literal: false

require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'date'
require 'time'

puts 'Event manager initialized.'

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new(template_letter)

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0').slice(0, 5)
end

def clean_homephone(homephone)
  homephone = homephone.to_s.gsub(/\D/, '')

  if homephone.length < 10 || (homephone.length > 11 && homephone[0] != '1')
    'N/A'
  else
    homephone.split('').last(10).join('')
  end
end

reg_hours = []
reg_weekdays = []
weekday_to_day = %w[Sunday Monday Tuesday Wednesday Thursday Friday Saturday]

def max_freq(arr)
  arr.max_by { |elem| arr.count(elem) }
end

def legislators_by_zipcode(zipcode)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    civic_info.representative_info_by_address(
      address: zipcode,
      levels: 'country',
      roles: %w[legislatorUpperBody legislatorLowerBody]
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')
  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])
  homephone = clean_homephone(row[:homephone])
  reg_date_time = DateTime.strptime(row[:regdate], '%m/%d/%y %H:%M')

  reg_hours << reg_date_time.hour
  reg_weekdays << reg_date_time.wday

  legislators = legislators_by_zipcode(zipcode)
  form_letter = erb_template.result(binding)

  save_thank_you_letter(id, form_letter)
end

puts "Peak registration hour: #{max_freq(reg_hours)}:00"
puts "Peak day: #{weekday_to_day[max_freq(reg_weekdays)]}"
