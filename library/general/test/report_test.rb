#! /usr/bin/env rspec

require_relative "test_helper"
require "yaml"

Yast.import "Report"
Yast.import "Mode"

describe Yast::Report do
  before { subject.ClearAll }

  #
  # Shared examples
  #
  shared_examples "logging" do |meth, level|
    context "when logging is enabled" do
      it "logs the message" do
        allow(Yast::Popup).to receive(meth)
        expect(Yast::Builtins).to receive("y2#{level}")
          .with(1, "%1", "Message")
        subject.send(meth, "Message")
      end
    end

    context "when logging is disabled" do
      let(:log) { false }

      it "does not log the message" do
        allow(Yast::Popup).to receive(meth)
        expect(Yast::Builtins).to_not receive("y2#{level}")
        subject.send(meth, "Message")
      end
    end
  end

  shared_examples "display" do |meth|
    context "when display of messages is disabled" do
      let(:show) { false }

      it "does not show a popup" do
        expect(Yast::Popup).to_not receive(meth)
        subject.send(meth, "Message")
      end
    end

    context "when display of messages is enabled" do
      it "shows a popup" do
        expect(Yast::Popup).to receive(meth)
          .with("Message")
        subject.send(meth, "Message")
      end
    end

    shared_examples "timeouts" do
      context "when timeouts are enabled" do
        let(:timeout) { 1 }

        it "shows a timed popup" do
          expect(Yast::Popup).to receive("Timed#{meth}")
            .with("Message", 1)
          subject.send(meth, "Message")
        end
      end
    end
  end

  describe ".LongMessage" do
    let(:show) { true }
    let(:timeout) { 0 }
    let(:log) { true }

    before do
      subject.DisplayMessages(show, timeout)
      subject.LogMessages(log)
    end

    include_examples "logging", :LongMessage, "milestone"
    include_examples "display", :LongMessage
    include_examples "timeouts", :LongMessage

    it "stores the message" do
      subject.LongMessage("Message")
      expect(subject.GetMessages(0, 1, 0, 0)).to match(/Message/)
    end
  end

  describe ".LongWarning" do
    let(:show) { true }
    let(:timeout) { 0 }
    let(:log) { true }

    before do
      subject.DisplayWarnings(show, timeout)
      subject.LogWarnings(log)
    end

    include_examples "logging", :LongWarning, "warning"
    include_examples "display", :LongWarning
    include_examples "timeouts", :LongWarning

    it "stores the message" do
      subject.LongWarning("Message")
      expect(subject.GetMessages(0, 1, 0, 0)).to match(/Message/)
    end
  end

  describe ".LongError" do
    let(:show) { true }
    let(:timeout) { 0 }
    let(:log) { true }

    before do
      subject.DisplayErrors(show, timeout)
      subject.LogErrors(log)
    end

    include_examples "logging", :LongError, "error"
    include_examples "display", :LongError
    include_examples "timeouts", :LongError

    it "stores the message" do
      subject.LongError("Message")
      expect(subject.GetMessages(0, 1, 0, 0)).to match(/Message/)
    end
  end

  describe ".Settings" do
    DATA_PATH =  File.join(File.dirname(__FILE__), 'data')
    let(:ay_profile) { File.join(DATA_PATH, 'ay_profile.yml') }
    let(:default_normal) { File.join(DATA_PATH, 'default_normal_installation.yml') }
    let(:default_ay) { File.join(DATA_PATH, 'default_ay_installation.yml') }
    let(:result_ay) { File.join(DATA_PATH, 'ay_installation.yml') }

    context "while normal installation" do
      it "check default entries" do
        Yast::Mode.SetMode("installation")
        subject.main()
        default_map = YAML.load_file(default_normal)
        expect(subject.Export()).to match(default_map)
      end
    end

    context "while AutoYaST installation" do
      before(:each) do
        Yast::Mode.SetMode("autoinstallation")
        subject.main()
      end

      it "check default entries" do
        default_map = YAML.load_file(default_ay)
        expect(subject.Export()).to match(default_map)
      end
      it "check if default entries are not overwritten by empty import" do
        default_map = YAML.load_file(default_ay)
        subject.Import({})
        expect(subject.Export()).to match(default_map)
      end
      it "set flags via AutoYaST profile" do
        result_map = YAML.load_file(result_ay)
        ay_map = YAML.load_file(ay_profile)
        subject.Import(ay_map)
        expect(subject.Export()).to match(result_map)
      end
    end

    context "while AutoYaST cloning system" do
      before(:each) do
        Yast::Mode.SetMode("autoinst_config")
        subject.main()
      end

      it "AutoYaST default entries will be cloned" do
        # Set timeout for autoyast to 10 seconds (bnc#887397)
        default_map = YAML.load_file(default_ay)
        expect(subject.Export()).to match(default_map)
      end
    end
  end

end
