#!/home/vagrant/.rvm/rubies/ruby-2.2.1/bin/ruby

# Use these docs: https://www.zoho.com/books/api/v3/
# Inspired by https://github.com/jgrossiord/zoho-invoice-get-receipt/blob/master/importInvoices.rb

require 'rest-client'
require 'json'
require 'open-uri'
require 'fileutils'

authtoken=YOUR_AUTH_TOKEN
organization_id=YOUR_ORGANIZATION_ID
base_endpoint = 'https://books.zoho.com/api/v3'

account_id=YOUR_ACCOUNT_NUMBER
transactions_endpoint = base_endpoint + '/banktransactions'


output_filename = './some-name.csv'
output = open(output_filename, 'w')

page = 1
has_more = true

while has_more
  transactions = RestClient.get transactions_endpoint, { params: { authtoken: authtoken, organization_id: organization_id, account_id: account_id, page: page}}
  transactions = JSON.parse(transactions)
  has_more = transactions['page_context']['has_more_page']
  transactions['banktransactions'].each do |transaction|
    count = 0
    if count == 140
      puts "gonna take a break for a min...\n"
      count = 0
      sleep(60)
      puts "ok doke!\n"
    end
    count+=1
    line = []
    puts transaction['transaction_id']
    #get the basic transaction data
    line << transaction['transaction_id']
    line << transaction['date']
    line << transaction['amount']
    line << transaction['transaction_type']
    line << transaction['status']
    line << transaction['source']
    line << transaction['account_name']
    line << transaction['account_type']
    line << transaction['payee']
    line << transaction['description']
    line << transaction['debit_or_credit']
    line << transaction['offset_account_name']
    line << transaction['reference_number']
    line << transaction['debit_or_credit']

    # if there is a customer id, get that
    if transaction['customer_id'] == ''
      line << ''
      line << ''
    else
      count+=1
      customer = JSON.parse(RestClient.get("#{base_endpoint}/contacts/#{transaction['customer_id']}", { params: { authtoken: authtoken, organization_id: organization_id }}))
      line << customer['contact']['contact_name']
      line << customer['contact']['company_name']
    end

    # if the transaction is an expense get that data, otherwise get the other kind
    if transaction['transaction_type'] == 'expense'
      count+=1
      expense = JSON.parse(RestClient.get("#{base_endpoint}/expenses/#{transaction['transaction_id']}", { params: { authtoken: authtoken, organization_id: organization_id}}))
      line << expense['expense']['vendor_name']
      line << expense['expense']['reference_number']
      line << expense['expense']['description']
      line << expense['expense']['is_billable']
      line << expense['expense']['customer_name']
      line << expense['expense']['project_name']

    elsif transaction['transaction_type'] == 'vendor_payment'
      payment = JSON.parse(RestClient.get("#{base_endpoint}/vendorpayments/#{transaction['transaction_id']}", { params: { authtoken: authtoken, organization_id: organization_id}}))
      line << payment['vendorpayment']['vendor_name']
      line << payment['vendorpayment']['reference_number']
      line << payment['vendorpayment']['description']
      line << ''
      line << ''
      line << ''
      line << ''
      line << ''
    else
      count+=1
      begin
        nonexpense = JSON.parse(RestClient.get("#{transactions_endpoint}/#{transaction['transaction_id']}", { params: { authtoken: authtoken, organization_id: organization_id, account_id: account_id}}))
        line << nonexpense['banktransaction']['vendor_name']
        line << nonexpense['banktransaction']['reference_number']
        line << nonexpense['banktransaction']['description']
        line << ''
        line << nonexpense['banktransaction']['customer_name']
        line << ''
        line << nonexpense['banktransaction']['from_account_name']
        line << nonexpense['banktransaction']['to_account_name']
      rescue
        puts "Failed --> #{transaction['transaction_id']}"
        puts transaction.inspect
      end
    end


      output.puts line.join(',')
  end

  puts "processed #{page} page\n"
  page += 1
end

output.close
