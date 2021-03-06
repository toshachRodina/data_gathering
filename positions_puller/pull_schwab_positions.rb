#!/usr/bin/ruby
require 'blogins'

include BLogins

login_file = ARGV[0]
directory = ARGV[1]

def get_schwab(user, pass, directory = 'Schwab')
    headless = Headless.new
    headless.start

    # Goto local directory
    puts 'Prepping directory ' + directory
    begin
        FileUtils.cd(directory)
    rescue Errno::ENOENT
        FileUtils.mkdir(directory)
        FileUtils.cd(directory)
    end

    # Set some variables
    autosave_mime_types = 'text/comma-separated-values,text/csv,application/csv'
    download_directory = "#{Dir.pwd}"

    # Autodownload profile (thanks to WatirMelon!)
    profile = Selenium::WebDriver::Firefox::Profile.new
    profile['browser.download.folderList'] = 2 # custom location
    profile['browser.download.dir'] = download_directory
    profile['browser.helperApps.neverAsk.saveToDisk'] = autosave_mime_types

    # Goto page    
    b = Watir::Browser.new :firefox, :profile => profile
    puts 'Logging In'
    schwab_login(b, user, pass)

    # Grab the data
    puts 'Grabbing Data'

    # Show full descriptions
    if b.a(:text => "Full").visible?
        b.a(:text => "Full").click
    end

    # Pull all brokerage positions
    b.div(:id => 'accountSelector').a.click
    b.a(:text => 'Show All Brokerage Accounts').when_present.click
    b.a(:text => 'Export').click
    b.windows[1].use
    b.a(:id => "ctl00_WebPartManager1_wpExportDisclaimer_ExportDisclaimer_btnOk").click
    b.windows[0].use

    # Pull data for bank account
    b.a(:text => 'Balances').when_present.click
    b.div(:id => 'accountSelector').a.click
    b.span(:text => /Checking/).when_present.click
    bank_desc, bank_acct = b.h2(:id => /AccountBalanceUserControl/).text.split[0..1]
    bank_acct = bank_acct[-8..-1]
    bank_cash = b.div(:id => /TotalBalAmt/).text
    bank_cash.gsub!("$", "")
    # Logout
    puts 'Logging out'
    schwab_logout(b)
    b.close()

    # Store the cash data
    fname = 'Bank.csv'
    fname_ts = 'Bank_' + Time.now.getutc.iso8601 + '.csv'

    headers = ['Symbol', 'Description', 'Quantity', 'Price', 'Market Value']
    f = File.new(fname_ts, 'w')
    f << 'Positions for Bank as of %s' % Time.now.strftime('%m/%d/%Y %H:%M:%S')
    f << "\nBank XXXX-%s\n" % bank_acct
    csv = CSV.new(f, {:headers => :first_row, :write_headers => true})
    head_row = CSV::Row.new(headers, headers, header_row = true)
    csv << head_row
    field_row = CSV::Row.new(headers, ['USD', bank_desc, bank_cash, 1,
                                        bank_cash])
    csv << field_row
    f << "account total"
    csv.close()

    if Dir.entries('.').include?(fname)
        FileUtils.rm(fname)
    end
    puts 'Latest datafile is ' + fname_ts
    FileUtils.cp(fname_ts, fname)
    puts "Copied to " + fname + "\n\n"

    # Copy the position data to the simple filename
    update_local_positions_file('All-Accounts-Positions')

    headless.destroy
end

# Rudimentary and insecure way of getting login data
# First (and only) argument is a two-line file.
# Line 1 is username
# Line 2 is password
user = String.new
pass = String.new
File.open(login_file) do |f|
  user, pass = f.read.split("\n")
end

# Second argument is a custom path where you want the data.
# Default is the name of the brokerage.
if ARGV[1]
    get_schwab(user, pass, ARGV[1])
else
    get_schwab(user, pass)
end
