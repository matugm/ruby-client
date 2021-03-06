require 'capybara/poltergeist'
require 'pry'

require File.join File.dirname(__FILE__), '..', '..', 'lib', 'bitpay_sdk.rb'
require_relative '../../config/constants.rb'
require_relative '../../config/capybara.rb'

#
## Test Variables
#
#PEM = "-----BEGIN EC PRIVATE KEY-----\nMHQCAQEEICg7E4NN53YkaWuAwpoqjfAofjzKI7Jq1f532dX+0O6QoAcGBSuBBAAK\noUQDQgAEjZcNa6Kdz6GQwXcUD9iJ+t1tJZCx7hpqBuJV2/IrQBfue8jh8H7Q/4vX\nfAArmNMaGotTpjdnymWlMfszzXJhlw==\n-----END EC PRIVATE KEY-----\n"
#
#PUB_KEY = '038d970d6ba29dcfa190c177140fd889fadd6d2590b1ee1a6a06e255dbf22b4017'
#CLIENT_ID = "TeyN4LPrXiG5t2yuSamKqP3ynVk3F52iHrX"
module BitPay
  # Location for API Credentials
  BITPAY_CREDENTIALS_DIR = File.join(Dir.home, ".bitpay")
  PRIVATE_KEY_FILE = 'bitpay.pem'
  PRIVATE_KEY_PATH = File.join(BITPAY_CREDENTIALS_DIR, PRIVATE_KEY_FILE)
  TOKEN_FILE = 'tokens.json'
  TOKEN_FILE_PATH = File.join(BITPAY_CREDENTIALS_DIR, TOKEN_FILE)
end

def get_claim_code_from_server
  Capybara::visit ROOT_ADDRESS
  if logged_in
    Capybara::visit "#{ROOT_ADDRESS}/home"
  else
    log_in
  end
  Capybara::click_link "My Account"
  Capybara::click_link "API Tokens", match: :first
  Capybara::find(".token-access-new-button").find(".btn").find(".icon-plus").click
  sleep 0.25
  Capybara::find_button("Add Token", match: :first).click
  Capybara::find(".token-claimcode", match: :first).text
end

def log_in
  Capybara::click_link('Login')
  Capybara::fill_in 'email', :with => TEST_USER
  Capybara::fill_in 'password', :with => TEST_PASS
  Capybara::click_button('loginButton')
end

def new_paired_client
  claim_code = get_claim_code_from_server
  pem = BitPay::KeyUtils.generate_pem
  client = BitPay::SDK::Client.new(api_uri: ROOT_ADDRESS, pem: pem, insecure: true)
  client.pair_pos_client(claim_code)
  client
end

def new_client_from_stored_values
  if File.file?(BitPay::PRIVATE_KEY_PATH) && File.file?(BitPay::TOKEN_FILE_PATH)
    token = get_token_from_file
    pem = File.read(BitPay::PRIVATE_KEY_PATH)
    BitPay::SDK::Client.new(pem: pem, tokens: token, insecure: true, api_uri: ROOT_ADDRESS )
  else
    claim_code = get_claim_code_from_server
    pem = BitPay::KeyUtils.generate_pem
    client = BitPay::SDK::Client.new(api_uri: ROOT_ADDRESS, pem: pem, insecure: true)
    token = client.pair_pos_client(claim_code)
    File.write(BitPay::PRIVATE_KEY_PATH, pem)
    File.write(BitPay::TOKEN_FILE_PATH, JSON.generate(token))
    client
  end   
end

def get_token_from_file
  token = JSON.parse(File.read(BitPay::TOKEN_FILE_PATH))['data'][0]
  {token['facade'] => token['token']}
end

def logged_in
  Capybara::has_link?('Dashboard')
end
