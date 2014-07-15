#
# Author:: Mukta Aphale (<mukta.aphale@clogeny.com>)
# Author:: Siddheshwar More (<siddheshwar.more@clogeny.com>)
# Copyright:: Copyright (c) 2013-2014 Chef Software, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'support/shared_examples_for_command'
require 'support/shared_examples_for_servercreatecommand'
require 'net/ssh'
require 'chef/knife/cloud/server/create_options'

describe Chef::Knife::Cloud::ServerCreateCommand do
  it_behaves_like Chef::Knife::Cloud::Command, Chef::Knife::Cloud::ServerCreateCommand.new
  it_behaves_like Chef::Knife::Cloud::ServerCreateCommand, Chef::Knife::Cloud::ServerCreateCommand.new

  describe "#validate_params!" do
    before(:each) do
      @instance = Chef::Knife::Cloud::ServerCreateCommand.new
      allow(@instance.ui).to receive(:error)
      Chef::Config[:knife][:bootstrap_protocol] = "ssh"
      Chef::Config[:knife][:identity_file] = "identity_file"
      Chef::Config[:knife][:ssh_password] = "ssh_password"
      Chef::Config[:knife][:chef_node_name] = "chef_node_name"
      Chef::Config[:knife][:winrm_password] = "winrm_password"
    end
    after(:all) do
      Chef::Config[:knife].delete(:bootstrap_protocol)
      Chef::Config[:knife].delete(:identity_file)
      Chef::Config[:knife].delete(:chef_node_name)
      Chef::Config[:knife].delete(:ssh_password)
      Chef::Config[:knife].delete(:winrm_password)
    end

    it "run sucessfully on all params exist" do
      expect { @instance.validate_params! }.to_not raise_error
      expect(@instance.config[:chef_node_name]).to eq(Chef::Config[:knife][:chef_node_name])
    end

    context "when bootstrap_protocol ssh" do
      it "raise error on ssh_password and identity_file are missing" do
        Chef::Config[:knife].delete(:identity_file)
        Chef::Config[:knife].delete(:ssh_password)
        expect { @instance.validate_params! }.to raise_error(Chef::Knife::Cloud::CloudExceptions::ValidationError, " You must provide either Identity file or SSH Password..")
      end
    end

    context "when bootstrap_protocol winrm" do
      it "raise error on winrm_password is missing" do
        Chef::Config[:knife][:bootstrap_protocol] = "winrm"
        Chef::Config[:knife].delete(:winrm_password)
        expect { @instance.validate_params! }.to raise_error(Chef::Knife::Cloud::CloudExceptions::ValidationError, " You must provide Winrm Password..")
      end
    end
  end

  describe "#after_exec_command" do
    it "calls bootstrap" do
      instance = Chef::Knife::Cloud::ServerCreateCommand.new
      expect(instance).to receive(:bootstrap)
      instance.after_exec_command
    end

    it "delete server on bootstrap failure" do
      instance = Chef::Knife::Cloud::ServerCreateCommand.new
      instance.service = Chef::Knife::Cloud::Service.new
      allow(instance).to receive(:raise)
      allow(instance.ui).to receive(:fatal)
      instance.config[:delete_server_on_failure] = true
      allow(instance).to receive(:bootstrap).and_raise(Chef::Knife::Cloud::CloudExceptions::BootstrapError)
      expect(instance.service).to receive(:delete_server_dependencies)
      expect(instance.service).to receive(:delete_server_on_failure)
      instance.after_exec_command
    end

    # Currently the RangeError is occured when image_os_type is set to linux and bootstrap-protocol is set to ssh before windows server bootstrap.
    it "raise error message when bootstrap fails due to image_os_type not exist" do
      instance = Chef::Knife::Cloud::ServerCreateCommand.new
      instance.service = Chef::Knife::Cloud::Service.new
      allow(instance.ui).to receive(:fatal)
      instance.config[:delete_server_on_failure] = true
      allow(instance).to receive(:bootstrap).and_raise(RangeError)
      expect(instance.service).to receive(:delete_server_dependencies)
      expect(instance.service).to receive(:delete_server_on_failure)
      expect { instance.after_exec_command }.to raise_error(RangeError, "Check if --bootstrap-protocol and --image-os-type is correct. RangeError")
    end
  end

  describe "#set_default_config" do
    it "set valid image os type" do
      instance = Chef::Knife::Cloud::ServerCreateCommand.new
      instance.config[:bootstrap_protocol] = 'winrm'
      instance.set_default_config
      expect(instance.config[:image_os_type]).to eq('windows')
    end
  end

  describe "#bootstrap options" do

    class ServerCreate < Chef::Knife::Cloud::ServerCreateCommand
      include Chef::Knife::Cloud::ServerCreateOptions
    end

    it "set chef config knife options" do
      instance = ServerCreate.new
      bootstrap_url = "bootstrap_url"
      bootstrap_install_command = "bootstrap_install_command"
      bootstrap_wget_options = "bootstrap_wget_options"
      bootstrap_curl_options = "bootstrap_curl_options"
      bootstrap_no_proxy = "bootstrap_no_proxy"

      instance.options[:bootstrap_url][:proc].call bootstrap_url
      expect(Chef::Config[:knife][:bootstrap_url]).to eq(bootstrap_url)

      instance.options[:bootstrap_install_command][:proc].call bootstrap_install_command
      expect(Chef::Config[:knife][:bootstrap_install_command]).to eq(bootstrap_install_command)

      instance.options[:bootstrap_wget_options][:proc].call bootstrap_wget_options
      expect(Chef::Config[:knife][:bootstrap_wget_options]).to eq(bootstrap_wget_options)

      instance.options[:bootstrap_curl_options][:proc].call bootstrap_curl_options
      expect(Chef::Config[:knife][:bootstrap_curl_options]).to eq(bootstrap_curl_options)

      instance.options[:bootstrap_no_proxy][:proc].call bootstrap_no_proxy
      expect(Chef::Config[:knife][:bootstrap_no_proxy]).to eq(bootstrap_no_proxy)      

      expect(instance.options[:auth_timeout][:default]).to eq(25)
    end
  end
end
